# SpeechToTextKit

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2013.0+-blue.svg)](https://developer.apple.com/ios/)
[![SPM](https://img.shields.io/badge/SPM-compatible-green.svg)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**SpeechToTextKit** 是一个基于 iOS Speech Framework 的轻量级语音转文本 Swift Package，提供简洁易用的 API 将音频文件转换为文本。

> **最新更新** (2025-01-09): 修复了 Swift 6 并发安全问题，所有并发访问现在完全在 Actor 隔离环境中进行。

## ✨ 特性

- ✅ **音频文件转文本**：支持将本地音频文件转换为文本
- ✅ **智能标点恢复**：基于 NLLanguage 语义分析和停顿时长智能添加标点符号
- ✅ **诗词断句支持**：专门为古诗词、现代诗优化的断句策略
- ✅ **权限管理**：自动处理语音识别权限申请
- ✅ **多语言支持**：支持中文、英文等多种语言识别
- ✅ **完善的错误处理**：提供详细的错误类型和恢复建议
- ✅ **async/await**：使用现代 Swift 并发 API
- ✅ **离线识别**：可选的设备本地识别支持
- ✅ **详细结果**：包含置信度和文本片段信息

## 📋 要求

- iOS 13.0+
- Swift 5.9+
- Xcode 15.0+

## 📦 安装

### Swift Package Manager

#### 方式一：Xcode 集成

1. 在 Xcode 中打开您的项目
2. 选择 `File` → `Add Package Dependencies...`
3. 输入仓库 URL：`https://github.com/yourusername/SpeechToTextKit.git`
4. 选择版本规则并添加

#### 方式二：Package.swift

在 `Package.swift` 文件中添加依赖：

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

#### 方式三：本地开发

```swift
dependencies: [
    .package(path: "../SpeechToTextKit")
]
```

## ⚙️ 配置

### Info.plist 权限配置

在您的应用的 `Info.plist` 文件中添加语音识别权限说明：

```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>语音识别用于将音频文件转换为文本</string>
```

或使用 Swift 代码风格（在 Info.plist 文件右键 → Open As → Source Code）：

```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>需要访问语音识别功能以将您的音频转换为文本</string>
```

> **注意**：此库仅需要语音识别权限，不需要麦克风权限（因为仅处理音频文件）

## 🚀 使用方法

### 基本用法

```swift
import SpeechToTextKit

// 1. 创建权限管理器和转写器
let permissionManager = SpeechPermissionManager()
let transcriber = SpeechFileTranscriber()

// 2. 请求权限
let status = await permissionManager.request()

guard status == .authorized else {
    print("语音识别权限未授权")
    return
}

// 3. 配置识别参数（使用默认配置）
let config = RecognitionConfig()

// 4. 转换音频文件
do {
    let audioURL = URL(fileURLWithPath: "path/to/audio.m4a")
    let result = try await transcriber.transcribe(
        fileURL: audioURL,
        config: config
    )
    
    print("识别文本：\(result.text)")
    if let confidence = result.confidence {
        print("置信度：\(confidence)")
    }
} catch {
    print("识别失败：\(error.localizedDescription)")
}
```

### 中文识别

```swift
// 使用预定义的中文配置
let config = RecognitionConfig.chinese

let result = try await transcriber.transcribe(
    fileURL: audioURL,
    config: config
)
```

### 英文识别

```swift
// 使用预定义的英文配置
let config = RecognitionConfig.english

let result = try await transcriber.transcribe(
    fileURL: audioURL,
    config: config
)
```

### 自定义配置

```swift
let config = RecognitionConfig(
    locale: Locale(identifier: "zh-CN"),           // 语言
    requiresOnDeviceRecognition: false,            // 是否使用离线识别
    taskHint: .dictation,                          // 任务类型提示
    punctuationRecovery: .default                  // 标点符号恢复配置
)
```

### 标点符号恢复

SpeechToTextKit 提供智能标点符号恢复功能，基于 Natural Language 语义分析和停顿时长智能添加标点。

#### 默认模式

```swift
let config = RecognitionConfig(
    locale: Locale(identifier: "zh-CN"),
    punctuationRecovery: .default  // 基于停顿时长添加标点
)

let result = try await transcriber.transcribe(fileURL: audioURL, config: config)
print(result.formattedText)  // 带标点的文本
```

#### 诗词模式

专门为古诗词、现代诗优化的断句策略：

```swift
let config = RecognitionConfig(
    locale: Locale(identifier: "zh-CN"),
    punctuationRecovery: .poetry  // 诗词断句模式
)

let result = try await transcriber.transcribe(fileURL: audioURL, config: config)
// 输入：“床前明月光疑是地上霜举头望明月低头思故乡”
// 输出：“床前明月光。疑是地上霜。举头望明月。低头思故乡。”
```

#### 纯语义模式

适用于没有时间信息或时间信息不准确的场景：

```swift
let config = RecognitionConfig(
    locale: Locale(identifier: "zh-CN"),
    punctuationRecovery: .semanticOnly  // 忽略停顿，仅依赖语义分析
)

let result = try await transcriber.transcribe(fileURL: audioURL, config: config)
```

#### 禁用标点恢复

```swift
let config = RecognitionConfig(
    locale: Locale(identifier: "zh-CN"),
    punctuationRecovery: nil  // 不添加标点
)
```

#### 自定义标点配置

```swift
let customOptions = PunctuationRecoveryOptions(
    enabled: true,
    shortPauseThreshold: 0.5,      // 短停顿阈值（逗号）
    longPauseThreshold: 1.0,       // 长停顿阈值（句号）
    enableSemanticMode: false,     // 是否启用语义模式
    minWordsForSentence: 5         // 句子最小词数
)

let config = RecognitionConfig(
    locale: Locale(identifier: "zh-CN"),
    punctuationRecovery: customOptions
)
```

### 获取详细结果

```swift
let result = try await transcriber.transcribe(
    fileURL: audioURL,
    config: config
)

// 完整文本
print("文本：\(result.text)")

// 总体置信度
if let confidence = result.confidence {
    print("总体置信度：\(String(format: "%.2f%%", confidence * 100))")
}

// 文本片段详情
if let segments = result.segments {
    for (index, segment) in segments.enumerated() {
        print("片段 \(index + 1)：")
        print("  文本：\(segment.text)")
        print("  时间：\(segment.timestamp)s")
        print("  持续时间：\(segment.duration)s")
        print("  置信度：\(String(format: "%.2f%%", segment.confidence * 100))")
    }
}
```

### 检查权限状态

```swift
let permissionManager = SpeechPermissionManager()
let status = permissionManager.status()

switch status {
case .notDetermined:
    print("用户尚未做出选择")
case .denied:
    print("用户拒绝了权限")
case .restricted:
    print("权限受限（家长控制等）")
case .authorized:
    print("已授权")
}
```

## 📖 API 文档

### RecognitionConfig

识别配置

```swift
public struct RecognitionConfig {
    /// 识别语言区域
    public let locale: Locale
    
    /// 是否要求设备本地识别（离线）
    public let requiresOnDeviceRecognition: Bool
    
    /// 任务提示类型
    public let taskHint: TaskHint
    
    /// 标点符号恢复配置
    public let punctuationRecovery: PunctuationRecoveryOptions?
}
```

**预定义配置：**
- `.chinese`: 中文识别配置
- `.english`: 英文识别配置

### PunctuationRecoveryOptions

标点符号恢复配置

```swift
public struct PunctuationRecoveryOptions {
    /// 是否启用标点符号恢复
    public let enabled: Bool
    
    /// 短停顿阈值（秒）- 逗号
    public let shortPauseThreshold: Double
    
    /// 长停顿阈值（秒）- 句号
    public let longPauseThreshold: Double
    
    /// 是否启用纯语义模式
    public let enableSemanticMode: Bool
    
    /// 语义模式下的最小词语数
    public let minWordsForSentence: Int
}
```

**预定义配置：**
- `.default`: 默认模式，基于停顿时长添加标点
- `.poetry`: 诗词模式，适用于古诗词、现代诗
- `.semanticOnly`: 纯语义模式，忽略停顿时长

### RecognitionResult

识别结果

```swift
public struct RecognitionResult {
    /// 原始识别文本（无标点）
    public let text: String
    
    /// 格式化后的文本（带标点）
    public let formattedText: String
    
    /// 总体置信度 (0.0 - 1.0)
    public let confidence: Double?
    
    /// 文本片段详情
    public let segments: [RecognitionSegment]
    
    /// 识别所用语言
    public let locale: Locale?
}
```

**使用示例：**
```swift
let result = try await transcriber.transcribe(fileURL: audioURL, config: config)

// 使用格式化后的文本（带标点）
print(result.formattedText)  // "床前明月光。疑是地上霜。"

// 使用原始文本（无标点）
print(result.text)           // "床前明月光疑是地上霜"
```

### RecognitionError

错误类型

```swift
public enum RecognitionError: Error {
    case notDetermined      // 权限未确定
    case denied             // 权限被拒绝
    case restricted         // 权限受限
    case notAvailable       // 服务不可用
    case localeUnsupported  // 不支持的语言
    case fileNotFound       // 文件不存在
    case invalidFile        // 无效文件
    case cancelled          // 操作被取消
    case underlying(String) // 其他错误
}
```

## ⚠️ 注意事项

### 支持的音频格式

iOS Speech Framework 支持以下音频格式：
- `.m4a` (AAC)
- `.wav`
- `.mp3`
- `.aiff`
- 其他 Core Audio 支持的格式

### 文件大小限制

- **本地文件**：建议单个文件不超过 1 分钟（约 1-2 MB）
- **长音频**：对于较长的音频，建议先分割成小段再识别

### 网络要求

- **在线识别**（默认）：需要网络连接，准确率更高
- **离线识别**：需设置 `requiresOnDeviceRecognition = true`，不需要网络但准确率可能较低

### 性能建议

1. **避免并发**：同时进行多个识别任务可能影响性能
2. **预处理音频**：清晰的音频会获得更好的识别结果
3. **选择合适的语言**：正确设置 `locale` 可显著提高准确率

## 🔧 故障排除

### 识别失败

**问题**：识别总是失败或返回空结果

**解决方案**：
1. 检查音频文件是否存在且格式正确
2. 确认已授予语音识别权限
3. 检查网络连接（在线识别需要）
4. 验证音频语言与配置的 `locale` 匹配

### 权限被拒绝

**问题**：应用无法获取语音识别权限

**解决方案**：
1. 确保 `Info.plist` 中已添加 `NSSpeechRecognitionUsageDescription`
2. 引导用户到系统设置中手动开启权限
3. 提供清晰的权限说明和使用场景

### 服务不可用

**问题**：提示 `notAvailable` 错误

**解决方案**：
1. 检查设备系统版本是否支持（iOS 10+）
2. 验证网络连接（在线识别）
3. 稍后重试（服务暂时不可用）

## 📝 示例项目

查看 `Example-UIKit` 目录获取完整的示例应用。

运行示例：

```bash
cd SpeechToText
open Example-UIKit/Example-UIKit.xcodeproj
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 🙏 致谢

本项目基于 Apple 的 [Speech Framework](https://developer.apple.com/documentation/speech) 构建。

---

**Made with ❤️ by Your Team**
