//
//  AudioRecorder.swift
//  TestVoiceRecorder
//
//  Created by didong on 11/9/25.
//


//
//  AudioRecorderDelegate.swift
//  LuoboIM
//
//  Created by 蔡志文 on 3/5/25.
//

import Foundation
import AVFoundation
import Combine

// MARK: - 音频录制核心类

/// 高级录音封装：一边写文件、一边推送实时 PCM 数据，供离线与实时翻译同时使用。
public final class AudioRecorder: NSObject, @unchecked Sendable {
  // MARK: 配置参数

  /// 输出文件格式（决定编码设置与扩展名）
  public enum AudioFormat: String, CaseIterable {
    case m4a // AAC格式
    case wav // PCM格式
    case aiff // AIFF格式

    var fileType: AVFileType {
      switch self {
      case .m4a: return .m4a
      case .wav: return .wav
      case .aiff: return .aiff
      }
    }

    var settings: [String: Any] {
      switch self {
      case .m4a:
        return [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVSampleRateKey: 44100.0,
          AVNumberOfChannelsKey: 1,
          AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
      case .wav, .aiff:
        return [
          AVFormatIDKey: kAudioFormatLinearPCM,
          AVSampleRateKey: 44100.0,
          AVNumberOfChannelsKey: 1,
          AVLinearPCMBitDepthKey: 16,
          AVLinearPCMIsFloatKey: false
        ]
      }
    }
  }

  /// 对外广播的状态，便于 UI 同步显示
  public enum Status {
    case starting
    case progress(TimeInterval)
    case completion(saveURL: URL)
    case failure(Error)
    case cancel
  }

  /// 用于波形显示/音量门限判断
  public struct Power: Sendable {
    public let average: Float
    public let peak: Float
  }

  /// tap Buffer 的 PCM 采样精度（Float32/Int16），实时翻译需要知道如何还原
  public enum SampleFormat: Sendable {
    case float32
    case int16

    var bytesPerSample: Int {
      switch self {
      case .float32: return MemoryLayout<Float>.size
      case .int16: return MemoryLayout<Int16>.size
      }
    }
  }

  // 实时翻译消费的 PCM 数据块，保持格式信息方便还原 AVAudioPCMBuffer
  public struct RealtimeAudioChunk: Sendable {
    public let data: Data
    public let sampleRate: Double
    public let channelCount: AVAudioChannelCount
    public let duration: TimeInterval
    public let sampleFormat: SampleFormat
  }

  /// 内部错误，便于更明确地抛出问题
  enum RecorderError: Error {
    case permissionDenied
    case invalidFormat
    case engineUnavailable
    case fileWriteFailed
  }

  // MARK: 属性

  /// 驱动麦克风输入、安装 tap 的核心引擎
  private let audioEngine = AVAudioEngine()
  /// 当前写入中的音频文件
  private var audioFile: AVAudioFile?
  /// 输入节点的 PCM 格式（单声道/采样率/位宽）
  private var inputFormat: AVAudioFormat?
  /// 录音生成的最终文件 URL
  private var recordingFileURL: URL?
  /// 记录开始时间，以便计算进度 & 超时
  private var recordingStartTime: Date?
  /// 处理 PCM、写文件的串行队列，避免竞态
  private let streamingQueue = DispatchQueue(label: "com.testvoicerecorder.streaming")
  private var recordingTimer: Timer?
  private var currentRecordingTime: TimeInterval = 0
  private var statusChangedSubject = PassthroughSubject<Status, Never>()
  public var statusChangedPublisher: AnyPublisher<Status, Never> {
    statusChangedSubject.eraseToAnyPublisher()
  }

  private var powerUpdatedSubject = PassthroughSubject<Power, Never>()
  public var powerUpdatedPublisher: AnyPublisher<Power, Never> {
    powerUpdatedSubject.eraseToAnyPublisher()
  }

  private var realtimeChunkSubject = PassthroughSubject<RealtimeAudioChunk, Never>()
  public var realtimeChunkPublisher: AnyPublisher<RealtimeAudioChunk, Never> {
    realtimeChunkSubject.eraseToAnyPublisher()
  }

