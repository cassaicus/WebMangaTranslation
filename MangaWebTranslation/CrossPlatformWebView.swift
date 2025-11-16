internal import Combine
import SwiftUI
import Translation
import WebKit

// MARK: - WebView管理クラス
class WebViewManager: ObservableObject {
    @Published var webView: WKWebView?

    func captureWebView(completion: @escaping (CGImage?) -> Void) {
        #if canImport(UIKit)
        webView?.takeSnapshot(with: nil) { image, error in
            guard let image = image, error == nil else {
                print("Snapshot failed: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            DispatchQueue.main.async { completion(image.cgImage) }
        }
        #elseif canImport(AppKit)
        webView?.takeSnapshot(with: nil) { image, error in
            guard let image = image, error == nil else {
                print("Snapshot failed: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            DispatchQueue.main.async { completion(cgImage) }
        }
        #endif
    }
}

// MARK: - 共通 WebView Representable
#if canImport(UIKit)
struct PlatformWebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var manager: WebViewManager

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        self.manager.webView = webView
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

#elseif canImport(AppKit)
struct PlatformWebView: NSViewRepresentable {
    let url: URL
    @ObservedObject var manager: WebViewManager

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        self.manager.webView = webView
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#endif

// MARK: - 翻訳オーバーレイビュー
struct TranslationOverlayView: View {
    let translationData: [TranslationData]
    let frameSize: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(translationData.indices, id: \.self) { index in
                let data = translationData[index]
                Text(data.translatedText)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                    .position(
                        x: data.boundingBox.origin.x * frameSize.width + data.boundingBox.width * frameSize.width / 2,
                        y: data.boundingBox.origin.y * frameSize.height + data.boundingBox.height * frameSize.height / 2
                    )
            }
        }
    }
}

// MARK: - メインビュー
struct CrossPlatformWebView: View {
    @State private var address: String = "https://tonarinoyj.jp"
    @StateObject private var webViewManager = WebViewManager()
    @State private var capturedImage: CGImage?
    @State private var translationData: [TranslationData] = []
    @State private var translationSession: TranslationSession?
    @State private var translationConfig: TranslationSession.Configuration?

    var body: some View {
        Group {
            if #available(macOS 14.0, iOS 17.0, *) {
                contentView
                    .translationTask(translationConfig) { session in
                        self.translationSession = nil
                        do {
                            try await session.prepareTranslation()
                            self.translationSession = session
                            print("Translation models prepared or already installed.")
                        } catch {
                            print("Translation model preparation failed: \(error.localizedDescription)")
                            // Clear the config on failure to allow potential retry.
                            self.translationConfig = nil
                        }
                    }
            } else {
                contentView
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            // WebView 本体
            GeometryReader { geometry in
                ZStack {
                    PlatformWebView(url: URL(string: address)!, manager: webViewManager)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if !translationData.isEmpty {
                        TranslationOverlayView(translationData: translationData, frameSize: geometry.size)
                    }
                }
            }

            Divider()

            // 下部ツールバー
            HStack {
                Button(action: {
                    // ダミーアクション
                    print("Dummy button tapped")
                }) {
                    Image(systemName: "chevron.left")
                }

                TextField("Enter URL", text: $address)
                    .textFieldStyle(.roundedBorder)

                Button("Go") {
                    // とりあえずState更新で再ロード
                }

                Button(action: {
                    self.translationData = []
                    guard let session = self.translationSession else {
                        print("Translation session is not ready.")
                        return
                    }

                    webViewManager.captureWebView { image in
                        self.capturedImage = image
                        guard let capturedImage = image else { return }

                        TranslationService.recognizeText(from: capturedImage) { detectedTexts in
                            if #available(macOS 14.0, iOS 17.0, *) {
                                TranslationService.translate(detectedTexts: detectedTexts, with: session) { translatedData in
                                    self.translationData = translatedData
                                    print("Translated \(translatedData.count) text blocks.")
                                }
                            }
                        }
                    }
                }) {
                    Image(systemName: "camera.viewfinder")
                }
                .disabled(translationSession == nil)
            }
            .padding(8)
            .background(Color(white: 0.95))
        }
        .modifier(AdaptiveFrame())
        .onAppear {
            if #available(macOS 14.0, iOS 17.0, *) {
                // Automatically prepare for translation when the view appears.
                self.translationConfig = .init(source: .init(identifier: "ja"), target: .init(identifier: "en"))
            }
        }
    }
}

// MARK: - プレビュー
// MARK: - Adaptive Frame Modifier
struct AdaptiveFrame: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content.frame(minWidth: 600, minHeight: 400)
        #else
        content
        #endif
    }
}

// MARK: - プレビュー
#Preview {
    CrossPlatformWebView()
}
