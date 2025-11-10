//
//  SpeechFileTranscriber.swift
//  SpeechToTextKit
//
//  音频文件转文本核心实现
//

import Foundation

#if os(iOS) && canImport(Speech)
import Speech

/// 音频文件转文本实现（iOS 专属）
@available(iOS 13.0, *)
public actor SpeechFileTranscriber: SpeechFileTranscribing {
  
  private let permissionManager: SpeechPermissionManaging
  
  /// 初始化
  /// - Parameter permissionManager: 权限管理器，默认使用 SpeechPermissionManager
  public init(permissionManager: SpeechPermissionManaging = SpeechPermissionManager()) {
    self.permissionManager = permissionManager
  }
  
  // MARK: - SpeechFileTranscribing
  
  /// 将音频文件转换为文本
  public func transcribe(
    fileURL: URL,
    config: RecognitionConfig
  ) async throws -> RecognitionResult {
    // 1. 验证文件存在
    try validateFileExists(at: fileURL)
    
    // 2. 检查权限
    try await ensurePermissionAuthorized()
    
    // 3. 创建识别器
    guard let recognizer = SFSpeechRecognizer(locale: config.locale) else {
      throw RecognitionError.localeUnsupported
    }
    
    // 4. 检查识别器可用性
    guard recognizer.isAvailable else {
      throw RecognitionError.notAvailable
    }
    
    // 5. 创建识别请求并执行识别
    return try await performRecognition(
      recognizer: recognizer,
      fileURL: fileURL,
      config: config
    )
  }
  
  // MARK: - Private Methods
  
  /// 验证文件存在
  private func validateFileExists(at url: URL) throws {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: url.path) else {
      throw RecognitionError.fileNotFound
    }
  }
  
  /// 确保权限已授权
  private func ensurePermissionAuthorized() async throws {
    let status = permissionManager.status()
    
    switch status {
    case .authorized:
      return
    case .notDetermined:
      // 尝试请求权限
      if await permissionManager.request() != .authorized {
        throw RecognitionError.notDetermined
      }
    case .denied:
      throw RecognitionError.denied
    case .restricted:
      throw RecognitionError.restricted
    }
  }
  
  
  /// 执行识别
  private func performRecognition(
    recognizer: SFSpeechRecognizer,
    fileURL: URL,
    config: RecognitionConfig
  ) async throws -> RecognitionResult {
    // 创建请求
    let request = SFSpeechURLRecognitionRequest(url: fileURL)
    request.shouldReportPartialResults = false
    request.requiresOnDeviceRecognition = config.requiresOnDeviceRecognition
    request.taskHint = config.taskHint.speechTaskHint
    
    let locale = config.locale
    return try await withCheckedThrowingContinuation { continuation in
      var hasResumed = false
      
      let task = recognizer.recognitionTask(with: request) { result, error in
        // 避免重复恢复 continuation
        guard !hasResumed else { return }
        
        // 处理错误
        if let error = error {
          hasResumed = true
          let mappedError = SpeechRecognitionHelpers.mapError(error)
          continuation.resume(throwing: mappedError)
          return
        }
        
        // 处理最终结果
        if let result = result, result.isFinal {
          hasResumed = true
          let recognitionResult = SpeechRecognitionHelpers.buildResult(from: result, locale: locale)
          continuation.resume(returning: recognitionResult)
        }
      }
      
      // 检查任务是否立即失败
      if task.state == .completed && !hasResumed {
        hasResumed = true
        continuation.resume(throwing: RecognitionError.invalidFile)
      }
    }
  }
  
}

#else

/// 非 iOS 平台的占位实现
public actor SpeechFileTranscriber: SpeechFileTranscribing {
  public init() {}
  
  public func transcribe(
    fileURL: URL,
    config: RecognitionConfig
  ) async throws -> RecognitionResult {
    throw RecognitionError.notAvailable
  }
}

#endif
