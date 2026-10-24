import UIKit
import WebKit

class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {

    /// Lumina 网页地址（必须带 sharecode，否则页面会提示链接不完整）
    private static let appURL = URL(string: "https://pure-chat.app.workbuddy.host/?sharecode=MJF2XZZBZC")!

    /// 登录凭据（localStorage）的原生备份键 —— 网页被系统清掉时用它补回来
    private static let backupKey = "lumina_ls_backup"

    private var webView: WKWebView!

    override func loadView() {
        let config = WKWebViewConfiguration()

        // 关键：使用默认持久化数据仓库。
        // localStorage（登录凭据所在）和 Cookie 会跨启动保留 —— 登录一次，长期有效。
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        // 兜底：启动瞬间把上次备份的 localStorage 写回去（页面脚本执行之前）
        if let script = Self.restoreScript() {
            config.userContentController.addUserScript(script)
        }

        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        view = webView

        installBackupHooks()
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

    // MARK: - 登录凭据备份 / 恢复

    /// 生成「把备份写回 localStorage」的注入脚本（在文档加载最早期执行）
    private static func restoreScript() -> WKUserScript? {
        guard let json = UserDefaults.standard.string(forKey: backupKey), !json.isEmpty else { return nil }
        // JSON 里的 U+2028/2029 在 JS 字面量中不合法，先转义
        let safe = json
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        let src = """
        (function(){try{
          var d = \(safe);
          for (var k in d) {
            if (localStorage.getItem(k) === null) {
              try { localStorage.setItem(k, d[k]); } catch(e) {}
            }
          }
        }catch(e){}})();
        """
        return WKUserScript(source: src, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    private func installBackupHooks() {
        let names: [Notification.Name] = [
            UIApplication.didEnterBackgroundNotification,
            UIApplication.willResignActiveNotification,
            UIApplication.willTerminateNotification
        ]
        names.forEach {
            NotificationCenter.default.addObserver(self, selector: #selector(backupStorage), name: $0, object: nil)
        }
    }

    /// 把网页当前的 localStorage 全量快照存进 UserDefaults。
    /// 下次冷启动若发现 localStorage 被系统清空，就靠它把登录状态补回去。
    @objc private func backupStorage() {
        let js = """
        (function(){try{
          var o = {};
          for (var i = 0; i < localStorage.length; i++) {
            var k = localStorage.key(i);
            if (k === 'pc_ls_backup') continue;
            o[k] = localStorage.getItem(k);
          }
          return JSON.stringify(o);
        }catch(e){ return ''; }})()
        """
        webView.evaluateJavaScript(js) { result, _ in
            guard let s = result as? String, !s.isEmpty else { return }
            UserDefaults.standard.set(s, forKey: ViewController.backupKey)
        }
    }

    // MARK: - 生命周期

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 页面就绪后再存一次，保证备份是最新的
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.backupStorage()
        }
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
