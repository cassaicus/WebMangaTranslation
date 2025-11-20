import Foundation
import CoreML
import Vision

#if canImport(UIKit)
internal import UIKit
#elseif canImport(AppKit)
internal import AppKit
#endif

//
// 検出処理中に発生する可能性のあるエラーを定義する列挙型。
//
enum DetectionError: Error {
    case modelLoadError(Error)      // CoreMLモデルの読み込みに失敗した場合
    case imageConversionError       // NSImageからCGImageへの変換に失敗した場合
    case predictionError(Error)     // Visionフレームワークによる推論処理に失敗した場合
    case postProcessingError        // 推論結果の後処理に失敗した場合（現在は未使用）
}

//
// CoreMLモデルを使用して画像から物体（この場合は吹き出し）を検出するエンジンクラス。
//
// Visionフレームワークと連携して、画像内の特定の領域（バウンディングボックス）を特定します。
//
// 【リファクタリングの提案】
// - シングルトンパターン: DetectionEngineの初期化は、モデルの読み込みに時間がかかる可能性があるため、
//   アプリケーション全体で単一のインスタンスを共有するシングルトンとして実装することが望ましいです。
//   `static let shared = try? DetectionEngine()` のような形で提供できます。
// - モデル名のハードコーディング: モデル名 `best` が直接コードに埋め込まれています。
//   将来的にモデルを更新したり、複数のモデルを切り替えたりすることを考慮すると、
//   設定ファイルや外部の定数ファイルからモデル名を読み込むようにすると、より柔軟性が高まります。
// - 非同期処理: `init()` と `detectSpeechBubbles` は同期的（ブロッキング）な処理です。
//   特にUIスレッドから呼び出されると、アプリケーションがフリーズする原因になります。
//   `init`はアプリ起動時のバックグラウンドスレッドで、`detectSpeechBubbles`は
//   `Task`や`DispatchQueue.global().async`などを使って非同期に実行するように設計するべきです。
//
class DetectionEngine {

    // 自動生成されたCoreMLモデルクラスのインスタンス。
    private let model: best
    // Visionフレームワークで使用するためのモデルラッパー。
    private var visionModel: VNCoreMLModel!

    //
    // イニシャライザ。CoreMLモデルを読み込み、Visionフレームワークで利用可能な形式に変換します。
    //
    // - throws: モデルの読み込みや変換に失敗した場合、DetectionError.modelLoadErrorをスローします。
    //
    init(computeUnit: MLComputeUnits = .all) throws {
        do {
            let config = MLModelConfiguration()
            // .all を指定することで、CPU, GPU, Neural Engineの中から最適な計算ユニットが自動的に選択されます。
            // 特定のデバイスでパフォーマンスを最適化したい場合や、電力消費を抑えたい場合は、
            // .cpuOnly や .cpuAndGPU などを明示的に指定することも検討できます。
            config.computeUnits = computeUnit
            self.model = try best(configuration: config)
            self.visionModel = try VNCoreMLModel(for: model.model)
        } catch {
            // エラーが発生した場合は、カスタムエラー型でラップして再スローします。
            throw DetectionError.modelLoadError(error)
        }
    }

    //
    // 指定されたNSImageから吹き出しを検出し、その位置を示すCGRectの配列を返します。
    //
    // - parameter image: 吹き出しを検出したいPlatformImage (UIImage or NSImage)。
    // - returns: 検出された各吹き出しのバウンディングボックス（CGRect）の配列。
    // - throws: 画像変換や推論処理でエラーが発生した場合にDetectionErrorをスローします。
    //
    // 【潜在的なバグや欠陥】
    // - 座標系の不一致: `PlatformImage`のサイズと`CGImage`のピクセルサイズは、Retinaディスプレイなどでは異なる場合があります。
    //   `cgImage.width`, `cgImage.height` を使ってピクセル単位で座標計算を行っている点は正しいアプローチです。
    //   もし`image.size`を使ってしまうと、座標がずれる原因になります。
    // - スレッド安全性: このメソッドは同期的であり、重い処理であるためメインスreadで呼び出すべきではありません。
    //   呼び出し元で非同期化する責任がありますが、このクラス内で非同期API（例: `async throws`）を提供した方が、
    //   より安全で使いやすい設計になります。
    // - エラーの詳細情報: `predictionError` でラップしている元のエラーには、問題解決に役立つ詳細情報が含まれている可能性があります。
    //   ロギングフレームワークなどを使って、元のエラー情報も記録しておくとデバッグが容易になります。
    //
    func detectSpeechBubbles(on image: PlatformImage) throws -> [CGRect] {
        print("[DetectionEngine] detectSpeechBubbles 開始")
        // VisionフレームワークはCGImageを要求するため、PlatformImageから変換します。
        #if canImport(UIKit)
        guard let cgImage = image.cgImage else {
            print("[DetectionEngine] UIImageからCGImageへの変換に失敗しました。")
            throw DetectionError.imageConversionError
        }
        #elseif canImport(AppKit)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("[DetectionEngine] NSImageからCGImageへの変換に失敗しました。")
            throw DetectionError.imageConversionError
        }
        #endif
        print("[DetectionEngine] CGImageの取得に成功。width: \(cgImage.width), height: \(cgImage.height)")

        // CoreMLモデルを使用するVisionリクエストを作成します。
        let request = VNCoreMLRequest(model: visionModel)
        // 画像をモデルの入力サイズに合わせてどのようにスケーリングするかを指定します。
        // .scaleFillはアスペクト比を維持せずに全体を埋めるようにリサイズします。
        request.imageCropAndScaleOption = .scaleFill

        // 画像処理リクエストをハンドリングするオブジェクトを作成します。
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        print("[DetectionEngine] Visionリクエストの実行を開始...")
        do {
            // 作成したリクエストを実行します。この処理は同期的です。
            try handler.perform([request])
            print("[DetectionEngine] Visionリクエストの実行が完了しました。")
        } catch {
            print("[DetectionEngine] Visionリクエストの実行でエラーが発生: \(error)")
            throw DetectionError.predictionError(error)
        }

        // リクエストの結果をVNRecognizedObjectObservationの配列として取得します。
        // この型は、バウンディングボックスを持つ物体検出の結果を表します。
        guard let observations = request.results as? [VNRecognizedObjectObservation] else {
            // モデルの出力形式が予期したものと異なる場合、このキャストは失敗します。
            // 例えば、モデルが物体検出ではなく、セマンティックセグメンテーションや他のタスクのモデルだった場合など。
            print("Warning: Model output could not be cast to [VNRecognizedObjectObservation].")
            return []
        }

        // 検出されたバウンディングボックスを、Visionの正規化座標から画像のピクセル座標に変換します。
        let boundingBoxes = observations.map { observation -> CGRect in
            // Visionの正規化座標は左下隅が原点(0,0)ですが、Core GraphicsやAppKitの座標系は左上隅が原点です。
            // そのため、Y軸を反転させる計算が必要です。
            let boundingBox = observation.boundingBox
            let imageWidth = CGFloat(cgImage.width)
            let imageHeight = CGFloat(cgImage.height)

            return CGRect(
                x: boundingBox.origin.x * imageWidth,
                // Y座標を (1 - y - height) とすることで、左上原点の座標系に変換します。
                y: (1 - boundingBox.origin.y - boundingBox.size.height) * imageHeight,
                width: boundingBox.size.width * imageWidth,
                height: boundingBox.size.height * imageHeight
            )
        }

        return boundingBoxes
    }
}