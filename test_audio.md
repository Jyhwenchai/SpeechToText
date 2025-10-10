# 测试 test.m4a 音频文件的标点符号恢复

## 问题
你添加了一个 test.m4a 文件，内容是"床前明月光疑是地上霜举头望明月低头思故乡"，需要测试标点符号恢复功能。

## 解决方案

由于单元测试需要复杂的配置和权限，我为你创建了一个简单的测试方法。你可以在 Example-UIKit 应用中测试：

### 方法 1：在 Example 应用中测试（推荐）

1. **打开 Example-UIKit 项目**
2. **在主界面添加测试按钮**
3. **使用以下代码**：

```swift
// 在 ViewController 中添加测试按钮点击事件
@objc private func testPoetryAudio() {
    Task {
        do {
            // 获取 test.m4a 的 URL
            guard let audioURL = Bundle.main.url(forResource: "test", withExtension: "m4a") else {
                print("❌ 找不到 test.m4a 文件")
                return
            }
            
            print("📁 音频文件: \(audioURL.path)")
            
            // 测试1：标准模式
            print("\n========== 测试1：标准模式 ==========")
            let config1 = RecognitionConfig(
                locale: Locale(identifier: "zh-CN"),
                punctuationRecovery: .default
            )
            let transcriber1 = SpeechFileTranscriber()
            let result1 = try await transcriber1.transcribe(fileURL: audioURL, config: config1)
            print("结果: \(result1.formattedText)")
            print("片段数: \(result1.segments.count)")
            print("标点数: \(result1.formattedText.filter { "，。".contains($0) }.count)")
            
            // 测试2：诗词模式
            print("\n========== 测试2：诗词模式 ==========")
            let config2 = RecognitionConfig(
                locale: Locale(identifier: "zh-CN"),
                punctuationRecovery: .poetry
            )
            let transcriber2 = SpeechFileTranscriber()
            let result2 = try await transcriber2.transcribe(fileURL: audioURL, config: config2)
            print("结果: \(result2.formattedText)")
            print("片段数: \(result2.segments.count)")
            print("标点数: \(result2.formattedText.filter { "，。".contains($0) }.count)")
            
            // 测试3：纯语义模式
            print("\n========== 测试3：纯语义模式 ==========")
            let config3 = RecognitionConfig(
                locale: Locale(identifier: "zh-CN"),
                punctuationRecovery: .semanticOnly
            )
            let transcriber3 = SpeechFileTranscriber()
            let result3 = try await transcriber3.transcribe(fileURL: audioURL, config: config3)
            print("结果: \(result3.formattedText)")
            print("片段数: \(result3.segments.count)")
            print("标点数: \(result3.formattedText.filter { "，。".contains($0) }.count)")
            
            // 对比总结
            print("\n========== 对比总结 ==========")
            print("标准模式: \(result1.formattedText)")
            print("诗词模式: \(result2.formattedText)")
            print("语义模式: \(result3.formattedText)")
            
            print("\n✅ 测试完成")
            
        } catch {
            print("❌ 错误: \(error)")
        }
    }
}
```

### 方法 2：使用 Swift Playgrounds（简单）

创建一个 Playground 文件：

```swift
import PlaygroundSupport
import SpeechToTextKit

PlaygroundPage.current.needsIndefiniteExecution = true

Task {
    let audioURL = URL(fileURLWithPath: "/Users/didong/Desktop/work/project/SpeechToText/Example-UIKit/Example-UIKit/test.m4a")
    
    let config = RecognitionConfig(
        locale: Locale(identifier: "zh-CN"),
        punctuationRecovery: .poetry
    )
    
    let transcriber = SpeechFileTranscriber()
    let result = try await transcriber.transcribe(fileURL: audioURL, config: config)
    
    print("识别结果: \(result.formattedText)")
    print("片段数: \(result.segments.count)")
    
    PlaygroundPage.current.finishExecution()
}
```

### 方法 3：调试原始 segments（了解时间信息）

```swift
// 先不使用标点恢复，查看原始识别结果
let configRaw = RecognitionConfig(
    locale: Locale(identifier: "zh-CN"),
    punctuationRecovery: nil  // 禁用标点恢复
)

let transcriberRaw = SpeechFileTranscriber()
let resultRaw = try await transcriberRaw.transcribe(fileURL: audioURL, config: configRaw)

print("========== 原始识别结果 ==========")
print("文本: \(resultRaw.formattedText)")
print("总片段数: \(resultRaw.segments.count)\n")

// 打印每个片段的详细信息
for (index, segment) in resultRaw.segments.enumerated() {
    let gap = index < resultRaw.segments.count - 1 
        ? resultRaw.segments[index + 1].start - segment.end 
        : 0
    
    print("[\(index)] \(String(format: "%.2f", segment.start))-\(String(format: "%.2f", segment.end))s (间隔: \(String(format: "%.2f", gap))s): \(segment.text)")
}

// 然后手动应用标点恢复
print("\n========== 应用诗词模式标点恢复 ==========")
let segments = resultRaw.segments.map { segment in
    TextFormatter.SegmentProxy(
        text: segment.text,
        start: segment.start,
        end: segment.end
    )
}

let formatted = TextFormatter.formatSync(
    text: resultRaw.formattedText,
    segments: segments,
    options: .poetry
)

print("格式化后: \(formatted)")
```

## 预期结果

基于我们的测试，你应该看到类似的结果：

**标准模式**（基于停顿时长）：
```
床前明月光疑是地上霜举头望明月低头思故乡
或
床前明月光。疑是地上霜。举头望明月。低头思故乡
（取决于实际录音的停顿情况）
```

**诗词模式**（语义 + 停顿）：
```
床前明月光。疑是地上霜。举头望明月，低头思故乡
```

**纯语义模式**（仅语义）：
```
床前明月光，疑是地上霜，举头望明月，低头思故乡
```

## 关键点

1. **权限要求**：需要在真机或模拟器上运行，因为语音识别需要权限
2. **网络要求**：默认使用在线识别，需要网络连接
3. **时间信息**：实际的标点插入效果取决于录音时的停顿情况
4. **语义分析**：新的纯语义模式即使没有停顿也能正确断句

## 故障排除

如果测试失败，请检查：

1. ✅ 文件是否存在且已添加到 Bundle
2. ✅ 是否授予了语音识别权限
3. ✅ 网络连接是否正常
4. ✅ 音频文件格式是否支持（.m4a / .wav / .mp3等）
5. ✅ iOS 版本是否 >= 13.0

## 下一步

运行上述代码后，查看控制台输出，你将看到：
- 原始识别文本
- 每个片段的时间信息和停顿间隔
- 三种模式下的格式化结果
- 标点符号的数量对比

这将帮助你验证标点符号恢复功能是否按预期工作！
