//
//  MangaOCRService.swift
//  MangaWebTranslation6
//
//  Created by ibis on 2025/11/19.
//

import Foundation
import Vision
import CoreGraphics
import Translation

#if canImport(UIKit)
internal import UIKit
#elseif canImport(AppKit)
internal import AppKit
#endif

/// MANGA OCRのパイプライン（吹き出し検出、OCR、翻訳）を管理するクラス。
class MangaOCRService {

    /// セリフ検出を実行するMLエンジン。
    private var detectionEngine: DetectionEngine?

    /// OCR（光学的文字認識）を実行するMLエンジン。
    private var ocrEngine: OCREngine?

    /// イニシャライザ。各種MLエンジンを初期化する。
    init(appSettings: AppSettings) {
        do {
            let computeUnits = appSettings.computeUnit.mlComputeUnits
            self.detectionEngine = try DetectionEngine(computeUnit: computeUnits)
            self.ocrEngine = try OCREngine(computeUnit: computeUnits)
        } catch {
            print("Failed to initialize MangaOCRService engines: \(error)")
            self.detectionEngine = nil
            self.ocrEngine = nil
        }
    }

    /// 指定されたCGImageから漫画のセリフを認識し、翻訳します。
    /// - Parameters:
    ///   - image: 翻訳対象のCGImage。
    ///   - session: 翻訳に使用するTranslationSession。
    /// - Returns: 翻訳されたテキストと位置情報を含む`TranslationData`の配列。
    @available(macOS 14.0, iOS 17.0, *)
    func recognizeAndTranslate(from image: CGImage, with session: TranslationSession) async -> [TranslationData] {
        // エンジンが初期化されているか、画像が有効かを確認
        guard let detectionEngine = detectionEngine, let ocrEngine = ocrEngine else {
            print("MangaOCRService engines not initialized.")
            return []
        }

        // CGImageをプラットフォーム固有の画像形式に変換
        #if canImport(UIKit)
        let platformImage = PlatformImage(cgImage: image)
        #elseif canImport(AppKit)
        let platformImage = PlatformImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        #endif

        print("[MangaOCRService] 開始")
        do {
            // 1. 吹き出しを検出
            print("[MangaOCRService] 吹き出し検出を開始...")
            let boundingBoxes = try detectionEngine.detectSpeechBubbles(on: platformImage)
            print("[MangaOCRService] 検出された吹き出しの数: \(boundingBoxes.count)")
            guard !boundingBoxes.isEmpty else {
                print("[MangaOCRService] 吹き出しが見つからなかったので終了します。")
                return []
            }

            // 2. 検出された各吹き出しに対してOCRと翻訳を並行して実行
            let translationData = try await withThrowingTaskGroup(of: TranslationData?.self) { group in
                var results = [TranslationData]()
                results.reserveCapacity(boundingBoxes.count)

                for (index, box) in boundingBoxes.enumerated() {
                    // CGImageを切り抜く
                    guard let croppedImage = image.cropping(to: box) else {
                        print("[MangaOCRService] 吹き出し[\(index)]の切り抜きに失敗しました。")
                        continue
                    }

                    // デバッグ用に切り抜いた画像を保存する
                    // self.saveDebugImage(croppedImage, index: index)

                    group.addTask {
                        do {
                            // 3. 切り抜いた画像からテキストを認識
                            print("[MangaOCRService] 吹き出し[\(index)]のOCRを開始...")
                            let recognizedText = try ocrEngine.recognizeText(from: croppedImage, normalization: .scaleTo_minus1_1)
                            print("[MangaOCRService] 吹き出し[\(index)]のOCR結果: '\(recognizedText)'")
                            guard !recognizedText.isEmpty else {
                                print("[MangaOCRService] 吹き出し[\(index)]でテキストが認識されませんでした。")
                                return nil
                            }

                            // 4. 認識したテキストを翻訳
                            print("[MangaOCRService] 吹き出し[\(index)]の翻訳を開始...")
                            let response = try await session.translate(recognizedText)
                            print("[MangaOCRService] 吹き出し[\(index)]の翻訳結果: '\(response.targetText)'")

                            // 座標を正規化
                            let normalizedRect = CGRect(
                                x: box.origin.x / CGFloat(image.width),
                                y: box.origin.y / CGFloat(image.height),
                                width: box.width / CGFloat(image.width),
                                height: box.height / CGFloat(image.height)
                            )

                            return TranslationData(translatedText: response.targetText, boundingBox: normalizedRect)
                        } catch {
                            print("[MangaOCRService] 吹き出し[\(index)]のOCRまたは翻訳に失敗しました: \(error)")
                            return nil
                        }
                    }
                }

                for try await result in group {
                    if let result = result {
                        results.append(result)
                    }
                }
                return results
            }

            print("[MangaOCRService] 正常に終了。翻訳されたアイテム数: \(translationData.count)")
            return translationData

        } catch {
            print("[MangaOCRService] MANGA OCRパイプラインでエラーが発生しました: \(error)")
            return []
        }
    }

//    // MARK: - Debug Helpers
//
//    /// デバッグ用にCGImageをファイルとして保存します。
//    /// - Parameters:
//    ///   - cgImage: 保存するCGImage。
//    ///   - index: ファイル名に使用するインデックス。
//    private func saveDebugImage(_ cgImage: CGImage, index: Int) {
//        // デバッグ用の画像を保存するディレクトリを作成
//        let fileManager = FileManager.default
//        let debugDir = URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("debug_images", isDirectory: true)
//        do {
//            if !fileManager.fileExists(atPath: debugDir.path) {
//                try fileManager.createDirectory(at: debugDir, withIntermediateDirectories: true, attributes: nil)
//            }
//        } catch {
//            print("[Debug] デバッグ用ディレクトリの作成に失敗: \(error)")
//            return
//        }
//
//        // CGImageをPNGデータに変換
//        #if canImport(UIKit)
//        let image = UIImage(cgImage: cgImage)
//        guard let data = image.pngData() else {
//            print("[Debug] UIImageからPNGデータへの変換に失敗しました。")
//            return
//        }
//        #elseif canImport(AppKit)
//        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
//        guard let data = bitmapRep.representation(using: .png, properties: [:]) else {
//            print("[Debug] NSBitmapImageRepからPNGデータへの変換に失敗しました。")
//            return
//        }
//        #endif
//
//        // ファイルに書き込む
//        let fileURL = debugDir.appendingPathComponent("cropped_bubble_\(index).png")
//        do {
//            try data.write(to: fileURL)
//            print("[Debug] 切り抜いた画像を保存しました: \(fileURL.path)")
//        } catch {
//            print("[Debug] 画像のファイルへの書き込みに失敗: \(error)")
//        }
//    }
}
