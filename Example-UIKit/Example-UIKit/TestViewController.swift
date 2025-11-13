//
//  TestViewController.swift
//  Example-UIKit
//
//  手动测试用控制器，覆盖：
//  1. 录音完成后的文件转写流程
//  2. 外部 PCM 驱动的实时翻译流程
//

import UIKit
import AVFoundation
import SpeechToTextKit

final class TestViewController: UIViewController {

  // MARK: - Dependencies

  private let permissionManager = SpeechPermissionManager()
  private lazy var fileTranscriber = SpeechFileTranscriber(permissionManager: permissionManager)
  private let fileRecorder = AudioRecorder(format: .m4a)
  private let streamingRecorder = AudioRecorder(format: .m4a)
  private lazy var realtimeTranslator = RealtimeSpeechTranslator(
    config: .chinese,
    permissionManager: permissionManager,
    inputSource: .external
  )

  private var fileStatusTask: Task<Void, Never>?
  private var streamingStatusTask: Task<Void, Never>?
  private var realtimeChunkTask: Task<Void, Never>?
  private var isRecordingForTranscription = false
  private var isRealtimeRunning = false

  // MARK: - UI

  private lazy var scrollView: UIScrollView = {
    let view = UIScrollView()
    view.alwaysBounceVertical = true
    return view
  }()

  private lazy var contentStack: UIStackView = {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 20
    return stack
  }()

  private lazy var recordCardView = makeCardContainer()
  private lazy var realtimeCardView = makeCardContainer()

  private lazy var recordTitleLabel: UILabel = {
    let label = UILabel()
    label.text = "测试一：录音完成后翻译"
    label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
    return label
  }()

  private lazy var recordStatusLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
    label.textColor = .secondaryLabel
    label.numberOfLines = 0
    label.text = "点击下方按钮开始录音；结束后自动触发文件转写"
    return label
  }()

  private lazy var transcriptionStatusLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
    label.textColor = .systemBlue
    label.numberOfLines = 0
    label.text = "等待录音..."
    return label
  }()

  private lazy var transcriptionResultView: UITextView = {
    let view = UITextView()
    view.font = UIFont.systemFont(ofSize: 15)
    view.isEditable = false
    view.layer.cornerRadius = 10
    view.layer.borderColor = UIColor.systemGray4.cgColor
    view.layer.borderWidth = 1
    view.backgroundColor = .systemBackground
    view.textColor = .secondaryLabel
    view.text = "转写结果将显示在这里"
    view.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    return view
  }()

  private lazy var recordButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("开始录音并转写", for: .normal)
    button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    button.backgroundColor = UIColor.systemBlue
    button.setTitleColor(.white, for: .normal)
    button.layer.cornerRadius = 12
    button.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
    return button
  }()

  private lazy var realtimeTitleLabel: UILabel = {
    let label = UILabel()
    label.text = "测试二：实时语音翻译"
    label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
    return label
  }()

  private lazy var realtimeStatusLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
    label.textColor = .secondaryLabel
    label.numberOfLines = 0
    label.text = "启动后通过 AudioRecorder 的 PCM 流驱动 RealtimeSpeechTranslator"
    return label
  }()

  private lazy var realtimeInfoLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
    label.textColor = .secondaryLabel
    label.numberOfLines = 0
    return label
  }()

  private lazy var realtimeResultView: UITextView = {
    let view = UITextView()
    view.font = UIFont.systemFont(ofSize: 15)
    view.isEditable = false
    view.layer.cornerRadius = 10
    view.layer.borderColor = UIColor.systemGray4.cgColor
    view.layer.borderWidth = 1
    view.backgroundColor = .systemBackground
    view.textColor = .secondaryLabel
    view.text = "实时翻译内容将显示在这里"
    view.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    return view
  }()

  private lazy var realtimeButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("开始实时翻译", for: .normal)
    button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    button.backgroundColor = UIColor.systemPink
    button.setTitleColor(.white, for: .normal)
    button.layer.cornerRadius = 12
    button.addTarget(self, action: #selector(realtimeButtonTapped), for: .touchUpInside)
    return button
  }()

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Test Recorder"
    view.backgroundColor = .white
    setupLayout()
    bindRecorders()
    configureRealtimeCallbacks()
  }
  
  deinit {
    fileStatusTask?.cancel()
    streamingStatusTask?.cancel()
    realtimeChunkTask?.cancel()
  }
}