  // 用户配置
  var maxRecordingDuration: TimeInterval = 1 * 60 // 默认10分钟
  private var saveDirectory: URL
  private let format: AudioFormat

  // MARK: 初始化

  public init(format: AudioFormat = .m4a) {
    self.format = format
    saveDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
    super.init()
  }

  // MARK: 核心控制方法
  /// 录音权限校验（同步版，便于在 UIKit 按钮里快速判断）
  public func checkRecordPermission() -> Bool {
    if AVAudioSession.sharedInstance().recordPermission == .granted {
      return true
    }

    AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    return false
  }
//  func checkRecordPermission() async -> Bool {
//    await withCheckedContinuation { continuation in
//      if AVAudioSession.sharedInstance().recordPermission == .granted {
//        continuation.resume(returning: true)
//        return
//      }
//      AVAudioSession.sharedInstance().requestRecordPermission { granted in
//        continuation.resume(returning: granted)
//      }
//    }
//  }

  /// 开始录音（创建目录 -> 配置 AudioSession -> 启动 Engine）
  public func start(with saveDirectory: URL? = .none) throws {
    if let saveDirectory {
      self.saveDirectory = saveDirectory
    }
    createFileDirectory()

    guard checkRecordPermission() else {
      throw RecorderError.permissionDenied
    }

    let fileName = "recording_\(Int(Date().timeIntervalSince1970)).\(format.rawValue)"
    let fileURL = self.saveDirectory.appendingPathComponent(fileName)
    recordingFileURL = fileURL

    try configureSession()
    try prepareEngine(for: fileURL)

    recordingStartTime = Date()
    startTimers()
    try audioEngine.start()

    emitStatus(.starting)
  }

  /// 停止录音并保存
  public func stop() {
    guard audioEngine.isRunning else {
      cleanup()
      return
    }
    audioEngine.stop()
    audioEngine.inputNode.removeTap(onBus: 0)
    finishRecording(sendCompletion: true)
  }

  /// 取消录音并删除文件
  public func cancel() {
    audioEngine.stop()
    audioEngine.inputNode.removeTap(onBus: 0)
    if let recordingFileURL, FileManager.default.fileExists(atPath: recordingFileURL.path) {
      try? FileManager.default.removeItem(at: recordingFileURL)
    }
    finishRecording(sendCompletion: false)
    emitStatus(.cancel)
  }

  // MARK: 定时器管理

  /// 两个定时器：1) 更新功率 2) 记录录音时长
  private func startTimers() {
    // 功率更新定时器（每0.1秒更新）
    // 录音时长定时器
    currentRecordingTime = 0
    recordingTimer = Timer.scheduledTimer(
      withTimeInterval: 1,
      repeats: true
    ) { [weak self] _ in
      guard let self = self else { return }
      self.currentRecordingTime += 1
      if self.currentRecordingTime >= self.maxRecordingDuration {
        self.stop()
      }
        self.emitStatus(.progress(self.currentRecordingTime))
    }
  }

  /// 停止 Engine / 计时器 / 音频会话
  private func cleanup() {
    recordingTimer?.invalidate()
    audioFile = nil
    recordingFileURL = nil
    recordingStartTime = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
  }
}

extension AudioRecorder {
  /// 录音输出目录，默认在系统 tmp，可自定义
  private func createFileDirectory() {
    if FileManager.default.fileExists(atPath: saveDirectory.path) { return }
    do {
      print("创建音频保存目录... ")
      try FileManager.default.createDirectory(
        at: saveDirectory,
        withIntermediateDirectories: true,
        attributes: [
          // 设置目录不备份到 iCloud（可选）
          .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
        ]
      )
    } catch {
      print("目录创建失败: \(error.localizedDescription)")
      // 抛出错误或使用备用目录
      assertionFailure("必须处理目录创建失败的情况")
    }
  }

  /// 设置为录音模式，允许外放和蓝牙耳机
  private func configureSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
    try session.setActive(true, options: .notifyOthersOnDeactivation)
  }

