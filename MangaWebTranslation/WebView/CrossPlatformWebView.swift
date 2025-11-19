//2025/11/12.
//
//  このファイルは、アプリケーションの主要なUIを定義します。
//  WebViewの表示、URLの操作、スクリーンショットの取得、
//  翻訳の実行と結果のオーバーレイ表示など、中心的な機能を実装しています。
//  SwiftUIを使用して構築されており、iOSとmacOSで共通のコードベースで動作します。
//

internal import Combine
import SwiftUI
import Translation
import WebKit

// MARK: - WebView管理クラス

/// WKWebViewのインスタンスを管理し、ビュー階層から参照できるようにするためのObservableObject。
/// 主に、SwiftUIビューからWKWebViewのスクリーンショットを撮るために使用されます。
class WebViewManager: ObservableObject {
    /// 管理対象のWKWebViewインスタンス。
    /// @Publishedプロパティラッパーにより、このプロパティの変更がビューに通知されます。
    @Published var webView: WKWebView?
    /// WebViewが前のページに戻れる状態かどうかを保持します。
    /// このプロパティの変更はUIに自動的に通知され、戻るボタンの有効/無効状態を更新します。
    @Published var canGoBack = false

    /// WebViewの履歴を一つ前に戻します。
    func goBack() {
        webView?.goBack()
    }

    /// WebViewのコンテンツをリロードします。
    func reload() {
        webView?.reload()
    }

    /// 現在表示されているWebViewのコンテンツを画像（CGImage）としてキャプチャします。
    /// この処理は非同期で行われ、完了時にクロージャが呼び出されます。
    ///
    /// - Parameter completion: 画像のキャプチャが完了したときに呼び出されるクロージャ。
    ///                       成功した場合はCGImage、失敗した場合はnilを引数として受け取ります。
    func captureWebView(completion: @escaping (CGImage?) -> Void) {
        // 条件付きコンパイルブロックを使用して、プラットフォーム（iOS/macOS）ごとに異なるAPIを呼び出します。
        #if canImport(UIKit)
        // iOS (UIKit) の場合: WKWebViewのtakeSnapshotメソッドを使用します。
        webView?.takeSnapshot(with: nil) { image, error in
            guard let image = image, error == nil else {
                print("スナップショットの取得に失敗しました: \(error?.localizedDescription ?? "不明なエラー")")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            // UIImageからCGImageを取得して完了ハンドラを呼び出します。
            DispatchQueue.main.async { completion(image.cgImage) }
        }
        #elseif canImport(AppKit)
        // macOS (AppKit) の場合: 同様にtakeSnapshotメソッドを使用しますが、NSImageからCGImageへの変換が必要です。
        webView?.takeSnapshot(with: nil) { image, error in
            guard let image = image, error == nil else {
                print("スナップショットの取得に失敗しました: \(error?.localizedDescription ?? "不明なエラー")")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            // NSImageからCGImageを生成して完了ハンドラを呼び出します。
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            DispatchQueue.main.async { completion(cgImage) }
        }
        #endif
    }
}

// MARK: - 共通 WebView Representable

/// `PlatformWebView`とその`Coordinator`で共有されるロジックをカプセル化するためのプロトコル。
/// これにより、`Coordinator`の実装をiOSとmacOSで共通化できます。
protocol PlatformWebViewRepresentable {
    var manager: WebViewManager { get }
    var onURLChanged: (URL?) -> Void { get }
}

/// `PlatformWebView`の`Coordinator`。`WKNavigationDelegate`として機能し、
/// WebViewからのコールバックをSwiftUIビューに伝達します。
/// この実装は、iOSとmacOSで完全に共通です。
class Coordinator: NSObject, WKNavigationDelegate {
    /// 親ビューへの参照。`PlatformWebViewRepresentable`プロトコルを介して抽象化されています。
    var parent: PlatformWebViewRepresentable
    /// `WKWebView`の`canGoBack`プロパティへの変更を監視するためのオブザーバー。
    private var canGoBackObserver: NSKeyValueObservation?
    /// WebViewのURLの変更を監視するためのオブザーバー。
    private var urlObserver: NSKeyValueObservation?

    init(_ parent: PlatformWebViewRepresentable) {
        self.parent = parent
    }

    /// `WKWebView`のプロパティ監視を設定します。
    /// - Parameter webView: 監視対象のWKWebViewインスタンス。
    func setupObservers(for webView: WKWebView) {
        // `canGoBack`プロパティを監視し、変更があれば`WebViewManager`の状態を更新します。
        canGoBackObserver = webView.observe(\.canGoBack, options: .new) { [weak self] webView, _ in
            // UIの更新はメインスレッドで行う必要があります。
            DispatchQueue.main.async {
                self?.parent.manager.canGoBack = webView.canGoBack
            }
        }
        // `url`プロパティを監視し、変更があれば`onURLChanged`コールバックを呼び出します。
        // これにより、「戻る」操作などでURLが変更された際に、UIが正しく更新されます。
        urlObserver = webView.observe(\.url, options: .new) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.parent.onURLChanged(webView.url)
            }
        }
    }

