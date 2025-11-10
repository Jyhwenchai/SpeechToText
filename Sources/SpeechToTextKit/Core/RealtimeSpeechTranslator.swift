#if os(iOS) && canImport(Speech) && canImport(AVFoundation)
import Foundation
import AVFoundation
import Speech

/// 实时语音翻译器：支持麦克风或外部 PCM 源
@available(iOS 13.0, *)
@MainActor
public final class RealtimeSpeechTranslator: NSObject, SpeechRealtimeTranslating {
  
  public typealias ResultHandler = SpeechRealtimeTranslating.ResultHandler
  
  /// 音频输入来源
  public enum InputSource {
    /// 由内部 AVAudioEngine 采集麦克风
    case microphone
    /// 由调用方提供 PCM 缓冲（例如自定义录音器）
    case external
  }
  
  // MARK: - Callbacks
  
  public var onResult: ResultHandler?
  public var onError: ((Error) -> Void)?
  
  // MARK: - Private properties
  
  private let config: RecognitionConfig
  private let permissionManager: SpeechPermissionManaging
  private let inputSource: InputSource
  private let audioEngine = AVAudioEngine()
  private let processingQueue = DispatchQueue(label: "com.speechtotextkit.realtime")
  
  private var recognizer: SFSpeechRecognizer?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var isRunning = false
  
  // MARK: - Init
  
  public init(
    config: RecognitionConfig,
    permissionManager: SpeechPermissionManaging = SpeechPermissionManager(),
    inputSource: InputSource = .microphone
  ) {
    self.config = config
    self.permissionManager = permissionManager
    self.inputSource = inputSource
  }
  
  // MARK: - SpeechRealtimeTranslating
  
  public func start() async throws {
    guard !isRunning else { return }
    
    try await ensureSpeechPermission()
    
    if inputSource == .microphone {
      try await ensureMicrophonePermission()
      try configureAudioSession()
    }
    
    try prepareRecognitionTask()
    
    if inputSource == .microphone {
      try startAudioEngine()
    }
    
    isRunning = true
  }
  
  public func stop() {
    guard isRunning else { return }
    
    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    
    recognitionTask = nil
    recognitionRequest = nil
    recognizer = nil
    
    if inputSource == .microphone {
      audioEngine.stop()
      audioEngine.inputNode.removeTap(onBus: 0)
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    isRunning = false
  }
  
  /// 外部 PCM 源推送数据（仅 `.external` 模式有效）
  public func appendExternalBuffer(_ buffer: AVAudioPCMBuffer) {
    guard inputSource == .external, let request = recognitionRequest else { return }
    processingQueue.async {
      request.append(buffer)
    }
  }
  
  // MARK: - Permission
  
  private func ensureSpeechPermission() async throws {
    let status = permissionManager.status()
    switch status {
    case .authorized:
      return
    case .notDetermined:
      if await permissionManager.request() != .authorized {
        throw RecognitionError.notDetermined
      }
    case .denied:
      throw RecognitionError.denied
    case .restricted:
      throw RecognitionError.restricted
    }
  }
  
  private func ensureMicrophonePermission() async throws {
    let session = AVAudioSession.sharedInstance()
    switch session.recordPermission {
    case .granted:
      return
    case .denied:
      throw RecognitionError.denied
    case .undetermined:
      let granted = await withCheckedContinuation { continuation in
        session.requestRecordPermission { granted in
          continuation.resume(returning: granted)
        }
      }
      guard granted else {
        throw RecognitionError.denied
      }
    @unknown default:
      throw RecognitionError.restricted
    }
  }
  
  // MARK: - Setup
  
  private func configureAudioSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .playAndRecord,
      mode: .measurement,
      options: [.duckOthers, .allowBluetoothA2DP, .defaultToSpeaker]
    )
    try session.setActive(true, options: .notifyOthersOnDeactivation)
  }
  
  private func prepareRecognitionTask() throws {
    guard let recognizer = SFSpeechRecognizer(locale: config.locale) else {
      throw RecognitionError.localeUnsupported
    }
    guard recognizer.isAvailable else {
      throw RecognitionError.notAvailable
    }
    
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    request.requiresOnDeviceRecognition = config.requiresOnDeviceRecognition
    request.taskHint = config.taskHint.speechTaskHint
    
    self.recognizer = recognizer
    recognitionRequest = request
    
    recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
      guard let self else { return }
      if let error {
        let mapped = SpeechRecognitionHelpers.mapError(error)
        self.onError?(mapped)
        self.stop()
        return
      }
      
      guard let result else { return }
      let recognitionResult = SpeechRecognitionHelpers.buildResult(
        from: result,
        locale: self.config.locale
      )
      self.onResult?(recognitionResult, result.isFinal)
    }
  }
  
  private func startAudioEngine() throws {
    let inputNode = audioEngine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)
    
    inputNode.removeTap(onBus: 0)
    inputNode.installTap(
      onBus: 0,
      bufferSize: 2048,
      format: recordingFormat
    ) { [weak self] buffer, _ in
      guard let self, let request = self.recognitionRequest else { return }
      request.append(buffer)
    }
    
    audioEngine.prepare()
    try audioEngine.start()
  }
}
#endif
