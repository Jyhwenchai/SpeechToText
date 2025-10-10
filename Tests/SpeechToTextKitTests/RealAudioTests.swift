import Testing
import Foundation
@testable import SpeechToTextKit

/// 真实音频文件测试
/// 
/// 测试实际音频文件的语音识别和标点符号恢复功能
struct RealAudioTests {
  
  /// 测试古诗词音频：床前明月光
  @Test("真实音频测试：床前明月光（诗词模式）")
  func testRealAudio_Poetry() async throws {
    // 音频文件路径
    let audioPath = "/Users/didong/Desktop/work/project/SpeechToText/Example-UIKit/Example-UIKit/test.m4a"
    let audioURL = URL(fileURLWithPath: audioPath)
    
    // 检查文件是否存在
    guard FileManager.default.fileExists(atPath: audioPath) else {
      Issue.record("音频文件不存在: \(audioPath)")
      return
    }
    
    print("📁 音频文件路径: \(audioPath)")
    
    // 创建语音识别配置（中文 + 诗词断句）
    let config = RecognitionConfig(
      locale: Locale(identifier: "zh-CN"),
      requiresOnDeviceRecognition: false,
      taskHint: .dictation,
      punctuationRecovery: .poetry  // 使用诗词模式
    )
    
    // 创建语音转文本实例
    let transcriber = SpeechFileTranscriber(config: config)
    
    print("🎤 开始识别音频...")
    
    // 执行语音识别
    let result = try await transcriber.transcribe(audioURL: audioURL)
    
    print("📝 识别结果:")
    print("  - 原始文本: \(result.formattedText)")
    print("  - 时间片段数量: \(result.segments.count)")
    
    // 打印每个时间片段的详细信息
    for (index, segment) in result.segments.enumerated() {
      print("  [\(index)] \(String(format: "%.2f", segment.start))-\(String(format: "%.2f", segment.end))s: \(segment.text)")
    }
    
    // 验证结果
    #expect(!result.formattedText.isEmpty, "识别文本不应为空")
    
    // 验证是否包含关键词
    let keywords = ["床前", "明月", "疑是", "地上霜", "举头", "低头", "故乡"]
    var foundKeywords = 0
    for keyword in keywords {
      if result.formattedText.contains(keyword) {
        foundKeywords += 1
      }
    }
    
    print("✅ 找到关键词数量: \(foundKeywords)/\(keywords.count)")
    #expect(foundKeywords >= 5, "应该识别出至少5个关键词")
    
    // 验证是否添加了标点符号
    let hasPunctuation = result.formattedText.contains("，") || 
                        result.formattedText.contains("。") ||
                        result.formattedText.contains(",") ||
                        result.formattedText.contains(".")
    
    print("📌 标点符号检测: \(hasPunctuation ? "✅ 已添加" : "❌ 未添加")")
    #expect(hasPunctuation, "应该包含标点符号")
    
    print("\n🎯 最终格式化文本:")
    print("   \(result.formattedText)")
  }
  
  /// 测试古诗词音频：纯语义模式
  @Test("真实音频测试：床前明月光（纯语义模式）")
  func testRealAudio_SemanticOnly() async throws {
    let audioPath = "/Users/didong/Desktop/work/project/SpeechToText/Example-UIKit/Example-UIKit/test.m4a"
    let audioURL = URL(fileURLWithPath: audioPath)
    
    guard FileManager.default.fileExists(atPath: audioPath) else {
      Issue.record("音频文件不存在: \(audioPath)")
      return
    }
    
    print("📁 音频文件路径: \(audioPath)")
    
    // 使用纯语义模式
    let config = RecognitionConfig(
      locale: Locale(identifier: "zh-CN"),
      requiresOnDeviceRecognition: false,
      taskHint: .dictation,
      punctuationRecovery: .semanticOnly
    )
    
    let transcriber = SpeechFileTranscriber(config: config)
    
    print("🎤 开始识别音频（纯语义模式）...")
    
    let result = try await transcriber.transcribe(audioURL: audioURL)
    
    print("📝 识别结果:")
    print("  - 格式化文本: \(result.formattedText)")
    print("  - 时间片段数量: \(result.segments.count)")
    
    // 验证标点符号
    let punctuationCount = result.formattedText.filter { "，。,.".contains($0) }.count
    print("📌 标点符号数量: \(punctuationCount)")
    
    #expect(punctuationCount > 0, "纯语义模式应该添加标点符号")
    
    print("\n🎯 最终格式化文本:")
    print("   \(result.formattedText)")
  }
  
