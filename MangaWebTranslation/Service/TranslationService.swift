//
//  TranslationService.swift
//  MangaWebTranslation6
//
//  Created by ibis on 2025/11/12.
//
//  このファイルは、画像からのテキスト認識と翻訳を行うためのサービスを定義します。
//  AppleのVisionフレームワークを使用して画像内のテキストを検出し、
//  Translationフレームワークを使用して検出されたテキストを翻訳します。
//

import Foundation
import Vision
import CoreGraphics
import Translation

// MARK: - データ構造

/// Visionフレームワークによって画像から認識されたテキストとその位置情報を保持する構造体。
struct DetectedText {
    /// 認識されたテキスト文字列。
    let text: String
    /// テキストが画像内で占める領域（バウンディングボックス）。座標系はVisionフレームワークの正規化された座標（左下が原点）です。
    let boundingBox: CGRect
}

/// 翻訳後のテキストとその元の位置情報を保持する構造体。
/// このデータは、翻訳結果をオーバーレイ表示する際に使用されます。
struct TranslationData {
    /// 翻訳されたテキスト文字列。
    let translatedText: String
    /// 元のテキストが画像内で占める領域（バウンディングボックス）。
    let boundingBox: CGRect
}

// MARK: - 翻訳サービスクラス

/// テキスト認識と翻訳に関連する静的メソッドを提供するクラス。
class TranslationService {

    // MARK: - テキスト認識

    /// 指定されたCGImageから日本語のテキストを認識します。
    ///
    /// - Parameters:
    ///   - image: テキスト認識の対象となるCGImage。
    ///   - completion: 認識処理が完了したときに呼び出されるクロージャ。認識された`DetectedText`の配列を引数として受け取ります。
    static func recognizeText(from image: CGImage, completion: @escaping ([DetectedText]) -> Void) {

        // Visionフレームワークにテキスト認識を要求するためのリクエストを作成します。
        // 完了ハンドラで、認識結果またはエラーを処理します。
        let request = VNRecognizeTextRequest { (request, error) in
            // 結果をVNRecognizedTextObservationの配列として取得します。エラーがある場合は、コンソールに出力して空の配列を返します。
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                print("テキスト認識に失敗しました: \(error?.localizedDescription ?? "不明なエラー")")
                completion([])
                return
            }

            // 認識された各テキスト（observation）を、自前のDetectedText構造体に変換します。
            let detectedTexts = observations.compactMap { observation -> DetectedText? in
                // 認識結果の中から、最も確信度の高い候補を1つ取得します。
                guard let topCandidate = observation.topCandidates(1).first else { return nil }

                // Visionの座標系（左下が原点）から、ビューで扱いやすい座標系（左上が原点）に変換します。
                // Y軸を反転させる変換を行っています。
                let bounds = observation.boundingBox
                let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
                let convertedRect = bounds.applying(transform)

                // 変換後の座標とテキスト文字列でDetectedTextインスタンスを生成します。
                return DetectedText(text: topCandidate.string, boundingBox: convertedRect)
            }

            // 変換したDetectedTextの配列を完了ハンドラに渡します。
            completion(detectedTexts)
        }

        // 認識する言語を日本語に指定します。
        request.recognitionLanguages = ["ja-JP"]

        // 指定された画像でリクエストを実行するためのハンドラを作成します。
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        // テキスト認識は重い処理の可能性があるため、バックグラウンドスレッドで非同期に実行します。
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // テキスト認識処理を実行します。
                try handler.perform([request])
            } catch {
                print("テキスト認識の実行に失敗しました: \(error.localizedDescription)")
                completion([])
            }
        }
    }

    // MARK: - テキスト翻訳

    /// 検出されたテキストの配列を、指定されたTranslationSessionを使用して翻訳します。
    /// このメソッドは、macOS 14.0以降、iOS 17.0以降で利用可能です。
    ///
    /// - Parameters:
    ///   - detectedTexts: 翻訳対象の`DetectedText`の配列。
    ///   - session: 翻訳に使用する`TranslationSession`インスタンス。
    ///   - completion: 翻訳処理が完了したときに呼び出されるクロージャ。翻訳された`TranslationData`の配列を引数として受け取ります。
    @available(macOS 14.0, iOS 17.0, *)
    static func translate(detectedTexts: [DetectedText], with session: TranslationSession, completion: @escaping ([TranslationData]) -> Void) {
        // 翻訳対象のテキストがない場合は、何もせずに処理を終了します。
        guard !detectedTexts.isEmpty else {
            completion([])
            return
        }

        // Swiftの構造化された並行処理（Structured Concurrency）を使用して、複数のテキストを並行して翻訳します。
        Task {
            // withThrowingTaskGroupを使用して、複数の非同期タスクをグループ化します。
            // 各タスクはテキストの翻訳を行い、TranslationData?を返します。
            let translationData = try await withThrowingTaskGroup(of: TranslationData?.self) { group in
                var results = [TranslationData]()
                results.reserveCapacity(detectedTexts.count) // パフォーマンスのため、配列の容量をあらかじめ確保します。

                // 検出された各テキストに対して、翻訳タスクをグループに追加します。
                for detectedText in detectedTexts {
                    group.addTask {
                        do {
                            // TranslationSessionを使用してテキストを翻訳します。
                            let response = try await session.translate(detectedText.text)
                            // 翻訳結果と元のバウンディングボックスからTranslationDataを作成して返します。
                            return TranslationData(translatedText: response.targetText, boundingBox: detectedText.boundingBox)
                        } catch {
                            print("テキストの翻訳に失敗しました '\(detectedText.text)': \(error)")
                            // エラーが発生した場合はnilを返します。
                            return nil
                        }
                    }
                }

                // グループ内のすべてのタスクが完了するのを待ち、結果を収集します。
                for try await result in group {
                    if let result = result {
                        results.append(result)
                    }
                }
                return results
            }

            // すべての翻訳処理が終わったら、UIの更新をメインスレッドで行うため、
            // 結果をメインスレッドの完了ハンドラに渡します。
            DispatchQueue.main.async {
                completion(translationData)
            }
        }
    }
}
