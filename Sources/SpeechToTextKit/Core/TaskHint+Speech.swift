#if os(iOS) && canImport(Speech)
import Speech

@available(iOS 13.0, *)
extension TaskHint {
  /// 将自定义任务提示映射为 Speech Framework 类型
  var speechTaskHint: SFSpeechRecognitionTaskHint {
    switch self {
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
}
#endif
