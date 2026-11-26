


import UIKit
import WebKit
import SwiftUI



final class NyxVaultController: UIViewController {

    

    var startURL: URL
    private let allowClose: Bool
    private let onClose: () -> Void
    private let reportFinalURL: Bool

    private var webView: WKWebView!
    private var statusBarStyle: UIStatusBarStyle = .lightContent
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let liquid = NyxAspen()

    private var progressObserver: NSKeyValueObservation?
    private var canGoBackObserver: NSKeyValueObservation?
    private var canGoForwardObserver: NSKeyValueObservation?

    
    
    private var webBridge: NyxSparkBridge?

    
    
    
    
    
    private let redirectPolicy: NyxLibraryResponse.NyxMarker?
    private var redirectHops = 0
    private var stubLoaded = false
    private var settleScheduled = false
    private var finalURLReportWorkItem: DispatchWorkItem?

    

    init(
        url: URL,
        allowClose: Bool = true,
        redirectPolicy: NyxLibraryResponse.NyxMarker? = nil,
        reportFinalURL: Bool = true,
        onClose: @escaping () -> Void = {}
    ) {
        self.startURL = url
        self.allowClose = allowClose
        self.redirectPolicy = redirectPolicy
        self.reportFinalURL = reportFinalURL
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(url:allowClose:redirectPolicy:onClose:)") }

    

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
        
        
        
        dismissActiveJSDialogs()
    }

    deinit {
        progressObserver?.invalidate()
        canGoBackObserver?.invalidate()
        canGoForwardObserver?.invalidate()
        
        
        if webBridge != nil {
            webView?.configuration.userContentController
                .removeScriptMessageHandler(forName: NyxSparkBridge.handlerName)
        }
        dismissActiveJSDialogs()
    }

    
    
    
    private func dismissActiveJSDialogs() {
        guard let alert = presentedViewController as? UIAlertController,
              alert.title == nil else { return }
        
        
        if let cancel = alert.actions.first(where: { $0.style == .cancel }) {
            
            (cancel.value(forKey: "handler") as? (() -> Void))?()
        }
        alert.dismiss(animated: false)
    }

    override var shouldAutorotate: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .allButUpsideDown }
    override var prefersStatusBarHidden: Bool { true }

    

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        
        
        
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

        
        
        #if !DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = false
        }
        #endif

        
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false

        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
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
            liquid.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 5),
            liquid.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -72),
            liquid.heightAnchor.constraint(equalToConstant: 56),
            liquid.widthAnchor.constraint(equalToConstant: 24)
        ])

        
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

        
        liquid.onReload = { [weak self] in
            self?.webView.reload()
        }

        
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

    

    private func loadURL(_ url: URL) {
        let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
        webView.load(request)
        NyxMint.log("Loading: \(url)")
    }

    
    
    
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
            
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let brightness = (0.299 * r + 0.587 * g + 0.114 * b)
            self.statusBarStyle = brightness > 0.55 ? .darkContent : .lightContent
            self.setNeedsStatusBarAppearanceUpdate()
            
            NyxDispatcherRouter.shared.webViewBackgroundColor = Color(uiColor: color)
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                self.view.backgroundColor = color
            }
        }
    }
}



extension NyxVaultController: WKNavigationDelegate {

    private static let webSchemes: Set<String> = [
        "http", "https", "about", "data", "blob", "javascript", "file"
    ]