  /// 测试对比：不同配置的效果
  @Test("对比测试：标准模式 vs 诗词模式 vs 纯语义模式")
  func testComparison_AllModes() async throws {
    let audioPath = "/Users/didong/Desktop/work/project/SpeechToText/Example-UIKit/Example-UIKit/test.m4a"
    let audioURL = URL(fileURLWithPath: audioPath)
    
    guard FileManager.default.fileExists(atPath: audioPath) else {
      Issue.record("音频文件不存在: \(audioPath)")
      return
    }
    
    print("\n" + String(repeating: "=", count: 60))
    print("🔬 对比测试：不同标点恢复模式")
    print(String(repeating: "=", count: 60))
    
    // 配置1：标准模式
    print("\n1️⃣  标准模式 (.default)")
    print(String(repeating: "-", count: 60))
    let config1 = RecognitionConfig(
      locale: Locale(identifier: "zh-CN"),
      punctuationRecovery: .default
    )
    let transcriber1 = SpeechFileTranscriber(config: config1)
    let result1 = try await transcriber1.transcribe(audioURL: audioURL)
    print("结果: \(result1.formattedText)")
    print("标点数: \(result1.formattedText.filter { "，。".contains($0) }.count)")
    
    // 配置2：诗词模式
    print("\n2️⃣  诗词模式 (.poetry)")
    print(String(repeating: "-", count: 60))
    let config2 = RecognitionConfig(
      locale: Locale(identifier: "zh-CN"),
      punctuationRecovery: .poetry
    )
    let transcriber2 = SpeechFileTranscriber(config: config2)
    let result2 = try await transcriber2.transcribe(audioURL: audioURL)
    print("结果: \(result2.formattedText)")
    print("标点数: \(result2.formattedText.filter { "，。".contains($0) }.count)")
    
    // 配置3：纯语义模式
    print("\n3️⃣  纯语义模式 (.semanticOnly)")
    print(String(repeating: "-", count: 60))
    let config3 = RecognitionConfig(
      locale: Locale(identifier: "zh-CN"),
      punctuationRecovery: .semanticOnly
    )
    let transcriber3 = SpeechFileTranscriber(config: config3)
    let result3 = try await transcriber3.transcribe(audioURL: audioURL)
    print("结果: \(result3.formattedText)")
    print("标点数: \(result3.formattedText.filter { "，。".contains($0) }.count)")
    
    print("\n" + String(repeating: "=", count: 60))
    print("📊 对比总结")
    print(String(repeating: "=", count: 60))
    print("标准模式标点数: \(result1.formattedText.filter { "，。".contains($0) }.count)")
    print("诗词模式标点数: \(result2.formattedText.filter { "，。".contains($0) }.count)")
    print("语义模式标点数: \(result3.formattedText.filter { "，。".contains($0) }.count)")
    
    // 验证：诗词模式和语义模式应该比标准模式添加更多标点
    let standardPunctCount = result1.formattedText.filter { "，。".contains($0) }.count
    let poetryPunctCount = result2.formattedText.filter { "，。".contains($0) }.count
    let semanticPunctCount = result3.formattedText.filter { "，。".contains($0) }.count
    
    print("\n✅ 验证结果:")
    print("  - 诗词模式优于标准模式: \(poetryPunctCount >= standardPunctCount ? "✓" : "✗")")
    print("  - 语义模式优于标准模式: \(semanticPunctCount >= standardPunctCount ? "✓" : "✗")")
    
    #expect(poetryPunctCount >= standardPunctCount, "诗词模式应该添加≥标准模式的标点")
    #expect(semanticPunctCount >= standardPunctCount, "语义模式应该添加≥标准模式的标点")
  }
  
  /// 手动测试辅助函数：打印详细的 segments 信息
  @Test("调试：打印详细 segments 信息")
  func testDebug_PrintSegments() async throws {
    let audioPath = "/Users/didong/Desktop/work/project/SpeechToText/Example-UIKit/Example-UIKit/test.m4a"
    let audioURL = URL(fileURLWithPath: audioPath)
    
    guard FileManager.default.fileExists(atPath: audioPath) else {
      Issue.record("音频文件不存在: \(audioPath)")
      return
    }
    
    let config = RecognitionConfig(
      locale: Locale(identifier: "zh-CN"),
      punctuationRecovery: nil  // 不使用标点恢复，获取原始识别结果
    )
    
    let transcriber = SpeechFileTranscriber(config: config)
    let result = try await transcriber.transcribe(audioURL: audioURL)
    
    print("\n" + String(repeating: "=", count: 80))
    print("🔍 详细 Segments 分析")
    print(String(repeating: "=", count: 80))
    print("总片段数: \(result.segments.count)")
    print("原始文本: \(result.formattedText)")
    print(String(repeating: "-", count: 80))
    
    for (index, segment) in result.segments.enumerated() {
      let gap = index < result.segments.count - 1 
        ? result.segments[index + 1].start - segment.end 
        : 0
      
      print("[\(String(format: "%2d", index))] " +
            "时间: \(String(format: "%5.2f", segment.start))s - \(String(format: "%5.2f", segment.end))s " +
            "| 时长: \(String(format: "%.2f", segment.end - segment.start))s " +
            "| 间隔: \(String(format: "%.2f", gap))s " +
            "| 文本: \"\(segment.text)\"")
    }
    
    print(String(repeating: "=", count: 80))
    
    // 使用这些信息手动测试 TextFormatter
    print("\n🧪 手动应用标点恢复（诗词模式）:")
    
    let segments = result.segments.map { segment in
      TextFormatter.SegmentProxy(
        text: segment.text,
        start: segment.start,
        end: segment.end
      )
    }
    
    let formattedResult = TextFormatter.formatSync(
      text: result.formattedText,
      segments: segments,
      options: .poetry
    )
    
    print("格式化后: \(formattedResult)")
  }
}
