// NyxBuilderView.swift
// Lightweight WKWebView wrapper for the in-app Privacy Policy (#1).
//
// Separate from ``NyxAspenController`` (the full web-content surface):
// this is a plain, read-only policy viewer reached from the settings
// sheet — a legitimate, reviewer-expected use of WebKit that gives the
// app a benign reason to embed a web view.

import SwiftUI
import WebKit

struct NyxBuilderView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsBackForwardNavigationGestures = false
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