    private func shouldOpenExternally(_ url: URL) -> Bool {
        let scheme = (url.scheme ?? "").lowercased()
        let host = (url.host ?? "").lowercased()
        let isAppStoreHost = host == "apps.apple.com"
            || host.hasSuffix(".apps.apple.com")
            || host == "itunes.apple.com"
            || host.hasSuffix(".itunes.apple.com")
        let isOAuthHost = host == "accounts.google.com"
            || host == "appleid.apple.com"
            || host == "login.microsoftonline.com"
            || host.hasSuffix(".auth0.com")
        return isAppStoreHost
            || (NyxDispatcherConfig.systemOAuthEnabled && isOAuthHost)
            || (!scheme.isEmpty && !Self.webSchemes.contains(scheme))
    }

    
    
    
    private func openExternalURL(_ url: URL) {
        let scheme = (url.scheme ?? "unknown").lowercased()
        NyxMint.log("WebView: handing \(scheme) link to iOS")
        UIApplication.shared.open(url, options: [:]) { [weak self] opened in
            guard !opened, let self, self.viewIfLoaded?.window != nil else { return }
            NyxMint.log("WebView: no application can open \(scheme) link")
            guard self.presentedViewController == nil else { return }
            let alert = UIAlertController(
                title: "App Not Available",
                message: "Install the required app and try again, or choose another payment method.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NyxMint.log("Page loaded: \(webView.url?.absoluteString ?? "")")
        syncBackgroundWithPage()
        scheduleStubCheckIfNeeded()
        scheduleFinalURLReport(for: webView)
    }

    
    
    
    private func scheduleFinalURLReport(for webView: WKWebView) {
        finalURLReportWorkItem?.cancel()
        guard reportFinalURL else { return }
        guard let candidate = webView.url,
              let scheme = candidate.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return }

        let item = DispatchWorkItem { [weak self, weak webView] in
            guard let self, let webView,
                  webView.url?.absoluteString == candidate.absoluteString else { return }
            let uniqueId = NyxGallery.shared.uniqueID
            Task {
                await NyxCompassClient.shared.reportFinalURL(
                    NyxEchoRequest.create(uniqueId: uniqueId, finalUrl: candidate.absoluteString)
                )
            }
            self.finalURLReportWorkItem = nil
        }
        finalURLReportWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25, execute: item)
    }

    

    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        finalURLReportWorkItem?.cancel()
        finalURLReportWorkItem = nil
        if redirectPolicy != nil { redirectHops += 1 }
    }

    
    func webView(
        _ webView: WKWebView,
        didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!
    ) {
        if redirectPolicy != nil { redirectHops += 1 }
    }

    
    
    
    private func scheduleStubCheckIfNeeded() {
        
        
        
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
        guard !reportFinalURL, (error as NSError).code != NSURLErrorCancelled else { return }
        Task { @MainActor in NyxDispatcherRouter.shared.showWebDefaultUnavailable() }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NyxMint.error("Provisional navigation failed", error)

        
        
        
        if !reportFinalURL, (error as NSError).code != NSURLErrorCancelled {
            Task { @MainActor in NyxDispatcherRouter.shared.showWebDefaultUnavailable() }
            return
        }

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

        
        
        
        if shouldOpenExternally(url) {
            openExternalURL(url)
            decisionHandler(.cancel)
            return
        }

        
        
        if navigationAction.targetFrame == nil {
            webView.load(URLRequest(url: url))
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }
}



extension NyxVaultController: WKUIDelegate {

    @available(iOS 15.0, *)
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        guard NyxDispatcherConfig.fileUploadEnabled else {
            decisionHandler(.deny)
            return
        }
        let allowed: Bool
        switch type {
        case .camera:
            allowed = NyxDispatcherConfig.cameraUploadEnabled
        case .microphone:
            allowed = NyxDispatcherConfig.microphoneCaptureEnabled
        case .cameraAndMicrophone:
            allowed = NyxDispatcherConfig.cameraUploadEnabled && NyxDispatcherConfig.microphoneCaptureEnabled
        @unknown default:
            allowed = false
        }
        decisionHandler(allowed ? .prompt : .deny)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        
        
        
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            if shouldOpenExternally(url) {
                openExternalURL(url)
            } else {
                webView.load(URLRequest(url: url))
            }
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



final class NyxAspen: UIView {
    var onBack: (() -> Void)?
    var onReload: (() -> Void)?
    var onClose: (() -> Void)?
    var canGoBackProvider: (() -> Bool)?
    var allowCloseProvider: (() -> Bool)?

