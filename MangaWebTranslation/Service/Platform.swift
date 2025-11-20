//
//  Platform.swift
//  MangaWebTranslation6
//
//  Created by ibis on 2025/11/19.
//
//  This file provides platform-independent type definitions.
//  このファイルは、プラットフォームに依存しない型の定義を提供します。
//

#if canImport(UIKit)
internal import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
internal import AppKit
typealias PlatformImage = NSImage
#endif
