import Foundation
import Vision
import CoreGraphics
import Translation

// テキスト認識の結果を保持する構造体
struct DetectedText {
    let text: String
    let boundingBox: CGRect
}

// 翻訳結果を保持する構造体
struct TranslationData {
    let translatedText: String
    let boundingBox: CGRect
}

class TranslationService {
    // 画像からテキストを認識する関数
    static func recognizeText(from image: CGImage, completion: @escaping ([DetectedText]) -> Void) {
        let request = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                print("Text recognition failed: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }

            let detectedTexts = observations.compactMap { observation -> DetectedText? in
                guard let topCandidate = observation.topCandidates(1).first else { return nil }

                let bounds = observation.boundingBox
                let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
                let convertedRect = bounds.applying(transform)

                return DetectedText(text: topCandidate.string, boundingBox: convertedRect)
            }

            completion(detectedTexts)
        }

        request.recognitionLanguages = ["ja-JP"]
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform text recognition: \(error.localizedDescription)")
                completion([])
            }
        }
    }

    // テキストを翻訳する関数
    @available(macOS 14.0, iOS 17.0, *)
    static func translate(detectedTexts: [DetectedText], with session: TranslationSession, completion: @escaping ([TranslationData]) -> Void) {
        guard !detectedTexts.isEmpty else {
            completion([])
            return
        }

        Task {
            let translationData = try await withThrowingTaskGroup(of: TranslationData?.self) { group in
                var results = [TranslationData]()
                results.reserveCapacity(detectedTexts.count)

                for detectedText in detectedTexts {
                    group.addTask {
                        do {
                            let response = try await session.translate(detectedText.text)
                            return TranslationData(translatedText: response.targetText, boundingBox: detectedText.boundingBox)
                        } catch {
                            print("Failed to translate text '\(detectedText.text)': \(error)")
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

            DispatchQueue.main.async {
                completion(translationData)
            }
        }
    }
}
