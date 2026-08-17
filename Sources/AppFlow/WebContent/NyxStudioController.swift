// NyxStudioController.swift
// Modern WebView controller with Liquid Glass navigation

import UIKit
import WebKit
import SwiftUI

// MARK: - Web Content Controller

final class NyxStudioController: UIViewController {

    // MARK: - Properties

    var startURL: URL
    private let allowClose: Bool
    private let onClose: () -> Void

    private var webView: WKWebView!
    private var statusBarStyle: UIStatusBarStyle = .lightContent
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let liquid = NyxCanvasSlider()

    private var progressObserver: NSKeyValueObservation?
    private var canGoBackObserver: NSKeyValueObservation?
    private var canGoForwardObserver: NSKeyValueObservation?

    /// Cherry Flow web→native bridge. Retained here while registered on
    /// the web view's content controller; nil for non-cherry_flow builds.
    private var webBridge: NyxSparkBridge?

    // #4: 2nd-redirect → stub watcher (all_high_risk + client). nil =
    // disabled (normal apps). We count navigation hops; if after the page
    // settles fewer than ``minRedirects`` occurred, the chain dead-ended
    // (no real offer for this geo) → load the stub instead of leaving the
    // visitor on a blank/dead page.
    private let redirectPolicy: NyxLibraryResponse.NyxDirector?
    private var redirectHops = 0
    private var stubLoaded = false
    private var settleScheduled = false

    // MARK: - Init

    init(
        url: URL,
        allowClose: Bool = true,
        redirectPolicy: NyxLibraryResponse.NyxDirector? = nil,
        onClose: @escaping () -> Void = {}
    ) {
        self.startURL = url
        self.allowClose = allowClose
        self.redirectPolicy = redirectPolicy
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(url:allowClose:redirectPolicy:onClose:)") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupWebView()
        setupProgressView()
        setupLiquidSlider()
        bindObservers()
        loadURL(startURL)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return statusBarStyle
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // If the WebView is being torn down (e.g. state transition to
        // overlay), dismiss any active JS dialog so WKWebView doesn't
        // crash from a dangling completion handler.
        dismissActiveJSDialogs()
    }

    deinit {
        progressObserver?.invalidate()
        canGoBackObserver?.invalidate()
        canGoForwardObserver?.invalidate()
        // Drop the script-message handler so the content controller
        // doesn't retain the bridge past this controller's life.
        if webBridge != nil {
            webView?.configuration.userContentController
                .removeScriptMessageHandler(forName: NyxSparkBridge.handlerName)
        }
        dismissActiveJSDialogs()
    }

    /// Dismiss the currently-presented UIAlertController (JS alert/confirm/
    /// prompt) and invoke its completion handler with a safe default so
    /// WKWebView doesn't crash during teardown.
    private func dismissActiveJSDialogs() {
        guard let alert = presentedViewController as? UIAlertController,
              alert.title == nil else { return }
        // JS dialogs have nil title. Invoke the "Cancel" action if
        // available (confirm→false, prompt→nil, alert→OK).
        if let cancel = alert.actions.first(where: { $0.style == .cancel }) {
            // Simulate tapping Cancel by calling the handler
            (cancel.value(forKey: "handler") as? (() -> Void))?()
        }
        alert.dismiss(animated: false)
    }