    /// WebViewのページ読み込みが完了したときに呼び出されるデリゲートメソッド。
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // ページ読み込み完了後にも`canGoBack`の状態を更新します。
        parent.manager.canGoBack = webView.canGoBack
    }

    /// `Coordinator`が解放される際に、オブザーバーを無効化してメモリリークを防ぎます。
    deinit {
        canGoBackObserver?.invalidate()
        urlObserver?.invalidate()
    }
}


#if canImport(UIKit)
/// UIKitのWKWebViewをSwiftUIビュー階層に統合するためのラッパービュー。
struct PlatformWebView: UIViewRepresentable, PlatformWebViewRepresentable {
    let url: URL
    @ObservedObject var manager: WebViewManager
    var onURLChanged: (URL?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        context.coordinator.setupObservers(for: webView)
        self.manager.webView = webView
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
}

#elseif canImport(AppKit)
/// AppKitのWKWebViewをSwiftUIビュー階層に統合するためのラッパービュー。
struct PlatformWebView: NSViewRepresentable, PlatformWebViewRepresentable {
    let url: URL
    @ObservedObject var manager: WebViewManager
    var onURLChanged: (URL?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        context.coordinator.setupObservers(for: webView)
        self.manager.webView = webView
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            let request = URLRequest(url: url)
            nsView.load(request)
        }
    }
}
#endif

// MARK: - 翻訳オーバーレイビュー

/// 翻訳されたテキストを、WebView上の元の位置に重ねて表示するためのビュー。
struct TranslationOverlayView: View {
    /// 表示する翻訳データの配列。
    let translationData: [TranslationData]
    /// 親ビュー（WebView）のサイズ。テキストの位置を計算するために使用します。
    let frameSize: CGSize

    var body: some View {
        // ZStackを使用して、要素を重ねて表示します。
        ZStack(alignment: .topLeading) {
            // 各翻訳データに対して、テキストビューを生成します。
            ForEach(translationData.indices, id: \.self) { index in
                let data = translationData[index]
                Text(data.translatedText)
                    .font(.caption) // フォントを小さめに設定
                    .foregroundColor(.white) // 文字色を白に
                    .padding(2)
                    .background(Color.black.opacity(0.7)) // 半透明の黒い背景
                    .cornerRadius(4)
                    // 正規化された座標を、実際のビューのサイズに合わせてピクセル座標に変換し、テキストを配置します。
                    .position(
                        x: data.boundingBox.origin.x * frameSize.width + data.boundingBox.width * frameSize.width / 2,
                        y: data.boundingBox.origin.y * frameSize.height + data.boundingBox.height * frameSize.height / 2
                    )
            }
        }
    }
}

// MARK: - メインビュー

/// アプリケーションのメインとなるビュー。WebView、アドレスバー、翻訳ボタンなどを組み合わせます。
struct CrossPlatformWebView: View {
    // MARK: - 状態変数

