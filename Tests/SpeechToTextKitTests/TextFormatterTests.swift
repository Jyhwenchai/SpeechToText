import Testing
@testable import SpeechToTextKit

/// TextFormatter 单元测试
/// 
/// 测试标点符号恢复功能，包括：
/// - 基于停顿时长的标点插入
/// - Natural Language 语义分析
/// - 问句和感叹句识别
/// - 句子边界检测
struct TextFormatterTests {
  
  
  /// 测试英文问句识别
  @Test("英文问句识别")
  func testEnglishQuestionRecognition() {
    let segments = [
      TextFormatter.SegmentProxy(text: "What is your name", start: 0, end: 2.0),
      TextFormatter.SegmentProxy(text: "My name is John", start: 3.5, end: 5.5)
    ]
    
    let options = PunctuationRecoveryOptions.default
    let result = TextFormatter.formatSync(
      text: "What is your name My name is John",
      segments: segments,
      options: options
    )
    
    // 应该在问句后添加问号
    #expect(result.contains("?"))
  }
  
  /// 测试中文感叹句识别
  @Test("中文感叹句识别")
  func testChineseExclamationRecognition() {
    let segments = [
      TextFormatter.SegmentProxy(text: "太好了", start: 0, end: 1.5),
      TextFormatter.SegmentProxy(text: "我们成功了", start: 3.0, end: 4.5)
    ]
    
    let options = PunctuationRecoveryOptions.default
    let result = TextFormatter.formatSync(
      text: "太好了我们成功了",
      segments: segments,
      options: options
    )
    
    // 应该包含感叹号
    #expect(result.contains("!") || result.contains("！"))
  }
  
  /// 测试英文感叹句识别
  @Test("英文感叹句识别")
  func testEnglishExclamationRecognition() {
    let segments = [
      TextFormatter.SegmentProxy(text: "Wow that's amazing", start: 0, end: 2.0),
      TextFormatter.SegmentProxy(text: "I can't believe it", start: 3.5, end: 5.5)
    ]
    
    let options = PunctuationRecoveryOptions.default
    let result = TextFormatter.formatSync(
      text: "Wow that's amazing I can't believe it",
      segments: segments,
      options: options
    )
    
    // 应该包含感叹号
    #expect(result.contains("!"))
  }
  
  /// 测试句子边界检测（中文）
  @Test("中文句子边界检测")
  func testChineseSentenceBoundary() {
    let segments = [
      TextFormatter.SegmentProxy(text: "我喜欢编程", start: 0, end: 2.0),
      TextFormatter.SegmentProxy(text: "它很有趣", start: 3.0, end: 5.0),
      TextFormatter.SegmentProxy(text: "而且很有用", start: 5.5, end: 7.0)
    ]
    
    let options = PunctuationRecoveryOptions.default
    let result = TextFormatter.formatSync(
      text: "我喜欢编程它很有趣而且很有用",
      segments: segments,
      options: options
    )
    
    // 应该包含标点符号
    #expect(result.contains("。") || result.contains("，"))
  }
  
  /// 测试句子边界检测（英文）
  @Test("英文句子边界检测")
  func testEnglishSentenceBoundary() {
    let segments = [
      TextFormatter.SegmentProxy(text: "I love programming", start: 0, end: 2.0),
      TextFormatter.SegmentProxy(text: "It is very interesting", start: 3.5, end: 6.0),
      TextFormatter.SegmentProxy(text: "Moreover it is useful", start: 6.5, end: 9.0)
    ]
    
    let options = PunctuationRecoveryOptions.default
    let result = TextFormatter.formatSync(
      text: "I love programming It is very interesting Moreover it is useful",
      segments: segments,
      options: options
    )
    
    // 应该包含标点符号
    #expect(result.contains(".") || result.contains(","))
  }
  
  
  /// 测试长停顿添加句号
  @Test("长停顿添加句号")
  func testLongPausePeriod() {
    let segments = [
      TextFormatter.SegmentProxy(text: "这是第一句话", start: 0, end: 2.0),
      TextFormatter.SegmentProxy(text: "这是第二句话", start: 4.0, end: 6.0)
    ]
    
    let options = PunctuationRecoveryOptions.default
    let result = TextFormatter.formatSync(
      text: "这是第一句话这是第二句话",
      segments: segments,
      options: options
    )
    
    // 长停顿应该添加句号
    #expect(result.contains("。") || result.contains("."))
  }
  
  /// 测试保留现有标点
  @Test("保留现有标点")
  func testPreserveExistingPunctuation() {
    let segments = [
      TextFormatter.SegmentProxy(text: "你好！", start: 0, end: 1.5),
      TextFormatter.SegmentProxy(text: "很高兴见到你", start: 3.0, end: 5.0)
    ]
    
    let options = PunctuationRecoveryOptions.default
    let result = TextFormatter.formatSync(
      text: "你好！很高兴见到你",
      segments: segments,
      options: options
    )
    
    // 应该保留原有的感叹号
    #expect(result.contains("！") || result.contains("!"))
  }
  
  /// 测试空segments
  @Test("空segments处理")
  func testEmptySegments() {
    let segments: [TextFormatter.SegmentProxy] = []
    let options = PunctuationRecoveryOptions.default
    let result = TextFormatter.formatSync(
      text: "测试文本",
      segments: segments,
      options: options
    )
    
    // 应该返回原文本（去除空白）
    #expect(result == "测试文本")
  }
  
  /// 测试禁用标点恢复
  @Test("禁用标点恢复")
  func testDisabledPunctuation() {
    let segments = [
      TextFormatter.SegmentProxy(text: "第一句", start: 0, end: 2.0),
      TextFormatter.SegmentProxy(text: "第二句", start: 4.0, end: 6.0)
    ]
    
    // 创建禁用标点恢复的配置
    let options = PunctuationRecoveryOptions(
      enabled: false,
      shortPauseThreshold: 0.3,
      longPauseThreshold: 0.8,
      superLongPauseThreshold: 1.5,
      chineseRatioThreshold: 0.3,
      preserveExistingPunctuation: true
    )
    
    let result = TextFormatter.formatSync(
      text: "第一句第二句",
      segments: segments,
      options: options
    )
    
    // 禁用时不应添加标点
    #expect(!result.contains("。") && !result.contains(","))
  }
  
  /// 测试混合中英文
  @Test("混合中英文")
  func testMixedLanguage() {
    let segments = [
      TextFormatter.SegmentProxy(text: "我喜欢用Swift编程", start: 0, end: 2.5),
      TextFormatter.SegmentProxy(text: "它很强大", start: 3.5, end: 5.0)
    ]
    
    let options = PunctuationRecoveryOptions.default
    let result = TextFormatter.formatSync(
      text: "我喜欢用Swift编程它很强大",
      segments: segments,
      options: options
    )
    
    // 应该根据主要语言（中文）添加标点
    #expect(result.contains("。") || result.contains("，"))
  }
}
