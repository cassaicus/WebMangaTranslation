//
//  AppSettings.swift
//  MangaWebTranslation6
//
//  Created by Jules on 2025/11/18.
//
//  アプリ全体の設定を管理します。
//

import Foundation
internal import Combine

/// サポートする言語の構造体。
struct Language: Identifiable, Hashable {
    let id: String
    let name: String
}

/// 共通言語のリスト。
let commonLanguages: [Language] = [
    .init(id: "en", name: "English"),
    .init(id: "en-US", name: "English (US)"),
    .init(id: "en-GB", name: "English (UK)"),
    .init(id: "es", name: "Spanish"),
    .init(id: "fr", name: "French"),
    .init(id: "de", name: "German"),
    .init(id: "it", name: "Italian"),
    .init(id: "pt", name: "Portuguese"),
    .init(id: "pt-BR", name: "Portuguese (Brazil)"),
    .init(id: "zh-Hans", name: "Chinese (Simplified)"),
    .init(id: "zh-Hant", name: "Chinese (Traditional)"),
    .init(id: "ko", name: "Korean"),
    .init(id: "id", name: "Indonesian"),
    .init(id: "nl", name: "Dutch"),
    .init(id: "pl", name: "Polish"),
    .init(id: "th", name: "Thai"),
    .init(id: "tr", name: "Turkish"),
    .init(id: "uk", name: "Ukrainian"),
    .init(id: "vi", name: "Vietnamese"),
    .init(id: "ar", name: "Arabic"),
    .init(id: "hi", name: "Hindi"),
    .init(id: "ru", name: "Russian"),
]

/// アプリケーションの設定を管理するObservableObject。
class AppSettings: ObservableObject {

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let initialUrl = "initialUrl"
        static let targetLanguage = "targetLanguage"
        static let floatingButtonPosition = "floatingButtonPosition"
        static let computeUnit = "computeUnit"
    }

    // MARK: - Published Properties

    /// 初期表示URL。変更は自動的にUserDefaultsに保存されます。
    @Published var initialUrl: String {
        didSet {
            UserDefaults.standard.set(initialUrl, forKey: Keys.initialUrl)
        }
    }

    /// 翻訳のターゲット言語ID。変更は自動的にUserDefaultsに保存されます。
    @Published var targetLanguage: String {
        didSet {
            UserDefaults.standard.set(targetLanguage, forKey: Keys.targetLanguage)
        }
    }

    /// フローティングボタンの表示位置。変更は自動的にUserDefaultsに保存されます。
    @Published var floatingButtonPosition: FloatingButtonPosition {
        didSet {
            UserDefaults.standard.set(floatingButtonPosition.rawValue, forKey: Keys.floatingButtonPosition)
        }
    }

    /// Core MLモデルが使用する計算ユニット。変更は自動的にUserDefaultsに保存されます。
    @Published var computeUnit: ComputeUnitOption {
        didSet {
            UserDefaults.standard.set(computeUnit.rawValue, forKey: Keys.computeUnit)
        }
    }

    // MARK: - Initializer

    /// UserDefaultsから設定を読み込んで初期化します。
    init() {
        self.initialUrl = UserDefaults.standard.string(forKey: Keys.initialUrl) ?? "https://tonarinoyj.jp/"
        self.targetLanguage = UserDefaults.standard.string(forKey: Keys.targetLanguage) ?? "en" // デフォルトは英語

        // 保存されている値から位置を復元し、なければデフォルト値を設定します。
        let savedPosition = UserDefaults.standard.string(forKey: Keys.floatingButtonPosition) ?? FloatingButtonPosition.bottomLeft.rawValue
        self.floatingButtonPosition = FloatingButtonPosition(rawValue: savedPosition) ?? .bottomLeft

        // 保存されている計算ユニット設定を復元し、なければデフォルト値を設定します。
        let savedComputeUnit = UserDefaults.standard.string(forKey: Keys.computeUnit) ?? ComputeUnitOption.gpu.rawValue
        self.computeUnit = ComputeUnitOption(rawValue: savedComputeUnit) ?? .gpu
    }
}

/// フローティング翻訳ボタンの表示位置を示すenum。
/// CaseIterableに準拠しているため、Pickerなどで選択肢として簡単に利用できます。
enum FloatingButtonPosition: String, CaseIterable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String { self.rawValue }

    /// 表示用のテキスト。
    var displayName: String {
        switch self {
        case .topLeft:
            return "topLeft"
        case .topRight:
            return "topRight"
        case .bottomLeft:
            return "topRight"
        case .bottomRight:
            return "bottomRight"
        }
    }
}


import CoreML

/// Core MLモデルが使用する計算ユニットのオプション。
/// CaseIterableに準拠しているため、Pickerなどで選択肢として簡単に利用できます。
enum ComputeUnitOption: String, CaseIterable, Identifiable {
    case ane
    case gpu
    case cpu

    var id: String { self.rawValue }

    /// 設定画面に表示するテキスト。
    var displayName: String {
        switch self {
        case .ane:
            return "NeuralEngine"
        case .gpu:
            return "CPU and GPU"
        case .cpu:
            return "CPU only"
        }
    }

    /// `MLModelConfiguration`に設定するための`MLComputeUnits`値。
    var mlComputeUnits: MLComputeUnits {
        switch self {
        case .ane:
            return .all
        case .gpu:
            return .cpuAndGPU
        case .cpu:
            return .cpuOnly
        }
    }
}
