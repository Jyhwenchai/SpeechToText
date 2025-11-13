//
//  AudioRecorder.swift
//  Example-UIKit
//
//  完全基于 Swift Concurrency 的录音封装，提供状态/功率/实时 PCM 的异步流。
//

import AVFoundation
import Foundation

public actor AudioRecorder {

  // MARK: - Nested Types

  public enum AudioFormat: String, CaseIterable {
    case m4a
    case wav
    case aiff

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

  public enum Status: Sendable {
    case starting
    case progress(TimeInterval)
    case completion(saveURL: URL)
    case failure(Error)
    case cancel
  }

  public struct Power: Sendable {
    public let average: Float
    public let peak: Float
  }

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

  public struct RealtimeAudioChunk: Sendable {
    public let data: Data
    public let sampleRate: Double
    public let channelCount: AVAudioChannelCount
    public let duration: TimeInterval
    public let sampleFormat: SampleFormat
  }

  enum RecorderError: Error {
    case alreadyRunning
    case permissionDenied
    case invalidFormat
  }

  // MARK: - Public Configuration

  public var maxRecordingDuration: TimeInterval = 60

  // MARK: - Private State

  private var engineDriver: AudioEngineDriver?
  private let format: AudioFormat
  private var saveDirectory: URL

  private var audioFile: AVAudioFile?
  private var recordingFileURL: URL?
  private var recordingStartTime: Date?
  private var progressTask: Task<Void, Never>?
  private var isRunning = false
  private var currentRecordingTime: TimeInterval = 0

  private var statusContinuations: [UUID: AsyncStream<Status>.Continuation] = [:]
  private var powerContinuations: [UUID: AsyncStream<Power>.Continuation] = [:]
  private var chunkContinuations: [UUID: AsyncStream<RealtimeAudioChunk>.Continuation] = [:]

  // MARK: - Init

  public init(format: AudioFormat = .m4a) {
    self.format = format
    self.saveDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
  }

  deinit {
    progressTask?.cancel()
    statusContinuations.values.forEach { $0.finish() }
    powerContinuations.values.forEach { $0.finish() }
    chunkContinuations.values.forEach { $0.finish() }
  }

  // MARK: - Async Streams

  public func statusUpdates() -> AsyncStream<Status> {
    AsyncStream { continuation in
      let id = UUID()
      self.statusContinuations[id] = continuation
      continuation.onTermination = { [weak self] _ in
        guard let self else { return }
        Task { await self.removeStatusContinuation(id) }
      }
    }
  }

  public func powerUpdates() -> AsyncStream<Power> {
    AsyncStream { continuation in
      let id = UUID()
      self.powerContinuations[id] = continuation
      continuation.onTermination = { [weak self] _ in
        guard let self else { return }
        Task { await self.removePowerContinuation(id) }
      }
    }
  }

  public func realtimeChunks() -> AsyncStream<RealtimeAudioChunk> {
    AsyncStream { continuation in
      let id = UUID()
      self.chunkContinuations[id] = continuation
      continuation.onTermination = { [weak self] _ in
        guard let self else { return }
        Task { await self.removeChunkContinuation(id) }
      }
    }
  }

  private func removeStatusContinuation(_ id: UUID) {
    statusContinuations.removeValue(forKey: id)
  }

  private func removePowerContinuation(_ id: UUID) {
    powerContinuations.removeValue(forKey: id)
  }

  private func removeChunkContinuation(_ id: UUID) {
    chunkContinuations.removeValue(forKey: id)
  }

  // MARK: - Control

  public func start(with saveDirectory: URL? = nil) async throws {
    guard !isRunning else { throw RecorderError.alreadyRunning }

    if let saveDirectory { self.saveDirectory = saveDirectory }
    try createFileDirectory()
    try await ensureRecordPermission()

    let fileURL = makeRecordingURL()
    recordingFileURL = fileURL

    // Initialize engineDriver on MainActor if needed
    if engineDriver == nil {
      engineDriver = await MainActor.run { AudioEngineDriver() }
    }

    guard let driver = engineDriver else {
      throw RecorderError.invalidFormat
    }

    let inputFormat = await driver.currentInputFormat()
    guard AVAudioFormat(settings: format.settings) != nil else {
      throw RecorderError.invalidFormat
    }

    audioFile = try AVAudioFile(
      forWriting: fileURL,
      settings: format.settings,
      commonFormat: inputFormat.commonFormat,
      interleaved: inputFormat.isInterleaved
    )
  
    try await driver.startRecording { [weak self] chunk in
      guard let self else { return }
      Task(priority: .utility) { [weak self] in
        guard let self else { return }
        await self.processIncomingChunk(chunk)
      }
    }

    recordingStartTime = Date()
    currentRecordingTime = 0
    isRunning = true
    emitStatus(.starting)
    startProgressTask()
  }

  public func stop() async {
    guard isRunning else { return }
    isRunning = false
    if let driver = engineDriver {
      await driver.stopRecording()
    }
    await finalizeRecording(sendCompletion: true)
  }

  public func cancel() async {
    guard isRunning else { return }
    isRunning = false
    if let driver = engineDriver {
      await driver.stopRecording()
    }
    if let recordingFileURL {
      try? FileManager.default.removeItem(at: recordingFileURL)
    }
    await finalizeRecording(sendCompletion: false)
    emitStatus(.cancel)
  }

  // MARK: - Chunk Handling

  private func processIncomingChunk(_ chunk: RealtimeAudioChunk) async {
    guard isRunning else { return }
    emitRealtimeChunk(chunk)
    emitPower(from: chunk)
    await writeChunkToFile(chunk)
    await enforceDurationLimitIfNeeded()
  }

  private func writeChunkToFile(_ chunk: RealtimeAudioChunk) async {
    guard
      let audioFile,
      let buffer = chunk.makePCMBuffer()
    else { return }

    do {
      try audioFile.write(from: buffer)
    } catch {
      emitStatus(.failure(error))
      await cancel()
    }
  }

  private func enforceDurationLimitIfNeeded() async {
    guard let start = recordingStartTime else { return }
    let elapsed = Date().timeIntervalSince(start)
    if elapsed >= maxRecordingDuration {
      await stop()
    }
  }

  // MARK: - Progress Tracking

  private func startProgressTask() {
    progressTask?.cancel()
    progressTask = Task { [weak self] in
      guard let self else { return }
      await self.progressLoop()
    }
  }

  private func progressLoop() async {
    while !Task.isCancelled {
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      await updateProgress()
    }
  }

  private func updateProgress() async {
    guard isRunning else { return }
    currentRecordingTime += 1
    emitStatus(.progress(currentRecordingTime))
    if currentRecordingTime >= maxRecordingDuration {
      await stop()
    }
  }

  // MARK: - Finalize

  private func finalizeRecording(sendCompletion: Bool) async {
    progressTask?.cancel()
    progressTask = nil
    let finalURL = recordingFileURL
    recordingStartTime = nil
    currentRecordingTime = 0
    audioFile = nil
    recordingFileURL = nil

    if sendCompletion, let finalURL {
      emitStatus(.completion(saveURL: finalURL))
    }
  }

  private func createFileDirectory() throws {
    if FileManager.default.fileExists(atPath: saveDirectory.path) { return }
    try FileManager.default.createDirectory(
      at: saveDirectory,
      withIntermediateDirectories: true,
      attributes: nil
    )
  }

  private func makeRecordingURL() -> URL {
    let fileName = "recording_\(Int(Date().timeIntervalSince1970)).\(format.rawValue)"
    return saveDirectory.appendingPathComponent(fileName)
  }

  private func ensureRecordPermission() async throws {
    let permission = await MainActor.run { AVAudioSession.sharedInstance().recordPermission }
    switch permission {
    case .granted:
      return
    case .denied:
      throw RecorderError.permissionDenied
    case .undetermined:
      let granted = await withCheckedContinuation { continuation in
        Task { @MainActor in
          AVAudioSession.sharedInstance().requestRecordPermission { granted in
            continuation.resume(returning: granted)
          }
        }
      }
      guard granted else { throw RecorderError.permissionDenied }
    @unknown default:
      throw RecorderError.permissionDenied
    }
  }

  // MARK: - Emit Helpers

  private func emitStatus(_ status: Status) {
    for continuation in statusContinuations.values {
      continuation.yield(status)
    }
  }

  private func emitPower(from chunk: RealtimeAudioChunk) {
    let power = calculatePower(from: chunk)
    for continuation in powerContinuations.values {
      continuation.yield(power)
    }
  }

  private func emitRealtimeChunk(_ chunk: RealtimeAudioChunk) {
    for continuation in chunkContinuations.values {
      continuation.yield(chunk)
    }
  }

  private func calculatePower(from chunk: RealtimeAudioChunk) -> Power {
    let bytesPerSample = chunk.sampleFormat.bytesPerSample
    let totalSamples = chunk.data.count / bytesPerSample
    guard totalSamples > 0 else {
      return Power(average: -160, peak: -160)
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
    return Power(average: averagePower, peak: peakPower)
  }
}

// MARK: - Buffer Helpers

private extension AVAudioPCMBuffer {
  nonisolated func makePCMData() -> (data: Data, format: AudioRecorder.SampleFormat)? {
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
  nonisolated func makePCMBuffer() -> AVAudioPCMBuffer? {
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

// MARK: - Helpers

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

// MARK: - Audio Engine Driver
private final class AudioEngineDriver {
  private let audioEngine = AVAudioEngine()
  private var chunkHandler: (@Sendable (AudioRecorder.RealtimeAudioChunk) -> Void)?

  func currentInputFormat() -> AVAudioFormat {
    audioEngine.inputNode.outputFormat(forBus: 0)
  }
  
//  func startRecording() throws {
//    try configureSession()
//    audioEngine.stop()
//    audioEngine.reset()
//
//    let inputNode = audioEngine.inputNode
//    inputNode.removeTap(onBus: 0)
//
//    let inputFormat = inputNode.outputFormat(forBus: 0)
//
//    // Capture handler locally to avoid accessing @MainActor property from audio realtime thread
//    let capturedHandler = self.chunkHandler
//      
//    inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { buffer, _ in
//      guard
//        let handler = capturedHandler,
//        let chunk = AudioRecorder.makeRealtimeChunk(from: buffer)
//      else { return }
//      handler(chunk)
//    }
//    
//    audioEngine.prepare()
//    try audioEngine.start()
//  }

  func startRecording(
    chunkHandler: @escaping @Sendable (AudioRecorder.RealtimeAudioChunk) -> Void
  ) throws {
    self.chunkHandler = chunkHandler

    try configureSession()

    audioEngine.stop()
    audioEngine.reset()

    let inputNode = audioEngine.inputNode
    inputNode.removeTap(onBus: 0)

    let inputFormat = inputNode.outputFormat(forBus: 0)

    // Capture handler locally to avoid accessing @MainActor property from audio realtime thread
    let capturedHandler = self.chunkHandler
      
    inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { buffer, _ in
      guard
        let handler = capturedHandler,
        let chunk = AudioRecorder.makeRealtimeChunk(from: buffer)
      else { return }
      handler(chunk)
    }
    
    audioEngine.prepare()
    try audioEngine.start()
  }

  func stopRecording() {
    audioEngine.stop()
    audioEngine.inputNode.removeTap(onBus: 0)
    chunkHandler = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func configureSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .playAndRecord,
      mode: .measurement,
      options: [.defaultToSpeaker, .allowBluetoothHFP]
    )
    try session.setActive(true, options: .notifyOthersOnDeactivation)
  }
}
