//
//  SpeechToTextKit.swift
//  SpeechToTextKit
//
//  语音转文本 Swift Package
//  提供基于 iOS Speech Framework 的音频文件转文本功能
//

import Foundation

/// SpeechToTextKit 版本号
public let version = "1.0.0"

/// SpeechToTextKit 提供基于 iOS Speech Framework 的音频文件转文本功能
///
/// ## 主要功能
/// - 音频文件转文本
/// - 权限管理
/// - 多语言支持
/// - 完善的错误处理
///
/// ## 使用示例
/// ```swift
/// import SpeechToTextKit
///
/// let permissionManager = SpeechPermissionManager()
/// let status = await permissionManager.request()
///
/// if status == .authorized {
///     let transcriber = SpeechFileTranscriber()
///     let config = RecognitionConfig.chinese
///     let result = try await transcriber.transcribe(
///         fileURL: audioFileURL,
///         config: config
///     )
///     print(result.text)
/// }
/// ```
public enum SpeechToTextKit {}
