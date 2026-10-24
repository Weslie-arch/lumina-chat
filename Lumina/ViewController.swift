import UIKit
import WebKit

class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {

    /// Lumina 网页地址（必须带 sharecode，否则页面会提示链接不完整）
    private static let appURL = URL(string: "https://pure-chat.app.workbuddy.host/?sharecode=MJF2XZZBZC")!

    private var webView: WKWebView!

    override func loadView() {
        let config = WKWebViewConfiguration()

        // 关键：使用默认持久化数据仓库。
        // localStorage（登录凭据所在）和 Cookie 会跨启动保留 —— 登录一次，长期有效。
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadApp()
    }

    private func loadApp() {
        var req = URLRequest(url: Self.appURL)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 25
        webView.load(req)
    }

    // MARK: - 网络恢复：加载失败时给一个重试界面，而不是白屏

    private var failedOnce = false

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleFailureIfNeed(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleFailureIfNeed(error)
    }

    private func handleFailureIfNeed(_ error: Error) {
        let code = (error as NSError).code
        // 用户主动取消（如跳转别的 App）不算失败
        if code == NSURLErrorCancelled { return }
        guard !failedOnce else { return }
        failedOnce = true
        showRetryView()
    }

    private func showRetryView() {
        let retry = UIButton(type: .system)
        retry.setTitle("网络不给力，点我重试", for: .normal)
        retry.setTitleColor(.label, for: .normal)
        retry.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        retry.backgroundColor = .secondarySystemBackground
        retry.layer.cornerRadius = 14
        retry.frame = CGRect(x: 60, y: view.bounds.midY - 25, width: view.bounds.width - 120, height: 50)
        retry.autoresizingMask = [.flexibleWidth, .flexibleTopMargin, .flexibleBottomMargin]
        retry.addTarget(self, action: #selector(retryTapped(_:)), for: .touchUpInside)
        retry.tag = 998
        view.addSubview(retry)
    }

    @objc private func retryTapped(_ sender: UIButton) {
        sender.removeFromSuperview()
        failedOnce = false
        loadApp()
    }
}
