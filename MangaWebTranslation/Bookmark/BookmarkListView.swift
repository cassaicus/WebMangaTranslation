//
//  BookmarkListView.swift
//  MangaWebTranslation6
//
//  Created by Jules on 2025/11/17.
//
//  保存されたブックマークの一覧を表示し、管理するためのビューを定義します。
//

import SwiftUI

/// ブックマークの一覧を表示するビュー。
struct BookmarkListView: View {

    // MARK: - プロパティ

    /// ブックマークデータを管理する`BookmarkManager`のインスタンス。
    @ObservedObject var bookmarkManager: BookmarkManager

    /// ブックマークが選択されたときに呼び出されるコールバック。
    /// 選択された`Bookmark`を引数として受け取ります。
    let onBookmarkSelected: (Bookmark) -> Void

    /// このビュー（シート）を閉じるための環境変数。
    @Environment(\.dismiss) private var dismiss

    // MARK: - ボディ

    var body: some View {
        // NavigationViewを追加して、タイトルバーと閉じるボタンを表示できるようにします。
        NavigationView {
            // ブックマークが空の場合とそうでない場合で表示を切り替えます。
            Group {
                if bookmarkManager.bookmarks.isEmpty {
                    // ブックマークが一つもない場合に表示するビュー。
                    Text("ブックマークはありません")
                        .font(.headline)
                        .foregroundColor(.gray)
                } else {
                    // ブックマークが存在する場合にリストを表示します。
                    List {
                        // `ForEach`を使用して`bookmarks`配列の各要素をリストの行として表示します。
                        ForEach(bookmarkManager.bookmarks) { bookmark in
                            Button(action: {
                                // このブックマークを選択したことをコールバックで通知します。
                                onBookmarkSelected(bookmark)
                            }) {
                                VStack(alignment: .leading) {
                                    // ブックマークのタイトル
                                    Text(bookmark.title)
                                        .font(.headline)
                                    // ブックマークのURL
                                    Text(bookmark.url.absoluteString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .foregroundColor(.primary) // ボタン内のテキストの色を通常に戻します
                            }
                        }
                        // リストの行をスワイプして削除する機能を追加します。
                        .onDelete(perform: bookmarkManager.deleteBookmark)
                    }
                }
            }
            .navigationTitle("ブックマーク") // ナビゲーションバーのタイトル
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline) // タイトルの表示モード
            #endif
            .toolbar {
                // 「完了」ボタンを配置します。
                ToolbarItem(placement: .primaryAction) {
                    Button("完了") {
                        dismiss() // ボタンをタップするとシートを閉じます。
                    }
                }
            }
        }
    }
}

// MARK: - プレビュー

/// Xcodeのプレビュー機能でこのビューを表示するためのコード。
struct BookmarkListView_Previews: PreviewProvider {
    static var previews: some View {
        // BookmarkListViewにダミーデータを渡してプレビューします。
        BookmarkListView(bookmarkManager: {
            let manager = BookmarkManager()
            manager.addBookmark(title: "Google", url: URL(string: "https://www.google.com")!)
            manager.addBookmark(title: "Apple", url: URL(string: "https://www.apple.com")!)
            return manager
        }(), onBookmarkSelected: { bookmark in
            print("Selected bookmark: \(bookmark.title)")
        })
    }
}
