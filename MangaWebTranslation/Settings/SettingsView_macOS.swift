//2025/11/17.
//
//  macOS専用の設定画面を定義します。
//

import SwiftUI

#if os(macOS)
struct SettingsView_macOS: View {

    // MARK: - プロパティ

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appSettings: AppSettings

    // MARK: - ボディ

    var body: some View {
        VStack(spacing: 0) {
            Text("設定")
                .font(.headline)
                .padding()

            Divider()

            // 設定項目
            VStack {
                // 翻訳設定
                GroupBox(label: Text("翻訳設定").font(.title3)) {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("翻訳先の言語:", selection: $appSettings.targetLanguage) {
                            ForEach(commonLanguages) { language in
                                Text(language.name).tag(language.id)
                            }
                        }
                        .pickerStyle(.menu)

                        Text("翻訳元の言語は常に日本語です。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // 一般設定
                GroupBox(label: Text("一般設定").font(.title3)) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("初期URL:")
                            TextField("https://...", text: $appSettings.initialUrl)
                        }

                        Picker("翻訳ボタンの位置:", selection: $appSettings.floatingButtonPosition) {
                            ForEach(FloatingButtonPosition.allCases) { position in
                                Text(position.displayName).tag(position)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding()
                }
            }
            .padding()

            Spacer()

            Divider()

            // ボタン領域
            HStack {
                Button("キャンセル") {
                    dismiss()
                }
                Spacer()
                Button("完了") {
                    // @StateObjectの変更は自動的に保存される
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 480, height: 420) // macOSに適したウィンドウサイズ
    }
}

// MARK: - プレビュー
struct SettingsView_macOS_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView_macOS(appSettings: AppSettings())
    }
}
#endif