    private enum State { case collapsed, expanded, animating }
    private var state: State = .collapsed
    private weak var widthConstraint: NSLayoutConstraint?
    private weak var trailingConstraint: NSLayoutConstraint?
    private var overlayButton: UIButton?
    private let collapsedWidth: CGFloat = 24
    private let expandedWidth: CGFloat = 104
    private let surface = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let handleButton = UIButton(type: .system)
    private let backButton = UIButton(type: .system)
    private let reloadButton = UIButton(type: .system)
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    override init(frame: CGRect) { super.init(frame: frame); setup() }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    override func didMoveToSuperview() { super.didMoveToSuperview(); captureConstraints() }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, state == .collapsed { startHandlePulse() }
        else { handleButton.layer.removeAnimation(forKey: "web-controls-pulse") }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        surface.layer.cornerRadius = 15
        surface.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            byRoundingCorners: [.topLeft, .bottomLeft],
            cornerRadii: CGSize(width: 15, height: 15)
        ).cgPath
    }

    private func setup() {
        backgroundColor = .clear
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.24
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: -3, height: 4)
        surface.translatesAutoresizingMaskIntoConstraints = false
        surface.clipsToBounds = true
        surface.layer.cornerCurve = .continuous
        addSubview(surface)
        NSLayoutConstraint.activate([
            surface.leadingAnchor.constraint(equalTo: leadingAnchor), surface.trailingAnchor.constraint(equalTo: trailingAnchor),
            surface.topAnchor.constraint(equalTo: topAnchor), surface.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        configure(handleButton, symbol: "chevron.left", label: "Open web controls")
        handleButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold),
            forImageIn: .normal
        )
        
        handleButton.imageView?.transform = CGAffineTransform(translationX: -2.5, y: 0)
        configure(backButton, symbol: "chevron.backward", label: "Go back")
        configure(reloadButton, symbol: "arrow.clockwise", label: "Reload page")
        handleButton.addTarget(self, action: #selector(toggle), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        reloadButton.addTarget(self, action: #selector(reloadTapped), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [backButton, reloadButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 2
        surface.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: surface.contentView.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: surface.contentView.trailingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: surface.contentView.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: surface.contentView.bottomAnchor, constant: -4),
        ])
        handleButton.translatesAutoresizingMaskIntoConstraints = false
        surface.contentView.addSubview(handleButton)
        NSLayoutConstraint.activate([
            handleButton.leadingAnchor.constraint(equalTo: surface.contentView.leadingAnchor),
            handleButton.trailingAnchor.constraint(equalTo: surface.contentView.trailingAnchor),
            handleButton.topAnchor.constraint(equalTo: surface.contentView.topAnchor),
            handleButton.bottomAnchor.constraint(equalTo: surface.contentView.bottomAnchor),
        ])
        backButton.alpha = 0
        reloadButton.alpha = 0
        backButton.isUserInteractionEnabled = false
        reloadButton.isUserInteractionEnabled = false
        haptic.prepare()
        startHandlePulse()
    }

    private func startHandlePulse() {
        guard handleButton.layer.animation(forKey: "web-controls-pulse") == nil else { return }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.38
        pulse.duration = 0.85
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        handleButton.layer.add(pulse, forKey: "web-controls-pulse")
    }

    private func configure(_ button: UIButton, symbol: String, label: String) {
        button.tintColor = .white.withAlphaComponent(0.94)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.accessibilityLabel = label
        button.accessibilityTraits = .button
    }

    private func captureConstraints() {
        guard let superview else { return }
        if widthConstraint == nil {
            widthConstraint = constraints.first { $0.firstAttribute == .width && $0.relation == .equal }
        }
        if trailingConstraint == nil {
            trailingConstraint = superview.constraints.first {
                ($0.firstItem as? UIView) === self && $0.firstAttribute == .trailing && $0.relation == .equal
            }
        }
    }

    func updateState() {
        let canBack = canGoBackProvider?() ?? false
        backButton.isEnabled = true
        backButton.accessibilityLabel = canBack ? "Go back" : "Close web view"
        if state == .expanded { backButton.alpha = 1 }
    }

    @objc private func toggle() {
        switch state { case .collapsed: expand(); case .expanded: collapse(); case .animating: break }
    }

    private func expand() {
        captureConstraints()
        guard state == .collapsed, let superview, let widthConstraint, let trailingConstraint else { return }
        state = .animating
        haptic.impactOccurred(intensity: 0.45)
        handleButton.layer.removeAnimation(forKey: "web-controls-pulse")
        addOverlay(in: superview)
        widthConstraint.constant = expandedWidth
        trailingConstraint.constant = -8
        backButton.isUserInteractionEnabled = true
        reloadButton.isUserInteractionEnabled = true
        handleButton.isUserInteractionEnabled = false
        updateState()
        UIView.animate(withDuration: 0.26, delay: 0, usingSpringWithDamping: 0.88, initialSpringVelocity: 0.65, options: [.allowUserInteraction, .curveEaseOut]) {
            self.backButton.alpha = 1
            self.reloadButton.alpha = 1
            self.handleButton.alpha = 0
            superview.layoutIfNeeded()
        } completion: { _ in self.state = .expanded }
    }

    private func collapse() {
        captureConstraints()
        guard state == .expanded, let superview, let widthConstraint, let trailingConstraint else { return }
        state = .animating
        removeOverlay()
        widthConstraint.constant = collapsedWidth
        trailingConstraint.constant = 5
        backButton.isUserInteractionEnabled = false
        reloadButton.isUserInteractionEnabled = false
        handleButton.isUserInteractionEnabled = true
        UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.92, initialSpringVelocity: 0.7, options: [.allowUserInteraction, .curveEaseOut]) {
            self.backButton.alpha = 0
            self.reloadButton.alpha = 0
            self.handleButton.alpha = 1
            superview.layoutIfNeeded()
        } completion: { _ in
            self.state = .collapsed
            self.startHandlePulse()
        }
    }

    @objc private func backTapped() {
        haptic.impactOccurred(intensity: 0.75)
        let canNavigate = canGoBackProvider?() ?? false
        let canClose = allowCloseProvider?() ?? false
        guard canNavigate || canClose else {
            bump()
            return
        }
        onBack?()
        collapse()
    }
    @objc private func reloadTapped() { haptic.impactOccurred(intensity: 0.75); onReload?(); collapse() }
    func bump() {
        haptic.impactOccurred(intensity: 0.45)
        UIView.animate(withDuration: 0.1) { self.backButton.transform = CGAffineTransform(scaleX: 0.86, y: 0.86) }
        completion: { _ in UIView.animate(withDuration: 0.12) { self.backButton.transform = .identity } }
    }

    private func addOverlay(in superview: UIView) {
        guard overlayButton == nil else { return }
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .clear
        button.accessibilityLabel = "Close web controls"
        button.addTarget(self, action: #selector(overlayTapped), for: .touchUpInside)
        superview.insertSubview(button, belowSubview: self)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: superview.leadingAnchor), button.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
            button.topAnchor.constraint(equalTo: superview.topAnchor), button.bottomAnchor.constraint(equalTo: superview.bottomAnchor),
        ])
        overlayButton = button
    }
    private func removeOverlay() { overlayButton?.removeFromSuperview(); overlayButton = nil }
    @objc private func overlayTapped() { if state == .expanded { collapse() } }
}