// MARK: - Setup

private extension TestViewController {
  func setupLayout() {
    view.addSubview(scrollView)
    scrollView.translatesAutoresizingMaskIntoConstraints = false

    scrollView.addSubview(contentStack)
    contentStack.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
      contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
      contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
      contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20)
    ])

    setupRecordCard()
    setupRealtimeCard()
  }

  func setupRecordCard() {
    let stack = UIStackView(arrangedSubviews: [
      recordTitleLabel,
      recordStatusLabel,
      recordButton,
      transcriptionStatusLabel,
      transcriptionResultView
    ])
    stack.axis = .vertical
    stack.spacing = 12

    recordCardView.addSubview(stack)
    stack.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      recordButton.heightAnchor.constraint(equalToConstant: 48),
      transcriptionResultView.heightAnchor.constraint(equalToConstant: 150),

      stack.topAnchor.constraint(equalTo: recordCardView.topAnchor, constant: 16),
      stack.leadingAnchor.constraint(equalTo: recordCardView.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: recordCardView.trailingAnchor, constant: -16),
      stack.bottomAnchor.constraint(equalTo: recordCardView.bottomAnchor, constant: -16)
    ])

    contentStack.addArrangedSubview(recordCardView)
  }

  func setupRealtimeCard() {
    let stack = UIStackView(arrangedSubviews: [
      realtimeTitleLabel,
      realtimeStatusLabel,
      realtimeButton,
      realtimeInfoLabel,
      realtimeResultView
    ])
    stack.axis = .vertical
    stack.spacing = 12

    realtimeCardView.addSubview(stack)
    stack.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      realtimeButton.heightAnchor.constraint(equalToConstant: 48),
      realtimeResultView.heightAnchor.constraint(equalToConstant: 150),

      stack.topAnchor.constraint(equalTo: realtimeCardView.topAnchor, constant: 16),
      stack.leadingAnchor.constraint(equalTo: realtimeCardView.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: realtimeCardView.trailingAnchor, constant: -16),
      stack.bottomAnchor.constraint(equalTo: realtimeCardView.bottomAnchor, constant: -16)
    ])

    contentStack.addArrangedSubview(realtimeCardView)
  }

  func bindRecorders() {
    fileStatusTask = Task { [weak self] in
      guard let self else { return }
      let stream = await self.fileRecorder.statusUpdates()
      for await status in stream {
        await MainActor.run {
          self.handleFileRecorderStatus(status)
        }
      }
    }
    
    streamingStatusTask = Task { [weak self] in
      guard let self else { return }
      let stream = await self.streamingRecorder.statusUpdates()
      for await status in stream {
        await MainActor.run {
          self.handleStreamingRecorderStatus(status)
        }
      }
    }
    
    realtimeChunkTask = Task { [weak self] in
      guard let self else { return }
      let stream = await self.streamingRecorder.realtimeChunks()
      for await chunk in stream {
        await MainActor.run {
          self.handleRealtimeChunk(chunk)
        }
      }
    }
  }

  func configureRealtimeCallbacks() {
    realtimeTranslator.onResult = { [weak self] result, isFinal in
      self?.handleRealtimeResult(result: result, isFinal: isFinal)
    }

    realtimeTranslator.onError = { [weak self] error in
      let recognitionError = error as? RecognitionError
        ?? .underlying(message: error.localizedDescription)
      self?.presentRealtimeError(recognitionError)
    }
  }
}

// MARK: - Actions

private extension TestViewController {
  @objc func recordButtonTapped() {
    if isRecordingForTranscription {
      stopFileRecordingTest()
    } else {
      startFileRecordingTest()
    }
  }

  @objc func realtimeButtonTapped() {
    if isRealtimeRunning {
      stopRealtimeTest()
    } else {
      startRealtimeTest()
    }
  }
}

// MARK: - Recording -> Transcription

