//
//  MenuGridView.swift
//  MangaWebTranslation6
//
//  Created by Jules on 2025/11/17.
//
//  Popover内に表示される2x2のタイル状メニューを定義します。
//  ブックマーク、再読み込み、設定などのアクションボタンをグリッドレイアウトで表示します。
//

import SwiftUI

/// 2x2のグリッドレイアウトでメニュー項目を表示するビュー。
struct MenuGridView: View {

    // MARK: - アクションクロージャ

    /// 各ボタンがタップされたときに実行されるアクション。
    let onShowBookmarks: () -> Void
    let onAddBookmark: () -> Void
    let onReload: () -> Void
    let onShowSettings: () -> Void

    // MARK: - メニュー項目の定義

    /// メニューボタンの情報を表す構造体。
    private struct MenuItem: Identifiable {
        let id = UUID()
        let title: String
        let systemImage: String
    }

    /// 2x2グリッドに表示するメニュー項目のデータ。
    private let menuItems: [MenuItem] = [
        .init(title: "Bookmarks", systemImage: "book"),
        .init(title: "Add Bookmark", systemImage: "bookmark.fill"),
        .init(title: "Reload", systemImage: "arrow.clockwise"),
        .init(title: "Settings", systemImage: "gear")
    ]

    // MARK: - グリッドレイアウトの定義

    /// グリッドの列定義。固定幅80ポイントの列を2つ作成します。
    private let columns: [GridItem] = [
        GridItem(.fixed(80), spacing: 16),
        GridItem(.fixed(80), spacing: 16)
    ]

    // MARK: - ボディ

    var body: some View {
        VStack {
            // LazyVGridを使用して2x2のグリッドを生成します。
            LazyVGrid(columns: columns, spacing: 16) {
                // menuItems配列の各要素に対してボタンを生成します。
                // ForEachの代わりにインデックスを使って各ボタンに個別のアクションを割り当てます。

                // ブックマーク一覧ボタン
                createMenuButton(for: menuItems[0], action: onShowBookmarks)

                // ブックマーク追加ボタン
                createMenuButton(for: menuItems[1], action: onAddBookmark)

                // 再読み込みボタン
                createMenuButton(for: menuItems[2], action: onReload)

                // 設定ボタン
                createMenuButton(for: menuItems[3], action: onShowSettings)
            }
        }
        .padding() // 全体に余白を追加
        // iPadOSでPopoverが全画面表示になるのを防ぎ、コンテンツに合わせたサイズで表示します。
        .presentationCompactAdaptation(.none)
    }

    /// 指定されたメニュー項目のためのボタンビューを生成します。
    /// - Parameters:
    ///   - item: 表示するメニュー項目のデータ。
    ///   - action: ボタンがタップされたときに実行されるクロージャ。
    /// - Returns: 設定済みのButtonビュー。
    @ViewBuilder
    private func createMenuButton(for item: MenuItem, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: item.systemImage)
                    .font(.title2) // アイコンサイズ
                Text(item.title)
                    .font(.caption) // ラベルフォント
            }
            .frame(width: 80, height: 80) // ボタンのサイズを正方形に
            //.background(Color(UIColor.secondarySystemBackground)) // 背景色
            .cornerRadius(12) // 角丸
        }
        .foregroundColor(.primary) // ボタン内のテキストとアイコンの色
    }
}

// MARK: - プレビュー

/// Xcodeのプレビュー機能でこのビューを表示するためのコード。
struct MenuGridView_Previews: PreviewProvider {
    static var previews: some View {
        MenuGridView(
            onShowBookmarks: { print("Show Bookmarks") },
            onAddBookmark: { print("Add Bookmark") },
            onReload: { print("Reload") },
            onShowSettings: { print("Show Settings") }
        )
        .previewLayout(.sizeThatFits)
    }
}