  /// 清空旧的 tap，并安装新的 PCM tap，顺便准备写入文件
  private func prepareEngine(for fileURL: URL) throws {
    if audioEngine.isRunning {
      audioEngine.stop()
    }
    audioEngine.reset()

    let inputNode = audioEngine.inputNode
    inputNode.removeTap(onBus: 0)

    let inputFormat = inputNode.outputFormat(forBus: 0)
    self.inputFormat = inputFormat

    guard AVAudioFormat(settings: format.settings) != nil else {
      throw RecorderError.invalidFormat
    }
    audioFile = try AVAudioFile(
      forWriting: fileURL,
      settings: format.settings,
      commonFormat: inputFormat.commonFormat,
      interleaved: inputFormat.isInterleaved
    )

    inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
      guard let chunk = AudioRecorder.makeRealtimeChunk(from: buffer) else { return }
      Task { @MainActor [weak self] in
        self?.handleIncomingChunk(chunk)
      }
    }
  }

  /// 主线程调度：在实时线程复制 PCM 后，将 chunk 投递到串行队列。
  @MainActor
  private func handleIncomingChunk(_ chunk: RealtimeAudioChunk) {
    streamingQueue.async { [weak self] in
      guard let self = self else { return }
      self.handlePowerUpdate(from: chunk)
      self.handleStreaming(chunk)
      self.handleFileWrite(with: chunk)
      self.enforceDurationLimitIfNeeded()
    }
  }
  
  /// 将当前 chunk 发给实时翻译/波形等订阅者
  private func handleStreaming(_ chunk: RealtimeAudioChunk) {
    realtimeChunkSubject.send(chunk)
  }
  
  /// 把 chunk 转回 PCM buffer，同步写入文件
  private func handleFileWrite(with chunk: RealtimeAudioChunk) {
    guard
      let audioFile,
      let buffer = chunk.makePCMBuffer()
    else { return }
    
    do {
      try audioFile.write(from: buffer)
    } catch {
      emitStatus(.failure(error))
      cancel()
    }
  }
  
  /// 计算平均/峰值功率（dB）
  private func handlePowerUpdate(from chunk: RealtimeAudioChunk) {
    let bytesPerSample = chunk.sampleFormat.bytesPerSample
    let totalSamples = chunk.data.count / bytesPerSample
    guard totalSamples > 0 else {
      emitPower(.init(average: -160, peak: -160))
      return
    }
    
    var rms: Double = 0
    var peak: Double = 0
    
    chunk.data.withUnsafeBytes { rawBuffer in
      switch chunk.sampleFormat {
      case .float32:
        let samples = rawBuffer.bindMemory(to: Float.self)
        for index in 0..<totalSamples {
          let value = Double(samples[index])
          rms += value * value
          peak = max(peak, abs(value))
        }
      case .int16:
        let samples = rawBuffer.bindMemory(to: Int16.self)
        let scale = 1.0 / Double(Int16.max)
        for index in 0..<totalSamples {
          let value = Double(samples[index]) * scale
          rms += value * value
          peak = max(peak, abs(value))
        }
      }
    }
    
    rms = sqrt(rms / Double(totalSamples))
    let averagePower = Float(20 * log10(max(rms, Double(Float.ulpOfOne))))
    let peakPower = Float(20 * log10(max(peak, Double(Float.ulpOfOne))))
    emitPower(.init(average: averagePower, peak: peakPower))
  }
  
  private func enforceDurationLimitIfNeeded() {
    guard let start = recordingStartTime else { return }
    let elapsed = Date().timeIntervalSince(start)
    if elapsed >= maxRecordingDuration {
      DispatchQueue.main.async { [weak self] in
        self?.stop()
      }
    }
  }

  private func finishRecording(sendCompletion: Bool) {
    let finalURL = recordingFileURL
    cleanup()
    guard sendCompletion, let url = finalURL else { return }
    emitStatus(.completion(saveURL: url))
  }
}