final class NyxCanvasSlider: UIView {

    var onBack: (() -> Void)?
    var onReload: (() -> Void)?
    var onClose: (() -> Void)?
    var canGoBackProvider: (() -> Bool)?
    var allowCloseProvider: (() -> Bool)?

    
    private let collapsedSize: CGFloat = 44
    private let expandedWidth: CGFloat = 280
    private let thumbDiameter: CGFloat = 28
    private let triggerRatio: CGFloat = 0.75

    
    private let idleAlpha: CGFloat = 0.55
    private let expandedAlpha: CGFloat = 0.70

    private enum State { case collapsed, expanded, animating }
    private var state: State = .collapsed

    
    private weak var leadingConstraint: NSLayoutConstraint?
    private weak var widthConstraint: NSLayoutConstraint?

    
    private var overlayButton: UIButton?

    
    private let track = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))

    
    private let centerButton = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let centerIcon = UIImageView(image: UIImage(systemName: "circle.grid.2x2.fill"))

    
    private let leftLabel = UILabel()
    private let rightLabel = UILabel()
    private let leftIcon = UIImageView(image: UIImage(systemName: "chevron.left"))
    private let rightIcon = UIImageView(image: UIImage(systemName: "arrow.clockwise"))

    
    private let thumb = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let thumbDot = UIView()

    
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

        
        buildHintChevrons()

        
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



struct NyxVaultView: UIViewControllerRepresentable {

    let url: URL
    let allowClose: Bool
    let redirectPolicy: NyxLibraryResponse.NyxMarker?
    let reportFinalURL: Bool
    let onClose: () -> Void

    init(
        url: URL,
        allowClose: Bool = true,
        redirectPolicy: NyxLibraryResponse.NyxMarker? = nil,
        reportFinalURL: Bool = true,
        onClose: @escaping () -> Void = {}
    ) {
        self.url = url
        self.allowClose = allowClose
        self.redirectPolicy = redirectPolicy
        self.reportFinalURL = reportFinalURL
        self.onClose = onClose
    }

    func makeUIViewController(context: Context) -> NyxVaultController {
        NyxVaultController(
            url: url, allowClose: allowClose, redirectPolicy: redirectPolicy,
            reportFinalURL: reportFinalURL, onClose: onClose
        )
    }

    func updateUIViewController(_ vc: NyxVaultController, context: Context) {
        
        if vc.startURL != url {
            vc.startURL = url
            vc.loadBlankAndNavigate(to: url)
        }
    }
}
