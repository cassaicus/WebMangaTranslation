//
//  BookmarkListView_macOS.swift
//  MangaWebTranslation6
//
//  Created by Jules on 2025/11/17.
//
//  macOS専用のブックマーク一覧画面を定義します。
//

import SwiftUI

struct BookmarkListView_macOS: View {

    // MARK: - プロパティ

    @ObservedObject var bookmarkManager: BookmarkManager
    let onBookmarkSelected: (Bookmark) -> Void
    @Environment(\.dismiss) private var dismiss

    // MARK: - ボディ

    var body: some View {
        VStack(spacing: 0) {
            Text("ブックマーク")
                .font(.headline)
                .padding()

            Divider()

            if bookmarkManager.bookmarks.isEmpty {
                Spacer()
                Text("ブックマークはありません")
                    .foregroundColor(.gray)
                Spacer()
            } else {
                List {
                    ForEach(bookmarkManager.bookmarks) { bookmark in
                        HStack {
                            // ブックマーク情報を表示するボタン
                            Button(action: {
                                onBookmarkSelected(bookmark)
                            }) {
                                VStack(alignment: .leading) {
                                    Text(bookmark.title)
                                        .font(.headline)
                                    Text(bookmark.url.absoluteString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle()) // ボタンのデフォルトスタイルを無効化

                            Spacer()

                            // 削除ボタン
                            Button(action: {
                                bookmarkManager.deleteBookmark(withId: bookmark.id)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("完了") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .padding()
            }
        }
        .frame(width: 400, height: 500) // macOSに適したウィンドウサイズ
    }
}

// MARK: - プレビュー
struct BookmarkListView_macOS_Previews: PreviewProvider {
    static var previews: some View {
        BookmarkListView_macOS(bookmarkManager: {
            let manager = BookmarkManager()
            manager.addBookmark(title: "Google", url: URL(string: "https://www.google.com")!)
            manager.addBookmark(title: "Apple", url: URL(string: "https://www.apple.com")!)
            return manager
        }(), onBookmarkSelected: { _ in })
    }
}