private extension AVAudioPCMBuffer {
  /// 将 AVAudioPCMBuffer 拷贝为 Data，并附带采样格式信息，避免直接共享底层内存。
  func makePCMData() -> (data: Data, format: AudioRecorder.SampleFormat)? {
    let channels = Int(format.channelCount)
    let frames = Int(frameLength)
    guard frames > 0 else { return nil }
    
    switch format.commonFormat {
    case .pcmFormatFloat32:
      guard let channelData = floatChannelData else { return nil }
      var data = Data(capacity: frames * channels * MemoryLayout<Float>.size)
      for frame in 0..<frames {
        for channel in 0..<channels {
          var sample = channelData[channel][frame]
          withUnsafeBytes(of: &sample) { bytes in
            data.append(contentsOf: bytes)
          }
        }
      }
      return (data, .float32)
    case .pcmFormatInt16:
      guard let channelData = int16ChannelData else { return nil }
      var data = Data(capacity: frames * channels * MemoryLayout<Int16>.size)
      for frame in 0..<frames {
        for channel in 0..<channels {
          var sample = channelData[channel][frame]
          withUnsafeBytes(of: &sample) { bytes in
            data.append(contentsOf: bytes)
          }
        }
      }
      return (data, .int16)
    default:
      return nil
    }
  }
}

extension AudioRecorder.RealtimeAudioChunk {
  func makePCMBuffer() -> AVAudioPCMBuffer? {
    let channelCount = Int(channelCount)
    guard channelCount > 0 else { return nil }
    
    let commonFormat: AVAudioCommonFormat
    switch sampleFormat {
    case .float32:
      commonFormat = .pcmFormatFloat32
    case .int16:
      commonFormat = .pcmFormatInt16
    }
    
    let totalSamples = data.count / sampleFormat.bytesPerSample
    guard totalSamples > 0 else { return nil }
    let frameCount = totalSamples / channelCount
    
    guard let format = AVAudioFormat(
      commonFormat: commonFormat,
      sampleRate: sampleRate,
      channels: self.channelCount,
      interleaved: false
    ) else { return nil }
    
    guard let buffer = AVAudioPCMBuffer(
      pcmFormat: format,
      frameCapacity: AVAudioFrameCount(frameCount)
    ) else { return nil }
    
    buffer.frameLength = AVAudioFrameCount(frameCount)
    
    switch sampleFormat {
    case .float32:
      guard let channelData = buffer.floatChannelData else { return nil }
      data.withUnsafeBytes { rawBuffer in
        let pointer = rawBuffer.bindMemory(to: Float.self)
        for frame in 0..<frameCount {
          for channel in 0..<channelCount {
            let sampleIndex = frame * channelCount + channel
            channelData[channel][frame] = pointer[sampleIndex]
          }
        }
      }
    case .int16:
      guard let channelData = buffer.int16ChannelData else { return nil }
      data.withUnsafeBytes { rawBuffer in
        let pointer = rawBuffer.bindMemory(to: Int16.self)
        for frame in 0..<frameCount {
          for channel in 0..<channelCount {
            let sampleIndex = frame * channelCount + channel
            channelData[channel][frame] = pointer[sampleIndex]
          }
        }
      }
    }
    
    return buffer
  }
}

// MARK: - Helper Builders

private extension AudioRecorder {
  static func makeRealtimeChunk(from buffer: AVAudioPCMBuffer) -> RealtimeAudioChunk? {
    guard let pcm = buffer.makePCMData() else { return nil }
    let duration = Double(buffer.frameLength) / buffer.format.sampleRate
    return RealtimeAudioChunk(
      data: pcm.data,
      sampleRate: buffer.format.sampleRate,
      channelCount: buffer.format.channelCount,
      duration: duration,
      sampleFormat: pcm.format
    )
  }
}

// MARK: - Main-thread emit helpers

private extension AudioRecorder {
  func emitStatus(_ status: Status) {
    DispatchQueue.main.async { [weak self] in
      self?.statusChangedSubject.send(status)
    }
  }
  
  func emitPower(_ power: Power) {
    DispatchQueue.main.async { [weak self] in
      self?.powerUpdatedSubject.send(power)
    }
  }
}
