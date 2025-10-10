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
