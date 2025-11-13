//
//  SpeechPermissionManager.swift
//  SpeechToTextKit
//
//  语音识别权限管理器
//

import Foundation

#if os(iOS) && canImport(Speech)
import Speech

/// 语音识别权限管理器（iOS 专属）
@available(iOS 13.0, *)
public final class SpeechPermissionManager: SpeechPermissionManaging {
  
  public init() {}
  
  // MARK: - SpeechPermissionManaging
  
  /// 获取当前权限状态
  nonisolated public func status() -> SpeechPermissionStatus {
    let authStatus = SFSpeechRecognizer.authorizationStatus()
    return mapAuthorizationStatus(authStatus)
  }
  
  /// 请求语音识别权限
  public func request() async -> SpeechPermissionStatus {
    await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { authStatus in
        // 使用静态方法避免 actor 隔离问题
        let status = Self.mapAuthorizationStatusStatic(authStatus)
        continuation.resume(returning: status)
      }
    }
  }
  
  // MARK: - Private Methods
  
  /// 将系统权限状态映射到业务权限状态
  nonisolated private func mapAuthorizationStatus(
    _ authStatus: SFSpeechRecognizerAuthorizationStatus
  ) -> SpeechPermissionStatus {
    Self.mapAuthorizationStatusStatic(authStatus)
  }
  
  /// 静态方法：将系统权限状态映射到业务权限状态
  /// 用于在闭包中使用，避免 actor 隔离问题
  nonisolated private static func mapAuthorizationStatusStatic(
    _ authStatus: SFSpeechRecognizerAuthorizationStatus
  ) -> SpeechPermissionStatus {
    switch authStatus {
    case .notDetermined:
      return .notDetermined
    case .denied:
      return .denied
    case .restricted:
      return .restricted
    case .authorized:
      return .authorized
    @unknown default:
      return .notDetermined
    }
  }
}

#else

/// 非 iOS 平台的占位实现
public actor SpeechPermissionManager: SpeechPermissionManaging {
  public init() {}
  
  nonisolated public func status() -> SpeechPermissionStatus {
    .notDetermined
  }
  
  public func request() async -> SpeechPermissionStatus {
    .notDetermined
  }
}

#endif