    /// URL入力フィールドのテキストを保持する状態変数。
    @State private var urlInput: String
    /// WebViewが実際に読み込むURLを保持する状態変数。
    @State private var address: String
    /// WebViewManagerのインスタンスを生成し、ビューのライフサイクルと関連付けます。
    @StateObject private var webViewManager = WebViewManager()
    /// アプリ設定を管理するオブジェクト。
    @StateObject private var appSettings = AppSettings()
    /// キャプチャしたWebViewの画像を保持する状態変数。
    @State private var capturedImage: CGImage?
    /// 翻訳サービスの処理結果（翻訳済みテキストと位置情報）を保持する状態変数。
    @State private var translationData: [TranslationData] = []
    /// 翻訳オーバーレイが表示されているかどうか（ON/OFF）を管理する状態変数。
    @State private var isTranslationActive = false
    /// 翻訳処理を行うためのTranslationSessionを保持する状態変数。
    @State private var translationSession: TranslationSession?
    /// TranslationSessionを初期化するための設定を保持する状態変数。
    @State private var translationConfig: TranslationSession.Configuration?
    /// メニューpopoverの表示状態を管理する状態変数。
    @State private var isShowingMenuPopover = false

    /// ブックマークデータを管理する`BookmarkManager`のインスタンス。
    /// @StateObjectとして初期化することで、ビューのライフサイクルと連動して管理されます。
    @StateObject private var bookmarkManager = BookmarkManager()

    /// ブックマーク一覧シートの表示状態を管理する状態変数。
    @State private var isShowingBookmarkList = false

    /// 設定シートの表示状態を管理する状態変数。
    @State private var isShowingSettings = false

    // MARK: - 初期化

    init() {
        // AppSettingsから初期URLを読み込み、状態変数を初期化します。
        // AppSettingsのインスタンス化は@StateObjectで行われるため、ここでは直接参照できません。
        // 代わりに、AppSettingsのデフォルト値と同様のロジックを使用します。
        let initialUrl = AppSettings().initialUrl
        _urlInput = State(initialValue: initialUrl)
        _address = State(initialValue: initialUrl)
    }

    // MARK: - Computed Properties

    /// `appSettings`の`floatingButtonPosition`に基づいて、SwiftUIの`Alignment`を返します。
    private var floatingButtonAlignment: Alignment {
        switch appSettings.floatingButtonPosition {
        case .topLeft:
            return .topLeading
        case .topRight:
            return .topTrailing
        case .bottomLeft:
            return .bottomLeading
        case .bottomRight:
            return .bottomTrailing
        }
    }

    // MARK: - ボディ

