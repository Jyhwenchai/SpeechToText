//
//  ViewController.swift
//  Example-UIKit
//
//  SpeechToTextKit 示例应用 - 使用 Frame 布局
//

import AVFoundation
import Combine
import SpeechToTextKit
import UIKit
import UniformTypeIdentifiers

class ViewController: UIViewController {

  // MARK: - Properties

  private let permissionManager = SpeechPermissionManager()
  private let transcriber = SpeechFileTranscriber()
  private let audioRecorder = AudioRecorder(format: .m4a)
  private lazy var realtimeTranslator = RealtimeSpeechTranslator(
    config: .chinese,
    permissionManager: permissionManager,
    inputSource: .external
  )
  
  private var realtimeChunkCancellable: AnyCancellable?
  private var realtimeStatusCancellable: AnyCancellable?
  
  private var isProcessing = false
  private var currentResult: RecognitionResult?
  private var isFormattedMode = true  // 默认显示格式化文本
  private var isRealtimeRunning = false
  private var realtimeText: String = ""

  // MARK: - UI Components

  private lazy var scrollView: UIScrollView = {
    let scrollView = UIScrollView()
    scrollView.showsVerticalScrollIndicator = true
    scrollView.alwaysBounceVertical = true
    return scrollView
  }()

  private lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.text = "SpeechToTextKit 示例"
    label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
    label.textAlignment = .center
    return label
  }()

  private lazy var subtitleLabel: UILabel = {
    let label = UILabel()
    label.text = "选择音频文件并转换为文本"
    label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
    label.textColor = .secondaryLabel
    label.textAlignment = .center
    label.numberOfLines = 0
    return label
  }()

  private lazy var permissionStatusView: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor.systemGray6
    view.layer.cornerRadius = 12
    return view
  }()

  private lazy var permissionStatusLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
    label.textAlignment = .center
    label.numberOfLines = 0
    return label
  }()

  private lazy var requestPermissionButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("请求权限", for: .normal)
    button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    button.backgroundColor = UIColor.systemBlue
    button.setTitleColor(.white, for: .normal)
    button.layer.cornerRadius = 12
    button.addTarget(
      self,
      action: #selector(requestPermissionTapped),
      for: .touchUpInside
    )
    return button
  }()

  private lazy var selectFileButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("选择音频文件", for: .normal)
    button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
    button.backgroundColor = UIColor.systemGreen
    button.setTitleColor(.white, for: .normal)
    button.layer.cornerRadius = 12
    button.addTarget(
      self,
      action: #selector(selectFileTapped),
      for: .touchUpInside
    )
    button.isEnabled = false
    return button
  }()

  private lazy var activityIndicator: UIActivityIndicatorView = {
    let indicator = UIActivityIndicatorView(style: .large)
    indicator.hidesWhenStopped = true
    indicator.color = .systemBlue
    return indicator
  }()

  private lazy var statusLabel: UILabel = {
    let label = UILabel()
    label.text = ""
    label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
    label.textColor = .systemBlue
    label.textAlignment = .center
    label.numberOfLines = 0
    return label
  }()

  private lazy var resultContainerView: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor.systemBackground
    view.layer.cornerRadius = 12
    view.layer.borderWidth = 1
    view.layer.borderColor = UIColor.systemGray4.cgColor
    view.isHidden = true
    return view
  }()

  private lazy var realtimeContainerView: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor.systemGray6
    view.layer.cornerRadius = 12
    view.layer.borderColor = UIColor.systemGray4.cgColor
    view.layer.borderWidth = 1
    return view
  }()

  private lazy var realtimeTitleLabel: UILabel = {
    let label = UILabel()
    label.text = "实时语音翻译（麦克风）"
    label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
    return label
  }()

  private lazy var realtimeStatusLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
    label.textColor = .secondaryLabel
    label.numberOfLines = 0
    label.text = "点击下方按钮开始录音并实时翻译"
    return label
  }()

  private lazy var realtimeRecordingLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
    label.textColor = .secondaryLabel
    label.text = ""
    return label
  }()

  private lazy var realtimeToggleButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("开始实时翻译", for: .normal)
    button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    button.backgroundColor = UIColor.systemPink
    button.setTitleColor(.white, for: .normal)
    button.layer.cornerRadius = 10
    button.addTarget(self, action: #selector(realtimeButtonTapped), for: .touchUpInside)
    return button
  }()

  private lazy var realtimeTextView: UITextView = {
    let textView = UITextView()
    textView.font = UIFont.systemFont(ofSize: 15, weight: .regular)
    textView.textColor = .secondaryLabel
    textView.backgroundColor = UIColor.systemBackground
    textView.layer.cornerRadius = 10
    textView.text = "实时识别结果将在此显示"
    textView.isEditable = false
    textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    return textView
  }()

  private lazy var resultTitleLabel: UILabel = {
    let label = UILabel()
    label.text = "识别结果："
    label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    return label
  }()

  private lazy var textModeControl: UISegmentedControl = {
    let control = UISegmentedControl(items: ["原始", "格式化"])
    control.selectedSegmentIndex = 1  // 默认选中格式化
    control.addTarget(
      self,
      action: #selector(textModeChanged),
      for: .valueChanged
    )
    return control
  }()

  private lazy var resultTextView: UITextView = {
    let textView = UITextView()
    textView.font = UIFont.systemFont(ofSize: 16, weight: .regular)
    textView.textColor = .label
    textView.backgroundColor = UIColor.systemGray6
    textView.layer.cornerRadius = 8
    textView.textContainerInset = UIEdgeInsets(
      top: 12,
      left: 12,
      bottom: 12,
      right: 12
    )
    textView.isEditable = false
    return textView
  }()

  private lazy var confidenceLabel: UILabel = {
    let label = UILabel()
    label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
    label.textColor = .secondaryLabel
    label.text = ""
    return label
  }()

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.title = "SpeechToTextKit"
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: "测试面板",
      style: .plain,
      target: self,
      action: #selector(openTestController)
    )
    setupUI()
    configureRealtimeDemo()
    updatePermissionStatus()
    Task {
      guard
        let audioURL = Bundle.main.url(
          forResource: "test",
          withExtension: "m4a"
        )
      else {
        print("❌ 找不到文件")
        return
      }

//      // 使用诗词模式
//      let config = RecognitionConfig(
//        locale: Locale(identifier: "zh-CN"),
//        punctuationRecovery: .poetry
//      )
//
//      let transcriber = SpeechFileTranscriber()
//      let result = try await transcriber.transcribe(
//        fileURL: audioURL,
//        config: config
//      )
//
//      print("识别结果: \(result.formattedText)")
//      
      
      let config = RecognitionConfig(
        locale: Locale(identifier: "zh-CN"),
        punctuationRecovery: .poetry  // 或 .semanticOnly
      )
      let result = try await transcriber.transcribe(fileURL: audioURL, config: config)
      print(result.formattedText)
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    layoutViews()
  }

  // MARK: - UI Setup

  private func setupUI() {
    view.backgroundColor = .systemBackground

    // Add subviews
    view.addSubview(scrollView)
    scrollView.addSubview(titleLabel)
    scrollView.addSubview(subtitleLabel)
    scrollView.addSubview(permissionStatusView)
    permissionStatusView.addSubview(permissionStatusLabel)
    scrollView.addSubview(requestPermissionButton)
    scrollView.addSubview(selectFileButton)
    scrollView.addSubview(activityIndicator)
    scrollView.addSubview(statusLabel)
    scrollView.addSubview(realtimeContainerView)
    scrollView.addSubview(resultContainerView)
    resultContainerView.addSubview(resultTitleLabel)
    resultContainerView.addSubview(textModeControl)
    resultContainerView.addSubview(resultTextView)
    resultContainerView.addSubview(confidenceLabel)
    realtimeContainerView.addSubview(realtimeTitleLabel)
    realtimeContainerView.addSubview(realtimeStatusLabel)
    realtimeContainerView.addSubview(realtimeRecordingLabel)
    realtimeContainerView.addSubview(realtimeToggleButton)
    realtimeContainerView.addSubview(realtimeTextView)
  }
  
  private func configureRealtimeDemo() {
    realtimeTranslator.onResult = { [weak self] result, isFinal in
      self?.handleRealtimeResult(result: result, isFinal: isFinal)
    }
    
    realtimeTranslator.onError = { [weak self] error in
      let recognitionError = error as? RecognitionError
        ?? .underlying(message: error.localizedDescription)
      self?.presentRealtimeError(recognitionError)
    }
    
    realtimeStatusCancellable = audioRecorder.statusChangedPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] status in
        self?.handleRecorderStatus(status)
      }
    
    updateRealtimeUI(status: "点击下方按钮开始录音并实时翻译")
  }

  private func layoutViews() {
    let bounds = view.bounds
    let safeArea = view.safeAreaInsets
    let width = bounds.width
    let padding: CGFloat = 20
    let contentWidth = width - padding * 2

    // ScrollView
    scrollView.frame = CGRect(
      x: 0,
      y: safeArea.top,
      width: width,
      height: bounds.height - safeArea.top - safeArea.bottom
    )

    var yOffset: CGFloat = 30

    // Title Label
    let titleHeight: CGFloat = 35
    titleLabel.frame = CGRect(
      x: padding,
      y: yOffset,
      width: contentWidth,
      height: titleHeight
    )
    yOffset += titleHeight + 8

    // Subtitle Label
    let subtitleHeight = subtitleLabel.sizeThatFits(
      CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
    ).height
    subtitleLabel.frame = CGRect(
      x: padding,
      y: yOffset,
      width: contentWidth,
      height: subtitleHeight
    )
    yOffset += subtitleHeight + 30

    // Permission Status View
    let statusLabelSize = permissionStatusLabel.sizeThatFits(
      CGSize(width: contentWidth - 32, height: .greatestFiniteMagnitude)
    )
    let permissionStatusHeight = max(60, statusLabelSize.height + 24)
    permissionStatusView.frame = CGRect(
      x: padding,
      y: yOffset,
      width: contentWidth,
      height: permissionStatusHeight
    )

    // Permission Status Label (inside status view)
    permissionStatusLabel.frame = CGRect(
      x: 16,
      y: 12,
      width: contentWidth - 32,
      height: permissionStatusHeight - 24
    )
    yOffset += permissionStatusHeight + 16

    // Request Permission Button
    if !requestPermissionButton.isHidden {
      requestPermissionButton.frame = CGRect(
        x: padding,
        y: yOffset,
        width: contentWidth,
        height: 50
      )
      yOffset += 50 + 20
    }

    // Select File Button
    selectFileButton.frame = CGRect(
      x: padding,
      y: yOffset,
      width: contentWidth,
      height: 56
    )
    yOffset += 56 + 20

    // Activity Indicator
    let indicatorSize: CGFloat = 44
    activityIndicator.frame = CGRect(
      x: (width - indicatorSize) / 2,
      y: yOffset,
      width: indicatorSize,
      height: indicatorSize
    )
    yOffset += indicatorSize + 12

    // Status Label
    let statusTextSize = statusLabel.sizeThatFits(
      CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
    )
    statusLabel.frame = CGRect(
      x: padding,
      y: yOffset,
      width: contentWidth,
      height: max(20, statusTextSize.height)
    )
    yOffset += max(20, statusTextSize.height) + 20
    
    // Realtime Demo Container
    let realtimeStatusSize = realtimeStatusLabel.sizeThatFits(
      CGSize(width: contentWidth - 32, height: .greatestFiniteMagnitude)
    )
    let realtimeRecordingSize = realtimeRecordingLabel.sizeThatFits(
      CGSize(width: contentWidth - 32, height: .greatestFiniteMagnitude)
    )
    let realtimeTextHeight: CGFloat = 150
    let realtimeContainerHeight =
      16 + 24 + 12 + 44 + 12
      + realtimeStatusSize.height
      + 4 + max(18, realtimeRecordingSize.height)
      + 12 + realtimeTextHeight + 16
    
    realtimeContainerView.frame = CGRect(
      x: padding,
      y: yOffset,
      width: contentWidth,
      height: realtimeContainerHeight
    )
    
    realtimeTitleLabel.frame = CGRect(
      x: 16,
      y: 16,
      width: contentWidth - 32,
      height: 24
    )
    
    realtimeToggleButton.frame = CGRect(
      x: 16,
      y: realtimeTitleLabel.frame.maxY + 12,
      width: contentWidth - 32,
      height: 44
    )
    
    realtimeStatusLabel.frame = CGRect(
      x: 16,
      y: realtimeToggleButton.frame.maxY + 12,
      width: contentWidth - 32,
      height: realtimeStatusSize.height
    )
    
    realtimeRecordingLabel.frame = CGRect(
      x: 16,
      y: realtimeStatusLabel.frame.maxY + 4,
      width: contentWidth - 32,
      height: max(18, realtimeRecordingSize.height)
    )
    
    realtimeTextView.frame = CGRect(
      x: 16,
      y: realtimeRecordingLabel.frame.maxY + 12,
      width: contentWidth - 32,
      height: realtimeTextHeight
    )
    
    yOffset += realtimeContainerHeight + 20

    // Result Container View
    if !resultContainerView.isHidden {
      let resultTextHeight: CGFloat = 180
      let controlHeight: CGFloat = 32
      let resultContainerHeight =
        16 + 22 + 8 + controlHeight + 12 + resultTextHeight + 12 + 20 + 16

      resultContainerView.frame = CGRect(
        x: padding,
        y: yOffset,
        width: contentWidth,
        height: resultContainerHeight
      )

      // Result Title Label
      resultTitleLabel.frame = CGRect(
        x: 16,
        y: 16,
        width: contentWidth - 32,
        height: 22
      )

      // Text Mode Control
      textModeControl.frame = CGRect(
        x: 16,
        y: 16 + 22 + 8,
        width: contentWidth - 32,
        height: controlHeight
      )

      // Result TextView
      resultTextView.frame = CGRect(
        x: 16,
        y: 16 + 22 + 8 + controlHeight + 12,
        width: contentWidth - 32,
        height: resultTextHeight
      )

      // Confidence Label
      confidenceLabel.frame = CGRect(
        x: 16,
        y: 16 + 22 + 8 + controlHeight + 12 + resultTextHeight + 12,
        width: contentWidth - 32,
        height: 20
      )

      yOffset += resultContainerHeight + 20
    }

    // Update ScrollView content size
    scrollView.contentSize = CGSize(width: width, height: yOffset)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    stopRealtimeTranslation()
    realtimeStatusCancellable?.cancel()
    realtimeStatusCancellable = nil
  }

  // MARK: - Permission Management

  private func updatePermissionStatus() {
    Task {
      let status = await permissionManager.status()
      await MainActor.run {
        updateUI(for: status)
      }
    }
  }

  private func updateUI(for status: SpeechPermissionStatus) {
    switch status {
    case .notDetermined:
      permissionStatusLabel.text = "⚠️ 权限状态：未确定\n请点击下方按钮请求权限"
      permissionStatusLabel.textColor = .systemOrange
      requestPermissionButton.isHidden = false
      selectFileButton.isEnabled = false

    case .denied:
      permissionStatusLabel.text = "❌ 权限状态：已拒绝\n请在系统设置中开启语音识别权限"
      permissionStatusLabel.textColor = .systemRed
      requestPermissionButton.isHidden = true
      selectFileButton.isEnabled = false

    case .restricted:
      permissionStatusLabel.text = "🚫 权限状态：受限制\n设备可能启用了家长控制"
      permissionStatusLabel.textColor = .systemRed
      requestPermissionButton.isHidden = true
      selectFileButton.isEnabled = false

    case .authorized:
      permissionStatusLabel.text = "✅ 权限状态：已授权\n您可以开始使用语音识别功能"
      permissionStatusLabel.textColor = .systemGreen
      requestPermissionButton.isHidden = true
      selectFileButton.isEnabled = true
    }

    view.setNeedsLayout()
  }

  @objc private func requestPermissionTapped() {
    Task {
      let status = await permissionManager.request()
      await MainActor.run {
        updateUI(for: status)
      }
    }
  }
  
  @objc private func openTestController() {
    let controller = TestViewController()
    navigationController?.pushViewController(controller, animated: true)
  }

  // MARK: - File Selection

  @objc private func textModeChanged() {
    isFormattedMode = textModeControl.selectedSegmentIndex == 1
    updateDisplayedText()
  }

  @objc private func selectFileTapped() {
    guard !isProcessing else { return }

    let documentPicker: UIDocumentPickerViewController

    if #available(iOS 14.0, *) {
      documentPicker = UIDocumentPickerViewController(
        forOpeningContentTypes: [UTType.audio, UTType.movie]
      )
    } else {
      documentPicker = UIDocumentPickerViewController(
        documentTypes: ["public.audio", "public.movie"],
        in: .import
      )
    }

    documentPicker.delegate = self
    documentPicker.allowsMultipleSelection = false
    documentPicker.modalPresentationStyle = .formSheet

    present(documentPicker, animated: true)
  }
  
  @objc private func realtimeButtonTapped() {
    if isRealtimeRunning {
      stopRealtimeTranslation()
    } else {
      startRealtimeTranslation()
    }
  }

  // MARK: - Transcription

  private func transcribeAudio(fileURL: URL) {
    guard !isProcessing else { return }

    isProcessing = true
    resultContainerView.isHidden = true
    activityIndicator.startAnimating()
    statusLabel.text = "正在识别音频..."
    selectFileButton.isEnabled = false

    view.setNeedsLayout()

    Task {
      do {
        // 使用中文配置
        let config = RecognitionConfig.chinese

        let result = try await transcriber.transcribe(
          fileURL: fileURL,
          config: config
        )

        await MainActor.run {
          displayResult(result)
        }

      } catch let error as RecognitionError {
        await MainActor.run {
          displayError(error)
        }

      } catch {
        await MainActor.run {
          displayError(.underlying(message: error.localizedDescription))
        }
      }

      await MainActor.run {
        isProcessing = false
        activityIndicator.stopAnimating()
        selectFileButton.isEnabled = true
        view.setNeedsLayout()
      }
    }
  }

  private func displayResult(_ result: RecognitionResult) {
    currentResult = result
    statusLabel.text = "✅ 识别完成！"
    statusLabel.textColor = .systemGreen

    updateDisplayedText()

    if let confidence = result.confidence {
      let percentage = String(format: "%.1f%%", confidence * 100)
      confidenceLabel.text = "🎯 置信度：\(percentage)"
    } else {
      confidenceLabel.text = ""
    }

    resultContainerView.isHidden = false
    view.setNeedsLayout()

    // 滚动到结果区域
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      guard let self = self else { return }
      let bottomOffset = CGPoint(
        x: 0,
        y: max(
          0,
          self.scrollView.contentSize.height - self.scrollView.bounds.height
        )
      )
      self.scrollView.setContentOffset(bottomOffset, animated: true)
    }
  }

  private func displayError(_ error: RecognitionError) {
    statusLabel.text = "❌ \(error.localizedDescription)"
    statusLabel.textColor = .systemRed

    resultContainerView.isHidden = true
    view.setNeedsLayout()

    // 显示详细错误信息
    let alert = UIAlertController(
      title: "识别失败",
      message: error.localizedDescription
        + (error.recoverySuggestion.map { "\n\n\($0)" } ?? ""),
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "确定", style: .default))
    present(alert, animated: true)
  }

  // MARK: - Realtime Translation
  
  private func startRealtimeTranslation() {
    guard !isRealtimeRunning else { return }
    realtimeToggleButton.isEnabled = false
    realtimeText = ""
    realtimeRecordingLabel.text = ""
    updateRealtimeUI(status: "正在启动实时翻译...", textColor: .systemBlue)
    
    Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        try await realtimeTranslator.start()
        
        realtimeChunkCancellable?.cancel()
        realtimeChunkCancellable = audioRecorder.realtimeChunkPublisher
          .receive(on: DispatchQueue.main)
          .sink { [weak self] chunk in
            self?.handleRealtimeChunk(chunk)
          }
        
        try audioRecorder.start()
        
        self.isRealtimeRunning = true
        self.realtimeToggleButton.isEnabled = true
        self.updateRealtimeUI(status: "🎙️ 正在录音，开口说话吧！", textColor: .systemGreen)
      } catch let error as RecognitionError {
        self.realtimeToggleButton.isEnabled = true
        self.realtimeTranslator.stop()
        self.presentRealtimeError(error)
      } catch {
        self.realtimeToggleButton.isEnabled = true
        self.realtimeTranslator.stop()
        self.presentRealtimeError(.underlying(message: error.localizedDescription))
      }
    }
  }
  
  private func stopRealtimeTranslation() {
    audioRecorder.stop()
    realtimeTranslator.stop()
    realtimeChunkCancellable?.cancel()
    realtimeChunkCancellable = nil
    isRealtimeRunning = false
    updateRealtimeUI(status: "已停止，点击开始重新录音", textColor: .secondaryLabel)
  }
  
  private func handleRealtimeChunk(_ chunk: AudioRecorder.RealtimeAudioChunk) {
    guard let buffer = chunk.makePCMBuffer() else { return }
    realtimeTranslator.appendExternalBuffer(buffer)
  }
  
  private func handleRealtimeResult(result: RecognitionResult, isFinal: Bool) {
    realtimeText = isFinal ? result.formattedText : result.text
    let statusText = isFinal ? "✅ 已识别一句，可继续讲话" : "🎧 正在识别..."
    updateRealtimeUI(status: statusText, textColor: .systemBlue)
  }
  
  private func handleRecorderStatus(_ status: AudioRecorder.Status) {
    switch status {
    case .starting:
      realtimeRecordingLabel.text = "🎤 正在准备录音..."
    case .progress(let seconds):
      realtimeRecordingLabel.text = "录音长度：\(Int(seconds)) 秒"
    case .completion(let url):
      realtimeRecordingLabel.text = "已保存：\(url.lastPathComponent)"
    case .failure(let error):
      realtimeRecordingLabel.text = "录音失败：\(error.localizedDescription)"
      stopRealtimeTranslation()
    case .cancel:
      realtimeRecordingLabel.text = "录音已取消"
    }
    view.setNeedsLayout()
  }
  
  private func presentRealtimeError(_ error: RecognitionError) {
    stopRealtimeTranslation()
    realtimeStatusLabel.textColor = .systemRed
    realtimeStatusLabel.text = "❌ \(error.localizedDescription)"
    
    let message = error.localizedDescription
      + (error.recoverySuggestion.map { "\n\n\($0)" } ?? "")
    let alert = UIAlertController(
      title: "实时翻译失败",
      message: message,
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "确定", style: .default))
    present(alert, animated: true)
  }
  
  private func updateRealtimeUI(status: String? = nil, textColor: UIColor? = nil) {
    if let status {
      realtimeStatusLabel.text = status
    }
    if let textColor {
      realtimeStatusLabel.textColor = textColor
    } else {
      realtimeStatusLabel.textColor = isRealtimeRunning ? .systemGreen : .secondaryLabel
    }
    
    realtimeToggleButton.setTitle(
      isRealtimeRunning ? "停止实时翻译" : "开始实时翻译",
      for: .normal
    )
    
    if realtimeText.isEmpty {
      realtimeTextView.text = "实时识别结果将在此显示"
      realtimeTextView.textColor = .secondaryLabel
    } else {
      realtimeTextView.text = realtimeText
      realtimeTextView.textColor = .label
    }
    
    view.setNeedsLayout()
  }

  private func updateDisplayedText() {
    guard let result = currentResult else { return }
    resultTextView.text = isFormattedMode ? result.formattedText : result.text
  }
}

// MARK: - UIDocumentPickerDelegate

extension ViewController: UIDocumentPickerDelegate {
  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let fileURL = urls.first else { return }

    // 获取访问权限
    guard fileURL.startAccessingSecurityScopedResource() else {
      statusLabel.text = "❌ 无法访问文件"
      statusLabel.textColor = .systemRed
      return
    }

    defer {
      fileURL.stopAccessingSecurityScopedResource()
    }

    // 复制文件到临时目录
    let temporaryDirectoryURL = FileManager.default.temporaryDirectory
    let temporaryFileURL =
      temporaryDirectoryURL
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension(fileURL.pathExtension)

    do {
      if FileManager.default.fileExists(atPath: temporaryFileURL.path) {
        try FileManager.default.removeItem(at: temporaryFileURL)
      }
      try FileManager.default.copyItem(at: fileURL, to: temporaryFileURL)

      transcribeAudio(fileURL: temporaryFileURL)

    } catch {
      statusLabel.text = "❌ 文件复制失败：\(error.localizedDescription)"
      statusLabel.textColor = .systemRed
      view.setNeedsLayout()
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController)
  {
    statusLabel.text = ""
    view.setNeedsLayout()
  }
}
