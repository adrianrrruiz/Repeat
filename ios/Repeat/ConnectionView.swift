import SwiftUI
import WebKit

struct ConnectionView: View {
    @EnvironmentObject var store: HabitStore
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing:0) {
                Text("Inicia sesión con la misma cuenta que usas en Repeat en el computador. Tus hábitos locales se conservarán.").font(.footnote).foregroundStyle(.secondary).padding().background(Color(.secondarySystemGroupedBackground))
                SignInWebView(url:store.site)
            }
            .navigationTitle("Conectar con el computador").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cerrar") { dismiss() } }; ToolbarItem(placement:.confirmationAction) { Button(store.syncing ? "Conectando…" : "Comprobar") { Task { await store.sync(); if store.connected { dismiss() } } }.disabled(store.syncing) } }
        }
    }
}
struct SignInWebView: UIViewRepresentable {
    var url: URL
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration(); config.websiteDataStore = .default()
        let web = WKWebView(frame:.zero,configuration:config); web.navigationDelegate = context.coordinator; web.uiDelegate = context.coordinator
        web.load(URLRequest(url:url)); return web
    }
    func updateUIView(_ uiView: WKWebView,context: Context) {}
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(_ webView:WKWebView,createWebViewWith configuration:WKWebViewConfiguration,for navigationAction:WKNavigationAction,windowFeatures:WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }; return nil
        }
    }
}