    override var shouldAutorotate: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .allButUpsideDown }
    override var prefersStatusBarHidden: Bool { true }

    // MARK: - Setup

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Cherry Flow web→native bridge (cherry_flow builds only). Lets
        // the offer page signal in-app conversions (e.g. deposit) to
        // native, which forwards them to /client/event.
        if NyxDispatcherConfig.cherryFlowEnabled {
            let ucc = WKUserContentController()
            let bridge = NyxSparkBridge()
            ucc.add(bridge, name: NyxSparkBridge.handlerName)
            ucc.addUserScript(
                WKUserScript(
                    source: NyxSparkBridge.injectedJS,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: false
                )
            )
            config.userContentController = ucc
            self.webBridge = bridge
        }

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        webView.uiDelegate = self

        // Anti-debug: disable Web Inspector in production builds. Kept
        // available in DEBUG so we can still inspect our own pages.
        #if !DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = false
        }
        #endif

        // Transparent background for adaptive coloring
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        // Clean scroll — hide indicators only, keep smooth bounce
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false

        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupProgressView() {
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = UIColor(red: 0.922, green: 0.271, blue: 0.353, alpha: 1)
        progressView.trackTintColor = .clear
        progressView.isHidden = true

        view.addSubview(progressView)

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])
    }

    private func setupLiquidSlider() {
        liquid.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(liquid)

        NSLayoutConstraint.activate([
            liquid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            liquid.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            liquid.heightAnchor.constraint(equalToConstant: 44),
            liquid.widthAnchor.constraint(equalToConstant: 44)
        ])

        // Back action (swipe LEFT)
        liquid.onBack = { [weak self] in
            guard let self else { return }
            if self.webView.canGoBack {
                self.webView.goBack()
            } else if self.allowClose {
                self.closeWebView()
            } else {
                self.liquid.bump()
            }
        }

        // Reload action (swipe RIGHT)
        liquid.onReload = { [weak self] in
            self?.webView.reload()
        }

        // Close action (tap when no history)
        liquid.onClose = { [weak self] in
            guard let self, self.allowClose else { return }
            self.closeWebView()
        }

        liquid.canGoBackProvider = { [weak self] in
            self?.webView.canGoBack ?? false
        }

        liquid.allowCloseProvider = { [weak self] in
            self?.allowClose ?? false
        }
    }

    private func bindObservers() {
        progressObserver = webView.observe(\.estimatedProgress, options: .new) { [weak self] webView, _ in
            guard let self else { return }
            let progress = Float(webView.estimatedProgress)
            self.progressView.setProgress(progress, animated: true)
            self.progressView.isHidden = progress >= 1.0
        }

        canGoBackObserver = webView.observe(\.canGoBack, options: .new) { [weak self] _, _ in
            self?.liquid.updateState()
        }

        canGoForwardObserver = webView.observe(\.canGoForward, options: .new) { [weak self] _, _ in
            self?.liquid.updateState()
        }
    }

    // MARK: - Loading

    private func loadURL(_ url: URL) {
        let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
        webView.load(request)
        NyxMint.log("Loading: \(url)")
    }

    /// Called from SwiftUI's updateUIViewController when the URL changes
    /// (e.g. Fortune Wheel CTA → WebView landing). Load about:blank first
    /// to clear the old page, then navigate to the new URL.
    func loadBlankAndNavigate(to url: URL) {
        webView.load(URLRequest(url: URL(string: "about:blank")!))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.loadURL(url)
        }
    }

    private func closeWebView() {
        NyxMint.log("WebView closed")
        onClose()
        dismiss(animated: true)
    }

    // MARK: - Adaptive Background

    private func syncBackgroundWithPage() {
        let js = """
        (function() {
            const body = document.body;
            const html = document.documentElement;
            function bg(el) { return window.getComputedStyle(el).backgroundColor; }
            function pick(c) {
                if (!c) return null;
                if (c === "rgba(0, 0, 0, 0)" || c === "transparent") return null;
                return c;
            }
            return pick(body ? bg(body) : null) || pick(html ? bg(html) : null) || null;
        })();
        """

        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self else { return }
            guard let css = result as? String, let color = UIColor(cssRGBA: css) else {
                self.view.backgroundColor = .black
                self.statusBarStyle = .lightContent
                self.setNeedsStatusBarAppearanceUpdate()
                return
            }
            // Compute perceived brightness — dark bg → light status bar, light bg → dark status bar
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let brightness = (0.299 * r + 0.587 * g + 0.114 * b)
            self.statusBarStyle = brightness > 0.55 ? .darkContent : .lightContent
            self.setNeedsStatusBarAppearanceUpdate()
            // Push to SwiftUI so the ZStack safe-area fill matches the page
            NyxDispatcherRouter.shared.webViewBackgroundColor = Color(uiColor: color)
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                self.view.backgroundColor = color
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension NyxStudioController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NyxMint.log("Page loaded: \(webView.url?.absoluteString ?? "")")
        syncBackgroundWithPage()
        scheduleStubCheckIfNeeded()
        // #5 — report the final (post-JS-redirect) URL so the server caches
        // it per device and can return it on the next /init (sticky offer).
        if let final = webView.url, let scheme = final.scheme, scheme.hasPrefix("http") {
            let uniqueId = NyxGallery.shared.uniqueID
            Task {
                await NyxRosterClient.shared.reportFinalURL(
                    NyxEchoRequest.create(uniqueId: uniqueId, finalUrl: final.absoluteString)
                )
            }
        }
    }

    // MARK: - #4 redirect → stub watcher

    /// Each new provisional load (initial + JS redirects) is a hop.
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if redirectPolicy != nil { redirectHops += 1 }
    }

    /// HTTP 3xx server redirects within the same navigation also count.
    func webView(
        _ webView: WKWebView,
        didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!
    ) {
        if redirectPolicy != nil { redirectHops += 1 }
    }

    /// After the page settles, decide: enough hops → real offer, keep it;
    /// too few → dead-end → load the stub. Runs at most once; a short
    /// delay lets late JS redirects register before we judge.
    private func scheduleStubCheckIfNeeded() {
        // No ``stub`` requirement here: when the operator leaves stub_url
        // empty, a dead-end chain must fall back to NATIVE (not sit on the
        // dead-end page). Apps that DO set a stub keep the old behaviour.
        guard let policy = redirectPolicy, policy.shouldFollow,
              !stubLoaded, !settleScheduled else { return }
        settleScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self, !self.stubLoaded else { return }
            self.settleScheduled = false
            if self.redirectHops < policy.minRedirects {
                self.stubLoaded = true
                if let stub = policy.stub {
                    NyxMint.log("Redirect dead-end (\(self.redirectHops) < \(policy.minRedirects)) → stub")
                    self.loadURL(stub)
                } else {
                    NyxMint.log("Redirect dead-end (\(self.redirectHops) < \(policy.minRedirects)) → native")
                    Task { @MainActor in NyxDispatcherRouter.shared.startNativeFlow() }
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NyxMint.error("Navigation failed", error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NyxMint.error("Provisional navigation failed", error)

        let alert = UIAlertController(
            title: "Loading Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
            self?.loadURL(self?.startURL ?? URL(string: "about:blank")!)
        })
        if allowClose {
            alert.addAction(UIAlertAction(title: "Close", style: .cancel) { [weak self] _ in
                self?.closeWebView()
            })
        }
        present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        let scheme = (url.scheme ?? "").lowercased()

        // Handle special schemes
        if ["tel", "mailto", "sms", "facetime"].contains(scheme) {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        // Handle target=_blank (open in same webview)
        if navigationAction.targetFrame == nil {
            webView.load(URLRequest(url: url))
            decisionHandler(.cancel)
            return
        }

        // Handle App Store links
        if url.host?.contains("apps.apple.com") == true || url.host?.contains("itunes.apple.com") == true {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }
}

// MARK: - WKUIDelegate

extension NyxStudioController: WKUIDelegate {

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Handle window.open() in same webview
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })
        present(alert, animated: true)
    }
}

