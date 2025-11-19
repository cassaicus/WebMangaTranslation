//2025/11/15.
//
//  翻訳機能をトリガーするためのフローティングアクションボタン（FAB）を定義します。
//  このボタンは画面上に浮遊し、ユーザーがいつでも翻訳を実行できるようにします。
//

import SwiftUI

/// 翻訳実行用のフローティングアクションボタンビュー。
struct FloatingTranslationButton: View {

    // MARK: - プロパティ

    /// ボタンに表示するSF Symbolのアイコン名。
    let imageName: String

    /// このボタンが無効状態かどうかを示す値。
    let isDisabled: Bool

    /// ボタンがタップされたときに実行されるアクションクロージャ。
    let action: () -> Void

    // MARK: - ボディ

    var body: some View {
        Button(action: action) {
            Image(systemName: imageName)
                .font(.title2) // アイコンのサイズを調整
                .foregroundColor(.white) // アイコンの色を白に
                .padding() // 内側の余白
                .background(Color.blue) // 背景色を青に
                .clipShape(Circle()) // 円形に切り抜き
                .shadow(radius: 10) // 影をつけて立体感を出す
        }
        .disabled(isDisabled) // disabled状態を反映
        .opacity(isDisabled ? 0.6 : 1.0) // 無効状態のときは少し透明にする
    }
}

// MARK: - プレビュー

/// Xcodeのプレビュー機能でこのビューを表示するためのコード。
struct FloatingTranslationButton_Previews: PreviewProvider {
    static var previews: some View {
        // 翻訳実行（ON）状態のアイコン
        FloatingTranslationButton(
            imageName: "bubble.left.and.bubble.right.fill",
            isDisabled: false,
            action: { print("Translate!") }
        )
        .padding()
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Translate (ON)")

        // 翻訳非表示（OFF）状態のアイコン
        FloatingTranslationButton(
            imageName: "xmark.circle.fill",
            isDisabled: false,
            action: { print("Dismiss!") }
        )
        .padding()
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Dismiss (OFF)")

        // 無効状態のボタン
        FloatingTranslationButton(
            imageName: "bubble.left.and.bubble.right.fill",
            isDisabled: true,
            action: { print("Disabled") }
        )
        .padding()
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Disabled State")
    }
}
