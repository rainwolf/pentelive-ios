//
//  PenteWebViewController.swift
//  penteLive
//
//  Created by rainwolf on 21/02/2017.
//  Copyright © 2017 Triade. All rights reserved.
//

import UIKit
import WebKit

/// Renders a pente.org page inside the app: a full-view WKWebView with the
/// page title in the navigation bar, a thin load-progress bar, and
/// back / forward / reload-stop controls (bottom toolbar on iPhone,
/// navigation bar on iPad). pente.org game links open as a board replay.
class PenteWebViewController: UIViewController, WKNavigationDelegate {
    let digits = CharacterSet(charactersIn: "0123456789")

    private let request: URLRequest
    private let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    private let progressView = UIProgressView(progressViewStyle: .default)
    private var observations: [NSKeyValueObservation] = []

    private lazy var backItem = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), style: .plain, target: self, action: #selector(goBack))
    private lazy var forwardItem = UIBarButtonItem(image: UIImage(systemName: "chevron.forward"), style: .plain, target: self, action: #selector(goForward))
    private lazy var reloadItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reload))
    private lazy var stopItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(stopLoading))

    @objc init(address: String) {
        request = URLRequest(url: URL(string: address)!)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.isHidden = true
        view.addSubview(progressView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                self?.updateProgress(webView.estimatedProgress)
            },
            webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
                if let title = webView.title, !title.isEmpty {
                    self?.navigationItem.title = title
                }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] _, _ in
                self?.updateNavigationItems()
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in
                self?.updateNavigationItems()
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in
                self?.updateNavigationItems()
            },
        ]

        updateNavigationItems()
        webView.load(request)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // iPhone shows the controls in the bottom toolbar; iPad puts them in the navigation bar.
        navigationController?.setToolbarHidden(traitCollection.userInterfaceIdiom != .phone, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if traitCollection.userInterfaceIdiom == .phone {
            navigationController?.setToolbarHidden(true, animated: animated)
        }
    }

    private func updateProgress(_ progress: Double) {
        let done = progress >= 1
        progressView.isHidden = done
        progressView.setProgress(done ? 0 : Float(progress), animated: !done)
    }

    private func updateNavigationItems() {
        backItem.isEnabled = webView.canGoBack
        forwardItem.isEnabled = webView.canGoForward
        let reloadOrStop = webView.isLoading ? stopItem : reloadItem

        if traitCollection.userInterfaceIdiom == .phone {
            let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            toolbarItems = [backItem, flexible, forwardItem, flexible, reloadOrStop]
        } else {
            navigationItem.rightBarButtonItems = [forwardItem, backItem, reloadOrStop]
        }
    }

    @objc private func goBack() { webView.goBack() }
    @objc private func goForward() { webView.goForward() }
    @objc private func reload() { webView.reload() }
    @objc private func stopLoading() { webView.stopLoading() }

    func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping ((WKNavigationActionPolicy) -> Void)) {
//        print(navigationAction.request.url)
        var urlStr = navigationAction.request.url?.absoluteString
//        print(urlStr)
        if navigationAction.navigationType == .linkActivated || navigationAction.navigationType == .other, (urlStr?.contains("?mobile&g="))! || (urlStr?.contains("gameServer/tb/game?gid="))! {
            if (urlStr?.contains("?mobile&g="))! {
                while !(urlStr?.hasPrefix("?mobile&g="))! {
                    let startIdx = (urlStr?.startIndex)!
                    urlStr?.remove(at: startIdx)
                }
                urlStr = urlStr?.replacingOccurrences(of: "?mobile&g=", with: "")
            }
            if (urlStr?.contains("gameServer/tb/game?gid="))! {
                while !(urlStr?.hasPrefix("gameServer/tb/game?gid="))! {
                    let startIdx = (urlStr?.startIndex)!
                    urlStr?.remove(at: startIdx)
                }
                urlStr = urlStr?.replacingOccurrences(of: "gameServer/tb/game?gid=", with: "")
            }
            var gid = ""
            for c in (urlStr?.unicodeScalars)! {
                //                print("kitten \(c) \(gid)")
                if digits.contains(c) {
                    gid = gid + "\(c)"
                } else {
                    break
                }
            }

            let game = Game()
            game.gameID = gid
            game.remainingTime = "0 days"

            let storyboard = UIStoryboard(name: "MainStoryboard", bundle: nil)
            let boardVC = storyboard.instantiateViewController(withIdentifier: "boardViewController") as! BoardViewController
            //            let boardFrame = boardVC.view.frame;
            //            boardVC.view.frame = CGRect(x: boardFrame.origin.x, y: boardFrame.origin.y, width: boardFrame.size.width, height: boardFrame.size.height - 444)
            //            boardVC.viewDidLoad()
            boardVC.activeGame = false
            boardVC.game = game
            boardVC.boardTapRecognizer.isEnabled = false
            boardVC.replayGame()

            navigationController?.pushViewController(boardVC, animated: true)

            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
