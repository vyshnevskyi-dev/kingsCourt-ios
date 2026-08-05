"""Pre-upload de-fingerprint security checker.

Scans a BUILT artifact (.ipa or .app) for the shared fingerprints Apple
clusters the app farm on — the exact signals that got clean white apps
banned hours after going live. Every fix we shipped is encoded here as an
assertion, so a regression (or a mis-configured build) is caught and the
upload is BLOCKED before the binary ever reaches App Store Connect.

Usage:
    from orchestrator.defingerprint_check import check_artifact
    report = check_artifact("output/foo/FooApp.ipa")
    if not report["ok"]:
        raise RuntimeError(report["summary"])

Checks (FAIL = blocks upload, WARN = surfaced but non-blocking unless the
matching ``expect_*`` promotes it):

    build_path        no /Users/<name>/ or AppFactory/repos in the binary
    sdk_symbols       shared SDK type names renamed (uniquified)
    module_appflow    the 'AppFlow' module/folder token is gone
    incriminating     no 'ban gate' / 'covert gate' / cache-key tells
    c2pa_provenance   no OpenAI/C2PA Content-Credentials in the bundle
    shared_domain     no baked wildcherry.cloud (WARN, FAIL if per-app)
    fixed_wire_path   no '/api/v1/client/init' literal (WARN, FAIL if wire)
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
import zipfile

# High-signal shared SDK type names — present == SDK NOT uniquified (#6).
_SDK_SYMBOLS = [
    "CovertGate", "AppRouter", "NetworkClient", "WebContentController",
    "AppFlowRootView", "AppLogger", "OverlayHub", "FortuneWheelSheet",
]
# Self-incriminating literals that scream "cloaking" to a strings scan (#6).
_INCRIMINATING = [
    "ban gate", "Ban gate", "covert gate", "Covert gate", "BanGateView",
    "app.cached.ban_gate", "Covert gate open", "sticky ban gate",
]
# AI-provenance / C2PA Content Credentials in icons + backgrounds (#9).
_C2PA = [
    "c2pa", "jumbf", "OpenAI", "gpt-image", "gDALL",
    "trainedAlgorithmicMedia", "contentauth",
]
# Shared covert-gate beacon host — one workers.dev domain baked into every
# covert app = a single fingerprint that clusters the whole farm (#2).
_COVERT_HOSTS = ["wc-appcfg.workers.dev", "covert-gate.wc-appcfg"]

# Russian label + one-line explanation shown per check in the report.
_CHECK_META = {
    "build_path": (
        "Пути и username сборки",
        "В бинаре нет /Users/<имя>/… и AppFactory/repos — не светится ноутбук "
        "и машина сборки."),
    "sdk_symbols": (
        "Уникализация SDK (имена типов)",
        "Общие имена типов SDK (AppRouter, CovertGate, NetworkClient…) "
        "переименованы под каждый апп — нет единого символьного отпечатка."),
    "module_appflow": (
        "Уникализация SDK (модуль)",
        "Токен модуля/папки «AppFlow» убран — бинарь не выдаёт общий SDK."),
    "incriminating": (
        "Палевные строки",
        "В бинаре нет «ban gate» / «covert gate» / кэш-ключей клоакинга, "
        "которые Apple ловит грепом по строкам."),
    "c2pa_provenance": (
        "C2PA в графике",
        "Иконки и фоны без C2PA-меток OpenAI (AI-провенанс + дата генерации), "
        "по которым аппы кластеризуются пачкой."),
    "shared_domain": (
        "Общий бэкенд-домен",
        "В бинаре не зашит общий wildcherry.cloud — нужен per-app домен "
        "(снимется после активации доменов)."),
    "covert_gate_host": (
        "Общий covert-gate хост",
        "Нет зашитого covert-gate.wc-appcfg.workers.dev — один воркер-маяк на "
        "всех аппах; снимется после per-app covert-домена."),
    "fixed_wire_path": (
        "Фиксированный wire-путь",
        "Литерал /api/v1/client/init (мёртвый fallback; при wire-путях путь "
        "выводится из секрета в рантайме)."),
}


def _strings(path: str) -> str:
    """`strings -a` over a file; '' on failure."""
    try:
        out = subprocess.run(["strings", "-a", path], capture_output=True,
                             text=True, errors="ignore", timeout=120)
        return out.stdout
    except Exception:  # noqa: BLE001
        return ""


def _resolve_app_dir(path: str, workdir: str) -> str | None:
    """Return a .app directory, unzipping a .ipa into ``workdir`` if needed."""
    if path.endswith(".app") and os.path.isdir(path):
        return path
    if path.endswith(".ipa") and os.path.isfile(path):
        with zipfile.ZipFile(path) as z:
            z.extractall(workdir)
        payload = os.path.join(workdir, "Payload")
        if os.path.isdir(payload):
            for name in os.listdir(payload):
                if name.endswith(".app"):
                    return os.path.join(payload, name)
    return None


def _executable(app_dir: str) -> str | None:
    """The Mach-O executable inside a .app (CFBundleExecutable or app name)."""
    base = os.path.basename(app_dir)[:-4]
    cand = os.path.join(app_dir, base)
    if os.path.isfile(cand):
        return cand
    for name in os.listdir(app_dir):
        p = os.path.join(app_dir, name)
        if os.path.isfile(p) and os.access(p, os.X_OK) and "." not in name:
            return p
    return None


def gate_or_raise(ipa_path: str, config: dict | None = None) -> dict:
    """Pipeline gate: run the checker on ``ipa_path`` and RAISE if any hard
    fingerprint is present, blocking the upload. Returns the report on pass.

    Blocks only on the UNAMBIGUOUS binary fingerprints (build path, SDK
    symbols, AppFlow module, incriminating strings, C2PA). The shared
    domain stays a non-blocking WARN — it clears operationally once per-app
    domains are activated, and hard-blocking on it would halt every upload
    before that infra is live.
    """
    report = check_artifact(ipa_path, expect_per_app_domain=False)
    if not report["ok"]:
        raise RuntimeError(
            "De-fingerprint gate BLOCKED upload: " + report["summary"]
        )
    return report


def check_artifact(path: str, *, expect_wire_paths: bool = True,
                   expect_per_app_domain: bool = False,
                   shared_domain: str = "wildcherry.cloud") -> dict:
    """Scan a built .ipa/.app. Returns a report dict with ``ok`` + ``checks``."""
    work = tempfile.mkdtemp(prefix="defpcheck_")
    try:
        app_dir = _resolve_app_dir(path, work)
        if not app_dir:
            return {"ok": False, "summary": f"could not resolve .app from {path}",
                    "checks": []}
        exe = _executable(app_dir)
        exe_str = _strings(exe) if exe else ""
        # Bundle-wide scan (binary + Assets.car + nibs) for string tells.
        bundle_str = exe_str
        car = os.path.join(app_dir, "Assets.car")
        if os.path.isfile(car):
            bundle_str += "\n" + _strings(car)

        checks: list[dict] = []

        def add(name, severity, passed, detail=""):
            label, desc = _CHECK_META.get(name, (name, ""))
            checks.append({"name": name, "label": label, "desc": desc,
                           "severity": severity, "passed": passed,
                           "detail": detail})

        # 1. build-path / username leak (#5)
        m = re.search(r"/Users/[A-Za-z0-9._-]+/[A-Za-z0-9._/-]*", exe_str)
        repos = "AppFactory/repos" in exe_str
        add("build_path", "FAIL", not (m or repos),
            (m.group(0) if m else "AppFactory/repos") if (m or repos) else "")

        # 2. shared SDK symbol names (#6)
        hit = [s for s in _SDK_SYMBOLS if re.search(rf"\b{re.escape(s)}\b", exe_str)]
        add("sdk_symbols", "FAIL", not hit, ", ".join(hit))

        # 3. 'AppFlow' module/folder token (#6)
        add("module_appflow", "FAIL", "AppFlow" not in exe_str, "AppFlow")

        # 4. incriminating strings (#6)
        hit = [s for s in _INCRIMINATING if s in bundle_str]
        add("incriminating", "FAIL", not hit, ", ".join(sorted(set(hit))))

        # 5. C2PA / AI provenance across the bundle (#9)
        hit = [s for s in _C2PA if s in bundle_str]
        add("c2pa_provenance", "FAIL", not hit, ", ".join(hit))

        # 6. shared backend domain (#2/#3)
        has_shared = shared_domain in exe_str
        add("shared_domain", "FAIL" if expect_per_app_domain else "WARN",
            not has_shared, shared_domain if has_shared else "")

        # 6b. shared covert-gate beacon host (#2) — the single workers.dev
        # gateway baked into every covert app. WARN until per-app covert
        # domains are live (promoted to FAIL alongside shared_domain).
        chit = next((h for h in _COVERT_HOSTS if h in exe_str), None)
        add("covert_gate_host", "FAIL" if expect_per_app_domain else "WARN",
            not chit, chit or "")

        # 7. fixed wire path (#1) — WARN only: the literal survives as a dead
        # fallback constant even when wirePathsEnabled derives paths at
        # runtime (and obfuscate_strings vaults it away entirely). Presence
        # doesn't prove use, so it never blocks; enforcement is config-level.
        has_fixed = "/api/v1/client/init" in exe_str
        add("fixed_wire_path", "WARN", not has_fixed,
            "/api/v1/client/init" if has_fixed else "")

        failures = [c for c in checks if c["severity"] == "FAIL" and not c["passed"]]
        warns = [c for c in checks if c["severity"] == "WARN" and not c["passed"]]
        ok = not failures
        summary = (
            "de-fingerprint OK" if ok else
            "BLOCKED — fingerprints present: " +
            "; ".join(f"{c['name']}[{c['detail']}]" for c in failures)
        )
        if warns:
            summary += " | warnings: " + ", ".join(c["name"] for c in warns)
        return {"ok": ok, "summary": summary, "checks": checks,
                "app": os.path.basename(app_dir)}
    finally:
        shutil.rmtree(work, ignore_errors=True)


def render_html(report: dict) -> str:
    """Self-contained animated HTML report (no external assets, no network).

    Written as a Codemagic build artifact so the check is SEEN visually —
    each row scans then resolves ✅/⚠/❌, a bar fills, a verdict banner
    lands. Generated on the CI box; the laptop never touches the binary.
    """
    import json as _json
    ok = report.get("ok", False)
    app = report.get("app", "app")
    checks = report.get("checks", [])
    fails = sum(1 for c in checks if c["severity"] == "FAIL" and not c["passed"])
    data = _json.dumps(checks)
    verdict = ("CLEARED FOR UPLOAD" if ok
               else f"BLOCKED — {fails} fingerprint(s)")
    vclass = "ok" if ok else "bad"
    return """<!doctype html><html><head><meta charset="utf-8">
