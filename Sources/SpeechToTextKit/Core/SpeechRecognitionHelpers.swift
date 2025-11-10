#if os(iOS) && canImport(Speech)
import Foundation
import Speech

/// Speech Framework 共用帮助方法
@available(iOS 13.0, *)
enum SpeechRecognitionHelpers {
  
  /// 将 Speech 结果转换为 RecognitionResult
  /// - Parameters:
  ///   - sfResult: Speech Framework 返回的结果
  ///   - locale: 当前识别使用的语言
  /// - Returns: 转换后的业务结果
  static func buildResult(
    from sfResult: SFSpeechRecognitionResult,
    locale: Locale
  ) -> RecognitionResult {
    let transcription = sfResult.bestTranscription
    let text = transcription.formattedString
    
    let confidence: Double? = {
      let segments = transcription.segments
      guard !segments.isEmpty else { return nil }
      let sum = segments.reduce(0.0) { $0 + Double($1.confidence) }
      return sum / Double(segments.count)
    }()
    
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
  
  /// 将系统错误映射为业务错误
  /// - Parameter error: Speech Framework 抛出的错误
  /// - Returns: 对应的 RecognitionError
  static func mapError(_ error: Error) -> RecognitionError {
    let nsError = error as NSError
    
    if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
      return .cancelled
    }
    
    if nsError.domain == "kAFAssistantErrorDomain" {
      switch nsError.code {
      case 1100, 1101:
        return .denied
      case 203, 216:
        return .notAvailable
      default:
        return .underlying(message: nsError.localizedDescription)
      }
    }
    
    return .underlying(message: error.localizedDescription)
  }
}
#endif
