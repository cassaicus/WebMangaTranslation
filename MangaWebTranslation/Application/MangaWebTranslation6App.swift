//2025/11/12.
//
//  このファイルは、アプリケーションのエントリーポイント（開始点）を定義します。
//  アプリが起動する際に最初に実行され、ウィンドウのセットアップや
//  初期ビューの表示を行います。
//

import SwiftUI

// @main属性は、MangaWebTranslation6Appがアプリケーションの
// エントリーポイントであることを示します。
@main
struct MangaWebTranslation6App: App {

    // bodyプロパティは、アプリのシーン（画面）を定義します。
    // ここでウィンドウのコンテンツと構造が決定されます。
    var body: some Scene {

        // WindowGroupは、アプリケーションのメインウィンドウを管理するシーンです。
        // iOS, iPadOS, macOSなどのプラットフォームで、標準的なウィンドウの挙動を提供します。
        WindowGroup {

            // CrossPlatformWebView()を初期ビューとして設定します。
            // アプリが起動すると、このビューが最初に表示されます。
            CrossPlatformWebView()
        }
    }
}