private extension TestViewController {
  func startFileRecordingTest() {
    transcriptionStatusLabel.textColor = .systemBlue
    transcriptionStatusLabel.text = "录音结束后将自动开始转写..."
    updateTranscriptionResult(text: nil)
    recordStatusLabel.textColor = .systemBlue
    recordStatusLabel.text = "🎙️ 正在准备录音..."

    Task { 
      do {
        try await self.fileRecorder.start()
        await MainActor.run {
          self.isRecordingForTranscription = true
          self.recordButton.setTitle("停止录音并转写", for: .normal)
          self.recordButton.backgroundColor = UIColor.systemGray
          self.recordStatusLabel.textColor = .systemBlue
          self.recordStatusLabel.text = "🎙️ 正在准备录音..."
        }
      } catch {
        await MainActor.run {
          self.isRecordingForTranscription = false
          self.recordStatusLabel.textColor = .systemRed
          self.recordStatusLabel.text = "无法开始录音：\(error.localizedDescription)"
        }
      }
    }
  }

  func stopFileRecordingTest() {
    recordButton.isEnabled = false
    recordStatusLabel.textColor = .secondaryLabel
    recordStatusLabel.text = "正在停止录音..."
    Task { [weak self] in
      guard let self else { return }
      await self.fileRecorder.stop()
    }
  }

  func handleFileRecorderStatus(_ status: AudioRecorder.Status) {
    switch status {
    case .starting:
      recordStatusLabel.text = "🎙️ 正在开始录音..."
    case .progress(let seconds):
      recordStatusLabel.text = "录音时长：\(Int(seconds)) 秒"
    case .completion(let url):
      isRecordingForTranscription = false
      recordButton.isEnabled = true
      recordButton.backgroundColor = UIColor.systemBlue
      recordButton.setTitle("重新录音并转写", for: .normal)
      recordStatusLabel.textColor = .systemGreen
      recordStatusLabel.text = "录音完成，文件：\(url.lastPathComponent)"
      transcribeRecordedFile(at: url)
    case .failure(let error):
      isRecordingForTranscription = false
      recordButton.isEnabled = true
      recordButton.backgroundColor = UIColor.systemBlue
      recordButton.setTitle("开始录音并转写", for: .normal)
      recordStatusLabel.textColor = .systemRed
      recordStatusLabel.text = "录音失败：\(error.localizedDescription)"
    case .cancel:
      isRecordingForTranscription = false
      recordButton.isEnabled = true
      recordButton.backgroundColor = UIColor.systemBlue
      recordButton.setTitle("开始录音并转写", for: .normal)
      recordStatusLabel.textColor = .secondaryLabel
      recordStatusLabel.text = "录音已取消"
    }
  }

  func transcribeRecordedFile(at url: URL) {
    transcriptionStatusLabel.textColor = .systemBlue
    transcriptionStatusLabel.text = "⏳ 正在识别音频..."
    recordButton.isEnabled = false

    Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        let result = try await fileTranscriber.transcribe(
          fileURL: url,
          config: .chinese
        )
        self.updateTranscriptionResult(text: result.formattedText)
        self.transcriptionStatusLabel.textColor = .systemGreen
        self.transcriptionStatusLabel.text = "✅ 转写完成"
      } catch let error as RecognitionError {
        self.transcriptionStatusLabel.textColor = .systemRed
        self.transcriptionStatusLabel.text = "❌ \(error.localizedDescription)"
        self.updateTranscriptionResult(text: nil)
      } catch {
        self.transcriptionStatusLabel.textColor = .systemRed
        self.transcriptionStatusLabel.text = "❌ \(error.localizedDescription)"
        self.updateTranscriptionResult(text: nil)
      }
      self.recordButton.isEnabled = true
    }
  }

  func updateTranscriptionResult(text: String?) {
    if let text, !text.isEmpty {
      transcriptionResultView.text = text
      transcriptionResultView.textColor = .label
    } else {
      transcriptionResultView.text = "转写结果将显示在这里"
      transcriptionResultView.textColor = .secondaryLabel
    }
  }
}

// MARK: - Realtime Translation

