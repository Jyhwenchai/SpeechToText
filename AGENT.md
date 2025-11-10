# AGENT 指南

## 项目概览
SpeechToTextKit 是一个基于 Apple Speech Framework 的轻量级 Swift Package，主打离线可选、异步语音转写与中文标点恢复能力。最低支持 iOS 13，要求 Swift 5.9 与 Xcode 15。仓库内包含 UIKit 示例 (`Example-UIKit`) 以及完整的包源代码（`Sources/SpeechToTextKit`）。

## 目录速览
- `Sources/SpeechToTextKit/Core`：文件转写（`SpeechFileTranscriber`）、实时转写（`RealtimeSpeechTranslator`）以及 Speech 辅助方法。
- `Sources/SpeechToTextKit/Permission`：`SpeechPermissionManager` 及权限状态映射。
- `Sources/SpeechToTextKit/Models`：`RecognitionConfig`、`RecognitionResult`、`RecognitionSegment` 等数据结构。
- `Sources/SpeechToTextKit/Utilities`：标点恢复、语言偏好及辅助方法。
- `Example-UIKit`：示例工程，可直接运行体验。

## 关键特性
- 支持本地音频文件转文本，覆盖 `.m4a/.wav/.mp3/.aiff` 等 Core Audio 格式。
- 新增实时语音翻译：`RealtimeSpeechTranslator` 既可直接采集麦克风，也可接收自定义录音器的 PCM 流，支持部分/最终结果回调。
- async/await 并发 API，Swift 6 环境下经过 Actor 隔离加固。
- 自带中文配置 (`RecognitionConfig.chinese`)、智能标点恢复以及诗词断句策略。
- 细粒度结果：原始文本、标点文本、置信度、分段信息、语言 locale。
- 多语言与离线识别（`requiresOnDeviceRecognition = true`）开关。
- 全面错误定义（`RecognitionError`）与恢复建议。

## 集成方式
1. **SPM（Xcode GUI）**：`File → Add Package Dependencies...`，填入 `https://github.com/yourusername/SpeechToTextKit.git`。
2. **SPM（Package.swift）**：
   ```swift
   dependencies: [
       .package(url: "https://github.com/yourusername/SpeechToTextKit.git", from: "1.0.0")
   ],
   targets: [
       .target(
           name: "YourTarget",
           dependencies: ["SpeechToTextKit"]
       )
   ]
   ```
3. **本地调试**：`dependencies: [.package(path: "../SpeechToTextKit")]`。

## 必备配置
- `Info.plist` 中声明 `NSSpeechRecognitionUsageDescription`，说明用途（示例：`语音识别用于将音频文件转换为文本`）。
- 若使用实时语音翻译，还需 `NSMicrophoneUsageDescription`（示例：`需要访问麦克风以实时识别语音`）。文件转写场景可不请求麦克风。

## 核心使用流程
1. 创建 `SpeechPermissionManager` 与 `SpeechFileTranscriber`。
2. `await permissionManager.request()` 获取授权，并校验 `status == .authorized`。
3. 按需构造 `RecognitionConfig`（可使用 `RecognitionConfig()` 默认值或 `.chinese` 预设）。
4. 使用 `try await transcriber.transcribe(fileURL:config:)`。
5. 读取 `result.formattedText`（带标点）或 `result.text`（原始），并根据 `result.confidence`、`result.segments` 做 UI 展示。

> 建议提前校验文件存在性、格式及 locale；长音频需预切片后批量调用。

### 实时语音翻译
- `RealtimeSpeechTranslator`（仅 iOS）提供两种输入模式：
  - `.microphone`（默认）：内部使用 AVAudioEngine 采集麦克风。
  - `.external`：由调用方提供 `AVAudioPCMBuffer`，适合与自定义录音器（如 `AudioRecorder`）联动。
- 麦克风模式示例：
  ```swift
  @MainActor
  final class LiveHandler {
      private lazy var translator = RealtimeSpeechTranslator(
          config: .chinese,
          inputSource: .microphone
      )
      
      init() {
          translator.onResult = { result, isFinal in
              print("RT:", result.text, isFinal ? "✅" : "⏳")
          }
      }
      
      func start() {
          Task { try? await translator.start() }
      }
      
      func stop() {
          translator.stop()
      }
  }
  ```
- 外部 PCM 模式示例（参见 `Example-UIKit/Example-UIKit/ViewController.swift` 获取完整 UI）：
  ```swift
  private let recorder = AudioRecorder()
  private lazy var translator = RealtimeSpeechTranslator(
      config: .chinese,
      inputSource: .external
  )
  private var cancellable: AnyCancellable?

  func startLive() {
      translator.onResult = { print($0.formattedText) }
      Task {
          try await translator.start()
          cancellable = recorder.realtimeChunkPublisher
              .compactMap { $0.makePCMBuffer() }
              .sink { [weak translator] buffer in
                  translator?.appendExternalBuffer(buffer)
              }
          try recorder.start()
      }
  }
  ```
- 启动前需确保语音识别与麦克风权限均在 `Info.plist` 中声明，并根据模式处理权限申请。

## 错误与排障
- `notDetermined/denied/restricted`：缺权限，提示用户或跳转系统设置。
- `notAvailable`：Speech 服务不可用，建议检查网络或稍后重试。
- `localeUnsupported`：确认 `RecognitionConfig` 的 `locale` 与音频一致。
- `fileNotFound/invalidFile`：确认 URL & 音频格式。
- `underlying(String)`：打印 message 便于定位。

## 性能与限制
- 建议每次仅执行一个转写任务，避免并发阻塞。
- 本地识别受系统模型限制，准确率低于在线。
- 为保证准确率，保持音频清晰、噪音低，并选择匹配的语言配置。
- 单文件建议控制在 1 分钟左右（1–2 MB），长音频拆分处理。

## 示例运行
```bash
cd SpeechToText
open Example-UIKit/Example-UIKit.xcodeproj
```
在示例工程中替换音频文件路径即可体验文件转写；首页也提供“实时语音翻译”区块，可直接测试录音 + 实时识别流程。

## 常见问题速查
- **识别失败或空文本**：检查文件、权限、网络与 locale。
- **权限被拒绝**：确认 `Info.plist` 描述并提示用户手动开启。
- **服务不可用**：确认 iOS 版本 ≥13、网络正常，稍后再试。

## 进一步工作
- 查看 `Docs/`、`test_audio.md` 获取更详细的测试用例。
- 利用 `Tests/` 目录补充单元测试，确保新增特性覆盖核心 API。

本 AGENT 文档归纳自 README 与代码结构，可作为快速上手与沟通依据。若 README 更新，请同步调整此文件。 