// MARK: - Liquid Glass Slider

final class NyxCanvasSlider: UIView {

    var onBack: (() -> Void)?
    var onReload: (() -> Void)?
    var onClose: (() -> Void)?
    var canGoBackProvider: (() -> Bool)?
    var allowCloseProvider: (() -> Bool)?

    // Sizing
    private let collapsedSize: CGFloat = 44
    private let expandedWidth: CGFloat = 280
    private let thumbDiameter: CGFloat = 28
    private let triggerRatio: CGFloat = 0.75

    // Opacity
    private let idleAlpha: CGFloat = 0.55
    private let expandedAlpha: CGFloat = 0.70

    private enum State { case collapsed, expanded, animating }
    private var state: State = .collapsed

    // Constraints for animation
    private weak var leadingConstraint: NSLayoutConstraint?
    private weak var widthConstraint: NSLayoutConstraint?

    // Overlay for dismiss
    private var overlayButton: UIButton?

    // Track (expanded background)
    private let track = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))

    // Center button (collapsed state)
    private let centerButton = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let centerIcon = UIImageView(image: UIImage(systemName: "circle.grid.2x2.fill"))

    // Labels inside track
    private let leftLabel = UILabel()
    private let rightLabel = UILabel()
    private let leftIcon = UIImageView(image: UIImage(systemName: "chevron.left"))
    private let rightIcon = UIImageView(image: UIImage(systemName: "arrow.clockwise"))

    // Thumb (draggable)
    private let thumb = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let thumbDot = UIView()

    // Hint chevrons
    private var leftHints: [UIImageView] = []
    private var rightHints: [UIImageView] = []
    private var hintTimer: Timer?
    private var hintStep: Int = 0

    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private var isDragging = false
    private var didTrigger = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        captureConstraints()
    }

    private func captureConstraints() {
        guard let superview else { return }
        if widthConstraint == nil {
            widthConstraint = constraints.first { $0.firstAttribute == .width && $0.relation == .equal }
        }
        if leadingConstraint == nil {
            leadingConstraint = superview.constraints.first {
                ($0.firstItem as? UIView) === self && $0.firstAttribute == .leading && $0.relation == .equal
            }
        }
    }

    private func setup() {
        backgroundColor = .clear
        isUserInteractionEnabled = true

        // Track (hidden in collapsed)
        track.translatesAutoresizingMaskIntoConstraints = false
        track.clipsToBounds = true
        track.layer.cornerCurve = .continuous
        track.alpha = 0
        addSubview(track)

        NSLayoutConstraint.activate([
            track.leadingAnchor.constraint(equalTo: leadingAnchor),
            track.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.topAnchor.constraint(equalTo: topAnchor),
            track.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Center button (collapsed)
        centerButton.translatesAutoresizingMaskIntoConstraints = false
        centerButton.clipsToBounds = true
        centerButton.layer.cornerCurve = .continuous
        centerButton.alpha = idleAlpha
        addSubview(centerButton)

        NSLayoutConstraint.activate([
            centerButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerButton.widthAnchor.constraint(equalToConstant: collapsedSize),
            centerButton.heightAnchor.constraint(equalToConstant: collapsedSize)
        ])

        centerIcon.translatesAutoresizingMaskIntoConstraints = false
        centerIcon.contentMode = .scaleAspectFit
        centerIcon.tintColor = .white.withAlphaComponent(0.92)
        centerButton.contentView.addSubview(centerIcon)

        NSLayoutConstraint.activate([
            centerIcon.centerXAnchor.constraint(equalTo: centerButton.contentView.centerXAnchor),
            centerIcon.centerYAnchor.constraint(equalTo: centerButton.contentView.centerYAnchor),
            centerIcon.widthAnchor.constraint(equalToConstant: 18),
            centerIcon.heightAnchor.constraint(equalToConstant: 18)
        ])

        // Labels in track
        setupLabel(leftLabel, text: "Back")
        setupLabel(rightLabel, text: "Reload")
        setupIcon(leftIcon)
        setupIcon(rightIcon)

        track.contentView.addSubview(leftIcon)
        track.contentView.addSubview(leftLabel)
        track.contentView.addSubview(rightLabel)
        track.contentView.addSubview(rightIcon)

        NSLayoutConstraint.activate([
            leftIcon.leadingAnchor.constraint(equalTo: track.contentView.leadingAnchor, constant: 16),
            leftIcon.centerYAnchor.constraint(equalTo: track.contentView.centerYAnchor),
            leftIcon.widthAnchor.constraint(equalToConstant: 14),
            leftIcon.heightAnchor.constraint(equalToConstant: 14),

            leftLabel.leadingAnchor.constraint(equalTo: leftIcon.trailingAnchor, constant: 6),
            leftLabel.centerYAnchor.constraint(equalTo: track.contentView.centerYAnchor),

            rightIcon.trailingAnchor.constraint(equalTo: track.contentView.trailingAnchor, constant: -16),
            rightIcon.centerYAnchor.constraint(equalTo: track.contentView.centerYAnchor),
            rightIcon.widthAnchor.constraint(equalToConstant: 14),
            rightIcon.heightAnchor.constraint(equalToConstant: 14),

            rightLabel.trailingAnchor.constraint(equalTo: rightIcon.leadingAnchor, constant: -6),
            rightLabel.centerYAnchor.constraint(equalTo: track.contentView.centerYAnchor)
        ])

        // Thumb
        thumb.translatesAutoresizingMaskIntoConstraints = false
        thumb.clipsToBounds = true
        thumb.layer.cornerCurve = .continuous
        thumb.alpha = 0
        addSubview(thumb)

        NSLayoutConstraint.activate([
            thumb.centerXAnchor.constraint(equalTo: centerXAnchor),
            thumb.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumb.widthAnchor.constraint(equalToConstant: thumbDiameter),
            thumb.heightAnchor.constraint(equalToConstant: thumbDiameter)
        ])

        thumbDot.translatesAutoresizingMaskIntoConstraints = false
        thumbDot.backgroundColor = .white.withAlphaComponent(0.55)
        thumbDot.layer.cornerRadius = 2
        thumbDot.layer.cornerCurve = .continuous
        thumb.contentView.addSubview(thumbDot)

        NSLayoutConstraint.activate([
            thumbDot.centerXAnchor.constraint(equalTo: thumb.contentView.centerXAnchor),
            thumbDot.centerYAnchor.constraint(equalTo: thumb.contentView.centerYAnchor),
            thumbDot.widthAnchor.constraint(equalToConstant: 4),
            thumbDot.heightAnchor.constraint(equalToConstant: 4)
        ])

        // Hint chevrons
        buildHintChevrons()

        // Gestures
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        centerButton.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        thumb.addGestureRecognizer(pan)

        haptic.prepare()
    }

    private func buildHintChevrons() {
        let hintSize: CGFloat = 12
        let hintGap: CGFloat = 6

        for i in 0..<3 {
            let left = UIImageView(image: UIImage(systemName: "chevron.left"))
            let right = UIImageView(image: UIImage(systemName: "chevron.right"))

            for v in [left, right] {
                v.translatesAutoresizingMaskIntoConstraints = false
                v.contentMode = .scaleAspectFit
                v.tintColor = .white.withAlphaComponent(0.85)
                v.alpha = 0
                addSubview(v)

                NSLayoutConstraint.activate([
                    v.centerYAnchor.constraint(equalTo: centerYAnchor),
                    v.widthAnchor.constraint(equalToConstant: hintSize),
                    v.heightAnchor.constraint(equalToConstant: hintSize)
                ])
            }

            left.trailingAnchor.constraint(equalTo: thumb.leadingAnchor, constant: -(CGFloat(i + 1) * (hintSize + hintGap))).isActive = true
            right.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: CGFloat(i + 1) * (hintSize + hintGap)).isActive = true

            leftHints.append(left)
            rightHints.append(right)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        centerButton.layer.cornerRadius = collapsedSize / 2
        track.layer.cornerRadius = bounds.height / 2
        thumb.layer.cornerRadius = thumbDiameter / 2
    }

    // MARK: - State

    func updateState() {
        let canGoBack = canGoBackProvider?() ?? false
        let allowClose = allowCloseProvider?() ?? false

        if state == .expanded {
            leftLabel.text = canGoBack ? "Back" : (allowClose ? "Close" : "Back")
            leftIcon.image = UIImage(systemName: canGoBack ? "chevron.left" : (allowClose ? "xmark" : "chevron.left"))
            leftLabel.alpha = (canGoBack || allowClose) ? 1.0 : 0.5
            leftIcon.alpha = (canGoBack || allowClose) ? 1.0 : 0.5
        }
    }

    // MARK: - Expand / Collapse

    @objc private func handleTap() {
        switch state {
        case .collapsed: expand()
        case .expanded: collapse()
        case .animating: break
        }
    }

    private func expand() {
        captureConstraints()
        guard state == .collapsed, let superview, let leadingConstraint, let widthConstraint else { return }
        state = .animating

        haptic.impactOccurred(intensity: 0.5)
        addOverlay(in: superview)

        let targetLeading = max(12, (superview.bounds.width - expandedWidth) / 2)

        widthConstraint.constant = expandedWidth
        leadingConstraint.constant = targetLeading

        track.alpha = expandedAlpha
        thumb.alpha = expandedAlpha
        centerButton.alpha = 0

        thumb.center = CGPoint(x: bounds.midX, y: bounds.midY)
        didTrigger = false
        updateState()
        hintStep = 0

        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0.6,
            options: [.allowUserInteraction, .curveEaseOut]
        ) {
            superview.layoutIfNeeded()
        } completion: { _ in
            self.state = .expanded
            self.startHintSequence()
        }
    }

    private func collapse() {
        captureConstraints()
        guard state == .expanded, let superview, let leadingConstraint, let widthConstraint else { return }
        state = .animating

        stopHintSequence()
        removeOverlay()
        snapThumbToCenter(animated: true)

        widthConstraint.constant = collapsedSize
        leadingConstraint.constant = 16

        UIView.animate(
            withDuration: 0.24,
            delay: 0,
            usingSpringWithDamping: 0.92,
            initialSpringVelocity: 0.7,
            options: [.allowUserInteraction, .curveEaseOut]
        ) {
            self.track.alpha = 0
            self.thumb.alpha = 0
            self.centerButton.alpha = self.idleAlpha
            superview.layoutIfNeeded()
        } completion: { _ in
            self.state = .collapsed
        }
    }

    // MARK: - Pan Gesture

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        guard state == .expanded else { return }

        let t = gr.translation(in: self)
        gr.setTranslation(.zero, in: self)

        switch gr.state {
        case .began:
            isDragging = true
            didTrigger = false
            stopHintSequence()
            haptic.prepare()

        case .changed:
            var newX = thumb.center.x + t.x
            let leftLimit = track.frame.minX + 14 + thumbDiameter / 2
            let rightLimit = track.frame.maxX - 14 - thumbDiameter / 2
            newX = min(max(newX, leftLimit), rightLimit)

            thumb.center = CGPoint(x: newX, y: thumb.center.y)
            updateEmphasis()

            if !didTrigger, resolveAction() != .none {
                didTrigger = true
                haptic.impactOccurred(intensity: 0.35)
            }

        case .ended, .cancelled, .failed:
            isDragging = false
            let action = resolveAction()

            switch action {
            case .back:
                haptic.impactOccurred(intensity: 0.85)
                onBack?()
                collapse()

            case .reload:
                haptic.impactOccurred(intensity: 0.85)
                onReload?()
                collapse()

            case .none:
                snapThumbToCenter(animated: true)
                startHintSequence()
            }

        default:
            break
        }
    }

    private enum Action { case none, back, reload }

    private func resolveAction() -> Action {
        let dx = thumb.center.x - bounds.midX
        let usable = (expandedWidth / 2) - 20

        if dx < 0 {
            return abs(dx) / usable >= triggerRatio ? .back : .none
        } else if dx > 0 {
            return dx / usable >= triggerRatio ? .reload : .none
        }
        return .none
    }

    private func snapThumbToCenter(animated: Bool) {
        let target = CGPoint(x: bounds.midX, y: bounds.midY)
        if animated {
            UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                self.thumb.center = target
                self.resetEmphasis()
            }
        } else {
            thumb.center = target
            resetEmphasis()
        }
    }

    private func updateEmphasis() {
        let dx = thumb.center.x - bounds.midX
        if dx < 0 {
            leftLabel.alpha = 1
            leftIcon.alpha = 1
            rightLabel.alpha = 0.5
            rightIcon.alpha = 0.5
        } else if dx > 0 {
            rightLabel.alpha = 1
            rightIcon.alpha = 1
            leftLabel.alpha = 0.5
            leftIcon.alpha = 0.5
        } else {
            resetEmphasis()
        }
    }

    private func resetEmphasis() {
        leftLabel.alpha = 1
        leftIcon.alpha = 1
        rightLabel.alpha = 1
        rightIcon.alpha = 1
        updateState()
    }

    func bump() {
        haptic.impactOccurred(intensity: 0.45)
        UIView.animate(withDuration: 0.1) {
            self.thumb.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            UIView.animate(withDuration: 0.12) {
                self.thumb.transform = .identity
            }
        }
    }

    // MARK: - Hint Animation

    private func startHintSequence() {
        guard hintTimer == nil else { return }
        for v in leftHints + rightHints { v.alpha = 0.1 }
        hintStep = 0
        hintTimer = Timer.scheduledTimer(timeInterval: 0.45, target: self, selector: #selector(stepHint), userInfo: nil, repeats: true)
        RunLoop.main.add(hintTimer!, forMode: .common)
        stepHint()
    }

    private func stopHintSequence() {
        hintTimer?.invalidate()
        hintTimer = nil
        for v in leftHints + rightHints { v.alpha = 0 }
    }

    @objc private func stepHint() {
        guard state == .expanded, !isDragging else { return }

        UIView.animate(withDuration: 0.1) {
            for v in self.leftHints + self.rightHints { v.alpha = 0.1 }
        }

        let idx = hintStep % 3
        hintStep += 1

        let L = leftHints[idx]
        let R = rightHints[idx]

        UIView.animate(withDuration: 0.55, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
            L.alpha = 0.72
            R.alpha = 0.72
        } completion: { _ in
            UIView.animate(withDuration: 0.18, delay: 0.02, options: [.allowUserInteraction]) {
                L.alpha = 0.1
                R.alpha = 0.1
            }
        }
    }

    // MARK: - Helpers

    private func setupLabel(_ label: UILabel, text: String) {
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white.withAlphaComponent(0.90)
    }

    private func setupIcon(_ icon: UIImageView) {
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentMode = .scaleAspectFit
        icon.tintColor = .white.withAlphaComponent(0.92)
    }

    private func addOverlay(in superview: UIView) {
        guard overlayButton == nil else { return }
        let b = UIButton(type: .custom)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.backgroundColor = .clear
        b.addTarget(self, action: #selector(overlayTapped), for: .touchUpInside)
        superview.insertSubview(b, belowSubview: self)

        NSLayoutConstraint.activate([
            b.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
            b.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
            b.topAnchor.constraint(equalTo: superview.topAnchor),
            b.bottomAnchor.constraint(equalTo: superview.bottomAnchor)
        ])

        overlayButton = b
    }

    private func removeOverlay() {
        overlayButton?.removeFromSuperview()
        overlayButton = nil
    }

    @objc private func overlayTapped() {
        if state == .expanded { collapse() }
    }
}

// MARK: - CSS Color Parser

private extension UIColor {
    convenience init?(cssRGBA: String) {
        let s = cssRGBA
            .replacingOccurrences(of: "rgba(", with: "")
            .replacingOccurrences(of: "rgb(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: " ", with: "")

        let parts = s.split(separator: ",").map { String($0) }
        guard parts.count == 3 || parts.count == 4 else { return nil }

        func f(_ i: Int) -> CGFloat? {
            guard i < parts.count, let v = Double(parts[i]) else { return nil }
            return CGFloat(v)
        }

        guard let r = f(0), let g = f(1), let b = f(2) else { return nil }
        let a: CGFloat = (parts.count == 4 ? (Double(parts[3]).map { CGFloat($0) } ?? 1) : 1)

        self.init(red: r/255, green: g/255, blue: b/255, alpha: a)
    }
}

// MARK: - SwiftUI Wrapper

struct NyxStudioView: UIViewControllerRepresentable {

    let url: URL
    let allowClose: Bool
    let redirectPolicy: NyxLibraryResponse.NyxDirector?
    let onClose: () -> Void

    init(
        url: URL,
        allowClose: Bool = true,
        redirectPolicy: NyxLibraryResponse.NyxDirector? = nil,
        onClose: @escaping () -> Void = {}
    ) {
        self.url = url
        self.allowClose = allowClose
        self.redirectPolicy = redirectPolicy
        self.onClose = onClose
    }

    func makeUIViewController(context: Context) -> NyxStudioController {
        NyxStudioController(
            url: url, allowClose: allowClose, redirectPolicy: redirectPolicy, onClose: onClose
        )
    }

    func updateUIViewController(_ vc: NyxStudioController, context: Context) {
        // Reload when the URL changes — e.g. Fortune Wheel → WebView landing
        if vc.startURL != url {
            vc.startURL = url
            vc.loadBlankAndNavigate(to: url)
        }
    }
}
