//
//  ViewController.swift
//  Example-UIKit
//
//  SpeechToTextKit 示例应用 - 使用 Frame 布局
//

import SpeechToTextKit
import UIKit
import UniformTypeIdentifiers

class ViewController: UIViewController {

  // MARK: - Properties

  private let permissionManager = SpeechPermissionManager()
  private let transcriber = SpeechFileTranscriber()
  private var isProcessing = false
  private var currentResult: RecognitionResult?
  private var isFormattedMode = true  // 默认显示格式化文本

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
    setupUI()
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
    scrollView.addSubview(resultContainerView)
    resultContainerView.addSubview(resultTitleLabel)
    resultContainerView.addSubview(textModeControl)
    resultContainerView.addSubview(resultTextView)
    resultContainerView.addSubview(confidenceLabel)
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
