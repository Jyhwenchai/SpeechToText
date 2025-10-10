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
    let status = await permissionManager.status()
    
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
    request.taskHint = mapTaskHint(config.taskHint)
    
    let locale = config.locale
    return try await withCheckedThrowingContinuation { continuation in
      var hasResumed = false
      
      let task = recognizer.recognitionTask(with: request) { result, error in
        // 避免重复恢复 continuation
        guard !hasResumed else { return }
        
        // 处理错误
        if let error = error {
          hasResumed = true
          let mappedError = Self.mapErrorStatic(error)
          continuation.resume(throwing: mappedError)
          return
        }
        
        // 处理最终结果
        if let result = result, result.isFinal {
          hasResumed = true
          let recognitionResult = Self.buildResultStatic(from: result, locale: locale)
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
  
  /// 构建识别结果
  private nonisolated static func buildResultStatic(
    from sfResult: SFSpeechRecognitionResult,
    locale: Locale
  ) -> RecognitionResult {
    let transcription = sfResult.bestTranscription
    let text = transcription.formattedString
    
    // 计算平均置信度
    let confidence: Double? = {
      let segments = transcription.segments
      guard !segments.isEmpty else { return nil }
      let sum = segments.reduce(0.0) { $0 + Double($1.confidence) }
      return sum / Double(segments.count)
    }()
    
    // 构建片段信息
    let segments: [RecognitionSegment]? = {
      let sfSegments = transcription.segments
      guard !sfSegments.isEmpty else { return nil }
      
      return sfSegments.map { segment in
        RecognitionSegment(
          text: segment.substring,
          timestamp: segment.timestamp,
          duration: segment.duration,
          confidence: Double(segment.confidence)
        )
      }
    }()
    
    return RecognitionResult(
      text: text,
      confidence: confidence,
      segments: segments,
      locale: locale
    )
  }
  
  /// 映射任务提示
  private func mapTaskHint(_ hint: TaskHint) -> SFSpeechRecognitionTaskHint {
    switch hint {
    case .unspecified:
      return .unspecified
    case .dictation:
      return .dictation
    case .search:
      return .search
    case .confirmation:
      return .confirmation
    }
  }
  
  /// 映射系统错误到业务错误
  private nonisolated static func mapErrorStatic(_ error: Error) -> RecognitionError {
    let nsError = error as NSError
    
    // 检查取消错误
    if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
      return .cancelled
    }
    
    // 检查语音识别相关错误
    if nsError.domain == "kAFAssistantErrorDomain" {
      switch nsError.code {
      case 1100, 1101: // 权限相关
        return .denied
      case 203, 216: // 网络或服务不可用
        return .notAvailable
      default:
        return .underlying(message: nsError.localizedDescription)
      }
    }
    
    // 默认包装为底层错误
    return .underlying(message: error.localizedDescription)
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