private extension TestViewController {
  func startRealtimeTest() {
    realtimeButton.isEnabled = false
    realtimeStatusLabel.textColor = .systemBlue
    realtimeStatusLabel.text = "正在启动实时翻译..."
    updateRealtimeResult(text: nil)
//Task { [weak self] in
//      guard let self else { return }
      do {
         let translator = RealtimeSpeechTranslator(
          config: RecognitionConfig(locale: Locale(identifier: "zh-CN"), taskHint: .dictation),
          permissionManager: permissionManager
        )
        self.realtimeTranslator = translator
        Task {
          try await translator.start()
          try await self.streamingRecorder.start()
        }

        self.isRealtimeRunning = true
        self.realtimeButton.isEnabled = true
        self.realtimeButton.setTitle("停止实时翻译", for: .normal)
        self.realtimeStatusLabel.textColor = .systemGreen
        self.realtimeStatusLabel.text = "🎧 正在录音，开口说话吧"
      } catch let error as RecognitionError {
        self.realtimeButton.isEnabled = true
        self.presentRealtimeError(error)
      } catch {
        self.realtimeButton.isEnabled = true
        self.presentRealtimeError(.underlying(message: error.localizedDescription))
      }
//    }
//    Task { [weak self] in
//      guard let self else { return }
//      do {
//        try await self.realtimeTranslator.start()
//        try await self.streamingRecorder.start()
//
//        self.isRealtimeRunning = true
//        self.realtimeButton.isEnabled = true
//        self.realtimeButton.setTitle("停止实时翻译", for: .normal)
//        self.realtimeStatusLabel.textColor = .systemGreen
//        self.realtimeStatusLabel.text = "🎧 正在录音，开口说话吧"
//      } catch let error as RecognitionError {
//        self.realtimeButton.isEnabled = true
//        self.presentRealtimeError(error)
//      } catch {
//        self.realtimeButton.isEnabled = true
//        self.presentRealtimeError(.underlying(message: error.localizedDescription))
//      }
//    }
  }

  func stopRealtimeTest() {
    Task {
      await streamingRecorder.stop()
    }
    realtimeTranslator.stop()

    isRealtimeRunning = false
    realtimeButton.isEnabled = true
    realtimeButton.setTitle("开始实时翻译", for: .normal)
    realtimeStatusLabel.textColor = .secondaryLabel
    realtimeStatusLabel.text = "实时翻译已停止，点击按钮重新开始"
  }

  func handleStreamingRecorderStatus(_ status: AudioRecorder.Status) {
    switch status {
    case .starting:
      realtimeInfoLabel.text = "🎙️ 正在准备实时录音..."
    case .progress(let seconds):
      realtimeInfoLabel.text = "实时录音时长：\(Int(seconds)) 秒"
    case .completion(let url):
      realtimeInfoLabel.text = "实时录音已保存：\(url.lastPathComponent)"
    case .failure(let error):
      realtimeInfoLabel.text = "录音失败：\(error.localizedDescription)"
      stopRealtimeTest()
    case .cancel:
      realtimeInfoLabel.text = "实时录音已取消"
    }
  }

  func handleRealtimeChunk(_ chunk: AudioRecorder.RealtimeAudioChunk) {
    guard isRealtimeRunning, let buffer = chunk.makePCMBuffer() else { return }
    realtimeTranslator.appendExternalBuffer(buffer)
  }

  func handleRealtimeResult(result: RecognitionResult, isFinal: Bool) {
    let text = isFinal ? result.formattedText : result.text
    updateRealtimeResult(text: text)
    realtimeStatusLabel.textColor = .systemBlue
    realtimeStatusLabel.text = isFinal ? "✅ 已识别一句，可继续讲话" : "🎧 正在识别..."
  }

  func presentRealtimeError(_ error: RecognitionError) {
    stopRealtimeTest()
    realtimeStatusLabel.textColor = .systemRed
    realtimeStatusLabel.text = "❌ \(error.localizedDescription)"
  }

  func updateRealtimeResult(text: String?) {
    if let text, !text.isEmpty {
      realtimeResultView.text = text
      realtimeResultView.textColor = .label
    } else {
      realtimeResultView.text = "实时翻译内容将显示在这里"
      realtimeResultView.textColor = .secondaryLabel
    }
  }
}

// MARK: - Helpers

private extension TestViewController {
  func makeCardContainer() -> UIView {
    let view = UIView()
    view.backgroundColor = .secondarySystemBackground
    view.layer.cornerRadius = 16
    view.layer.borderColor = UIColor.systemGray5.cgColor
    view.layer.borderWidth = 1
    return view
  }
}