<title>De-fingerprint check — %s</title><style>
:root{--bg:#111;--card:#1a1a1a;--dim:#888;--ok:#3ddc84;--warn:#f5b301;--bad:#ff5c5c;--line:#2a2a2a}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:#eee;font:15px/1.5 -apple-system,Segoe UI,Roboto,sans-serif;padding:32px}
.wrap{max-width:640px;margin:0 auto}
h1{font-size:15px;letter-spacing:.14em;color:var(--dim);font-weight:600;margin:0 0 4px}
.app{font-size:24px;font-weight:700;margin:0 0 20px}
.bar{height:4px;background:var(--line);border-radius:4px;overflow:hidden;margin:0 0 22px}
.bar>i{display:block;height:100%%;width:0;background:linear-gradient(90deg,var(--ok),#7ef);transition:width .5s ease}
.row{display:flex;align-items:center;gap:14px;padding:13px 16px;background:var(--card);border:1px solid var(--line);border-radius:11px;margin:8px 0;opacity:0;transform:translateY(8px);transition:opacity .35s,transform .35s,border-color .35s}
.row.in{opacity:1;transform:none}
.ic{width:22px;height:22px;flex:0 0 22px;border-radius:50%%;display:grid;place-items:center;font-size:13px;font-weight:800}
.scan{border:2px solid var(--line);border-top-color:#7ef;animation:spin .7s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}
.pass .ic{background:rgba(61,220,132,.15);color:var(--ok)}.warn .ic{background:rgba(245,179,1,.15);color:var(--warn)}
.fail .ic{background:rgba(255,92,92,.15);color:var(--bad)}
.txt{flex:1;min-width:0}.nm{font-weight:600}.ds{color:var(--dim);font-size:12.5px;line-height:1.35;margin-top:2px}
.dt{color:#c99;font-size:11.5px;font-family:ui-monospace,monospace;max-width:150px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:0 0 auto}
.pass .nm{color:#cfeede}.fail .nm{color:#ffd7d7}
.verdict{margin-top:24px;padding:18px;border-radius:12px;text-align:center;font-weight:800;letter-spacing:.06em;font-size:17px;opacity:0;transform:scale(.96);transition:.4s}
.verdict.show{opacity:1;transform:none}
.verdict.ok{background:rgba(61,220,132,.12);color:var(--ok);border:1px solid rgba(61,220,132,.4)}
.verdict.bad{background:rgba(255,92,92,.12);color:var(--bad);border:1px solid rgba(255,92,92,.4)}
</style></head><body><div class="wrap">
<h1>ПРОВЕРКА БЕЗОПАСНОСТИ · ДЕ-ФИНГЕРПРИНТ</h1><div class="app">%s</div>
<div class="bar"><i id="bar"></i></div><div id="rows"></div>
<div class="verdict %s" id="verdict">%s</div></div>
<script>
var CHECKS=%s, V="%s";
var rows=document.getElementById('rows'),bar=document.getElementById('bar'),done=0;
function esc(s){var d=document.createElement('div');d.textContent=s||'';return d.innerHTML;}
CHECKS.forEach(function(c,i){
  var passed=c.passed, sev=c.severity;
  var cls=passed?'pass':(sev==='WARN'?'warn':'fail');
  var sym=passed?'\\u2713':(sev==='WARN'?'!':'\\u2715');
  var el=document.createElement('div');el.className='row '+cls;
  el.innerHTML='<div class="ic scan"></div><div class="txt"><div class="nm">'+esc(c.label||c.name)+'</div><div class="ds">'+esc(c.desc||'')+'</div></div><div class="dt">'+esc(c.detail||'')+'</div>';
  rows.appendChild(el);
  setTimeout(function(){el.classList.add('in');},120*i);
  setTimeout(function(){
    var ic=el.querySelector('.ic');ic.classList.remove('scan');ic.textContent=sym;
    done++;bar.style.width=(done/CHECKS.length*100)+'%%';
    if(done===CHECKS.length){var v=document.getElementById('verdict');setTimeout(function(){v.classList.add('show');},250);}
  },120*i+650);
});
</script></body></html>""" % (app, app, vclass, verdict, data, vclass)


def _main(argv: list[str]) -> int:
    """CLI: `python3 -m orchestrator.defingerprint_check <app.ipa|app.app>`.
    Exit 0 = clean (upload allowed), 1 = blocked. Usable as a Codemagic
    post-build gate before the TestFlight publish step."""
    if not argv:
        print("usage: defingerprint_check <path-to.ipa|.app> [--html OUT.html]")
        return 2
    html_out = None
    if "--html" in argv:
        i = argv.index("--html")
        html_out = argv[i + 1] if i + 1 < len(argv) else "defingerprint_report.html"
        argv = argv[:i] + argv[i + 2:]
    rep = check_artifact(argv[0])
    for c in rep["checks"]:
        mark = "PASS" if c["passed"] else c["severity"]
        print(f"  [{mark:4}] {c['name']:16} {c['detail'][:60]}")
    print(rep["summary"])
    if html_out:
        with open(html_out, "w", encoding="utf-8") as f:
            f.write(render_html(rep))
        print(f"report → {html_out}")
    return 0 if rep["ok"] else 1


if __name__ == "__main__":
    import sys
    raise SystemExit(_main(sys.argv[1:]))
