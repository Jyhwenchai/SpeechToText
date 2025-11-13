//
//  SpeechInterfaces.swift
//  SpeechToTextKit
//
//  语音识别协议接口定义
//

import Foundation

// MARK: - 权限状态

/// 语音识别权限状态
public enum SpeechPermissionStatus: Sendable, Equatable {
  /// 未确定（用户尚未做出选择）
  case notDetermined
  
  /// 已拒绝
  case denied
  
  /// 受限制（例如家长控制）
  case restricted
  
  /// 已授权
  case authorized
}

// MARK: - 权限管理协议

/// 语音识别权限管理协议
public protocol SpeechPermissionManaging: Sendable {
  /// 获取当前权限状态
  /// - Returns: 当前的权限状态
  nonisolated func status() -> SpeechPermissionStatus
  
  /// 请求语音识别权限
  /// - Returns: 权限请求后的状态
  func request() async -> SpeechPermissionStatus
}

// MARK: - 文件转文本协议

/// 音频文件转文本协议
public protocol SpeechFileTranscribing: Sendable {
  /// 将音频文件转换为文本
  /// - Parameters:
  ///   - fileURL: 音频文件的本地 URL
  ///   - config: 识别配置
  /// - Returns: 识别结果
  /// - Throws: RecognitionError
  func transcribe(
    fileURL: URL,
    config: RecognitionConfig
  ) async throws -> RecognitionResult
}

#if os(iOS) && canImport(Speech)
/// 实时语音转写协议（仅 iOS 可用）
@available(iOS 13.0, *)
public protocol SpeechRealtimeTranslating {
  /// 实时识别回调
  typealias ResultHandler = (RecognitionResult, Bool) -> Void
  
  /// 识别结果回调，`Bool` 表示是否为最终结果
  var onResult: ResultHandler? { get set }
  
  /// 错误回调
  var onError: ((Error) -> Void)? { get set }
  
  /// 开始实时识别
  func start() async throws
  
  /// 停止实时识别并清理资源
  func stop()
}
#endif
