//
//  BookmarkManager.swift
//  MangaWebTranslation6
//
//  Created by Jules on 2025/11/17.
//
//  ブックマークのデータモデルと、UserDefaultsを使った永続化を管理するクラスを定義します。
//

internal import Combine
import Foundation
import SwiftUI

/// ブックマークのデータを表現する構造体。
/// Codable: JSONへのエンコード・デコードを可能にします。
/// Identifiable: SwiftUIのListで各要素を一意に識別するために使用します。
struct Bookmark: Codable, Identifiable {
    /// 各ブックマークの一意なID。
    var id = UUID()
    /// ブックマークのタイトル（例: Webサイトのタイトル）。
    let title: String
    /// ブックマークのURL。
    let url: URL
}

/// ブックマークの追加、取得、削除を管理するクラス。
class BookmarkManager: ObservableObject {

    // MARK: - プロパティ

    /// 保存されたブックマークの配列。
    /// @Publishedプロパティラッパーにより、この配列への変更がSwiftUIビューに自動的に通知されます。
    @Published private(set) var bookmarks: [Bookmark] = []

    /// UserDefaultsにブックマークを保存するためのキー。
    private let bookmarksKey = "savedBookmarks"

    // MARK: - 初期化

    init() {
        // クラスのインスタンスが生成されたときに、UserDefaultsからブックマークを読み込みます。
        loadBookmarks()
    }

    // MARK: - ブックマーク操作メソッド

    /// 新しいブックマークを追加します。
    /// - Parameters:
    ///   - title: ブックマークのタイトル。
    ///   - url: ブックマークのURL。
    func addBookmark(title: String, url: URL) {
        // 新しいBookmarkインスタンスを作成します。
        let newBookmark = Bookmark(title: title, url: url)
        // bookmarks配列の先頭に追加します。
        bookmarks.insert(newBookmark, at: 0)
        // 変更をUserDefaultsに保存します。
        saveBookmarks()
    }

    /// 指定されたIDを持つブックマークを削除します。
    /// macOSの削除ボタンなど、直接ブックマークを指定して削除する場合に使用します。
    /// - Parameter id: 削除するブックマークのID。
    func deleteBookmark(withId id: UUID) {
        // 配列から指定されたIDと一致しない要素のみを残します。
        bookmarks.removeAll { $0.id == id }
        // 変更をUserDefaultsに保存します。
        saveBookmarks()
    }

    /// 指定されたインデックスセットのブックマークを削除します。
    /// SwiftUIの `onDelete` モディファイアと連携して動作します。
    /// - Parameter offsets: 削除するブックマークのインデックスのセット。
    func deleteBookmark(at offsets: IndexSet) {
        // 指定されたインデックスの要素を削除します。
        bookmarks.remove(atOffsets: offsets)
        // 変更をUserDefaultsに保存します。
        saveBookmarks()
    }

    // MARK: - データ永続化

    /// `bookmarks` 配列をUserDefaultsにJSONデータとして保存します。
    private func saveBookmarks() {
        do {
            // `bookmarks` 配列をJSONデータにエンコードします。
            let data = try JSONEncoder().encode(bookmarks)
            // UserDefaultsに保存します。
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        } catch {
            // エンコードに失敗した場合はエラーメッセージを出力します。
            print("ブックマークの保存に失敗しました: \(error.localizedDescription)")
        }
    }

    /// UserDefaultsからブックマークのJSONデータを読み込み、`bookmarks` 配列を更新します。
    private func loadBookmarks() {
        // UserDefaultsからデータを取得します。
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey) else { return }

        do {
            // 取得したJSONデータを `[Bookmark]` 型にデコードします。
            bookmarks = try JSONDecoder().decode([Bookmark].self, from: data)
        } catch {
            // デコードに失敗した場合はエラーメッセージを出力します。
            print("ブックマークの読み込みに失敗しました: \(error.localizedDescription)")
        }
    }
}
