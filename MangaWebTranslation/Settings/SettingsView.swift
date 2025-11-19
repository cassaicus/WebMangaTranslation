//2025/11/17.
//
//  設定画面のビューを定義します。
//  初期表示URLの編集・保存ができます。
//

import SwiftUI

/// 設定画面を表すビュー。
struct SettingsView: View {

    // MARK: - プロパティ

    /// このビュー（シート）を閉じるための環境変数。
    @Environment(\.dismiss) private var dismiss

    /// アプリ設定を管理するオブジェクト。（親ビューから渡される）
    @ObservedObject var appSettings: AppSettings

    // MARK: - ボディ

    var body: some View {
        NavigationView {
            // Formを使用して設定項目をグループ化します。
            Form {
                // MARK: 翻訳設定
                Section(header: Text("翻訳設定")) {
                    Picker("翻訳先の言語", selection: $appSettings.targetLanguage) {
                        ForEach(commonLanguages) { language in
                            Text(language.name).tag(language.id)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("翻訳元の言語は常に日本語です。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                // MARK: 一般設定
                Section(header: Text("一般設定")) {
                    HStack {
                        Text("初期URL:")
                        // URLを入力するためのテキストフィールド。
                        TextField("https://...", text: $appSettings.initialUrl)
                            #if os(iOS)
                            .keyboardType(.URL) // URL入力に適したキーボードを表示
                            .autocapitalization(.none) // 自動大文字化を無効
                            #endif
                    }

                    Picker("翻訳ボタンの位置", selection: $appSettings.floatingButtonPosition) {
                        ForEach(FloatingButtonPosition.allCases) { position in
                            Text(position.displayName).tag(position)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("設定") // ナビゲーションバーのタイトル
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline) // タイトルの表示モード
            #endif
            .toolbar {
                // キャンセルボタン（macOS互換）
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss() // シートを閉じます。
                    }
                }
                // 完了ボタン（macOS互換）
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        // @StateObjectの変更は自動的に保存されるため、
                        // このボタンはシートを閉じる機能のみ持ちます。
                        dismiss() // シートを閉じます。
                    }
                }
            }
        }
    }
}

// MARK: - プレビュー

/// Xcodeのプレビュー機能でこのビューを表示するためのコード。
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(appSettings: AppSettings())
    }
}