    var body: some View {
        Group {
            // 翻訳APIが利用可能なOSバージョン（macOS 14+, iOS 17+）であるかを確認します。
            if #available(macOS 14.0, iOS 17.0, *) {
                // contentViewにtranslationTaskモディファイアを追加し、翻訳モデルの準備を非同期で行います。
                contentView
                    .translationTask(translationConfig) { session in
                        // このクロージャは、翻訳の準備が完了したか、失敗したときに呼び出されます。
                        self.translationSession = nil // 既存のセッションをクリア
                        do {
                            // 翻訳モデルをデバイスにダウンロードまたは準備します。
                            try await session.prepareTranslation()
                            self.translationSession = session // 準備済みのセッションを保持
                            print("翻訳モデルの準備が完了しました。")
                        } catch {
                            print("翻訳モデルの準備に失敗しました: \(error.localizedDescription)")
                            // 失敗した場合は設定をクリアし、再試行の可能性を残します。
                            self.translationConfig = nil
                        }
                    }
            } else {
                // 古いOSバージョンの場合は、翻訳機能なしでcontentViewを表示します。
                contentView
            }
        }
    }

    /// 実際のビューコンテンツを定義するプライベートな算出プロパティ。
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            // MARK: WebView 本体
            ZStack {
                GeometryReader { geometry in
                    ZStack {
                        // プラットフォームに応じたWebViewを表示します。
                        // URLが不正な場合に備えて、デフォルトのURL（about:blank）を用意します。
                        PlatformWebView(url: URL(string: address) ?? URL(string: "about:blank")!, manager: webViewManager) { newURL in
                            // WebView内でのページ遷移が完了したときに呼び出されます。
                            // 遷移後のURLを取得し、UIの状態を更新します。
                            if let url = newURL, url.absoluteString != self.address {
                                // UIの更新はメインスレッドで行うことが推奨されます。
                                DispatchQueue.main.async {
                                    // urlInputを更新してTextFieldの表示を同期させます。
                                    self.urlInput = url.absoluteString
                                    // addressも更新して、ブックマーク追加などの機能が
                                    // 正しいURLを参照するようにします。
                                    self.address = url.absoluteString
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // 翻訳がアクティブな場合、オーバーレイビューを表示します。
                        if isTranslationActive {
                            TranslationOverlayView(translationData: translationData, frameSize: geometry.size)
                        }
                    }
                }
                .overlay(alignment: floatingButtonAlignment) {
                    // フローティング翻訳ボタン
                    FloatingTranslationButton(
                        imageName: isTranslationActive ? "xmark.circle.fill" : "bubble.left.and.bubble.right.fill",
                        isDisabled: translationSession == nil
                    ) {
                        // 翻訳状態をトグル（反転）させる
                        self.isTranslationActive.toggle()

                        // もし翻訳がONになったら、翻訳処理を実行
                        if self.isTranslationActive {
                            // 既存の翻訳データをクリア
                            self.translationData = []
                            // 翻訳セッションが準備できているか確認
                            guard let session = self.translationSession else {
                                print("翻訳セッションの準備ができていません。")
                                // 失敗した場合は状態を戻す
                                self.isTranslationActive = false
                                return
                            }

                            // WebViewのスクリーンショットを撮り、翻訳処理を開始します。
                            webViewManager.captureWebView { image in
                                self.capturedImage = image
                                guard let capturedImage = image else {
                                    // 失敗した場合は状態を戻す
                                    self.isTranslationActive = false
                                    return
                                }

                                // 1. 画像からテキストを認識
                                TranslationService.recognizeText(from: capturedImage) { detectedTexts in
                                    if #available(macOS 14.0, iOS 17.0, *) {
                                        // 2. 認識したテキストを翻訳
                                        TranslationService.translate(detectedTexts: detectedTexts, with: session) { translatedData in
                                            // 3. 翻訳結果を状態変数に保存し、UIを更新
                                            self.translationData = translatedData
                                            print("\(translatedData.count)個のテキストブロックを翻訳しました。")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(10) // 画面の端からの余白
                }
            }

            Divider()

            // MARK: 下部ツールバー
            HStack {
                // 戻るボタン
                Button(action: {
                    // WebViewManagerを介して、WebViewの履歴を一つ戻ります。
                    webViewManager.goBack()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.black)
                }
                // webViewManagerのcanGoBackプロパティがfalseの場合、ボタンを無効化します。
                .disabled(!webViewManager.canGoBack)

                // URL入力用のテキストフィールド
                TextField("URLを入力", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        // Returnキーが押されたら、入力されたテキストでaddressを更新します。
                        address = urlInput
                    }

                // メニューボタン
                Button(action: {
                    isShowingMenuPopover = true
                }) {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .foregroundColor(.black)
                }
                .popover(isPresented: $isShowingMenuPopover) {
                    // MenuGridViewに各アクションクロージャを渡します。
                    MenuGridView(
                        onShowBookmarks: {
                            isShowingMenuPopover = false
                            isShowingBookmarkList = true
                        },
                        onAddBookmark: {
                            isShowingMenuPopover = false
                            if let url = URL(string: address) {
                                // 現在のページのタイトルを取得し、ブックマークに追加します。
                                // evaluateJavaScriptの完了ハンドラはメインスレッドで実行されるとは限らないため、
                                // UIに影響を与える処理は明示的にメインスレッドで実行します。
                                webViewManager.webView?.evaluateJavaScript("document.title") { (title, error) in
                                    DispatchQueue.main.async {
                                        let pageTitle = (title as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "名称未設定"
                                        bookmarkManager.addBookmark(title: pageTitle, url: url)
                                    }
                                }
                            }
                        },
                        onReload: {
                            isShowingMenuPopover = false
                            webViewManager.reload()
                        },
                        onShowSettings: {
                            isShowingMenuPopover = false
                            isShowingSettings = true
                        }
                    )
                }
            }
            .padding(8)
            .background(Color(white: 0.95))
            // OSに応じて表示するビューを切り替えます。
            #if os(macOS)
            // macOS専用のブックマーク一覧をシートとして表示
            .sheet(isPresented: $isShowingBookmarkList) {
                BookmarkListView_macOS(bookmarkManager: bookmarkManager, onBookmarkSelected: { bookmark in
                    let urlString = bookmark.url.absoluteString
                    // 状態変数を更新してUIに反映
                    address = urlString
                    urlInput = urlString
                    // WebViewに直接ロード命令を送り、表示を確実に更新させます。
                    webViewManager.webView?.load(URLRequest(url: bookmark.url))
                    // シートを閉じます。
                    isShowingBookmarkList = false
                })
            }
            // macOS専用の設定画面をシートとして表示
            .sheet(isPresented: $isShowingSettings) {
                SettingsView_macOS(appSettings: appSettings)
            }
            #else
            // iOS用のブックマーク一覧をシートとして表示
            .sheet(isPresented: $isShowingBookmarkList) {
                BookmarkListView(bookmarkManager: bookmarkManager, onBookmarkSelected: { bookmark in
                    let urlString = bookmark.url.absoluteString
                    address = urlString
                    urlInput = urlString
                    isShowingBookmarkList = false
                })
            }
            // iOS用の設定画面をシートとして表示
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(appSettings: appSettings)
            }
            #endif
        }
        .modifier(AdaptiveFrame()) // macOS用にウィンドウサイズの最小値を設定
        .onAppear {
            // ビューが表示されるたびに、設定された初期URLを読み込みます。
            // これにより、設定画面でURLを変更した場合に、その変更が反映されます。
            loadInitialUrl()

            // ビューが表示されたときに、翻訳の準備を開始します。
            if #available(macOS 14.0, iOS 17.0, *) {
                // AppSettingsからターゲット言語を読み込み、翻訳セッションを設定します。
                self.translationConfig = .init(source: .init(identifier: "ja"), target: .init(identifier: appSettings.targetLanguage))
            }
        }
        .onChange(of: appSettings.targetLanguage) { oldState, newLanguage in
            // ターゲット言語が変更されたら、翻訳セッションの設定を更新します。
            // これにより、新しい言語モデルのダウンロード/準備がトリガーされます。
            if #available(macOS 14.0, iOS 17.0, *) {
                self.translationConfig = .init(source: .init(identifier: "ja"), target: .init(identifier: newLanguage))
                print("ターゲット言語が\(newLanguage)に変更されたため、翻訳設定を更新しました。")
            }
        }
    }

    // MARK: - ヘルパーメソッド

    /// AppSettingsから初期URLを読み込み、URL入力フィールドのテキストを更新します。
    private func loadInitialUrl() {
        // addressは変更せず、urlInputのみを更新することで、ユーザーのブラウジングセッションを中断させません。
        urlInput = appSettings.initialUrl
    }
}

// MARK: - Adaptive Frame Modifier

/// macOSアプリケーションとして実行される場合に、ウィンドウの最小サイズを設定するためのViewModifier。
struct AdaptiveFrame: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        // macOSの場合、最小幅600, 最小高さ400のフレームを適用します。
        content.frame(minWidth: 600, minHeight: 400)
        #else
        // iOSの場合は、何も変更せずにコンテンツを返します。
        content
        #endif
    }
}

// MARK: - プレビュー

/// Xcodeのプレビュー機能でこのビューを表示するためのコード。
#Preview {
    CrossPlatformWebView()
}
