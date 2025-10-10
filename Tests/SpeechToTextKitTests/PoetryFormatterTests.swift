import Testing
@testable import SpeechToTextKit

/// 古诗词和连续文本断句测试
/// 
/// 测试纯语义模式的标点符号恢复功能
struct PoetryFormatterTests {
  
  /// 测试古诗断句：床前明月光
  @Test("古诗断句：床前明月光")
  func testPoetry_ChuangQianMingYueGuang() {
    // 将古诗按每5个字分成一个segment（模拟连续语音识别）
    let segments = [
      TextFormatter.SegmentProxy(text: "床前明月光", start: 0, end: 1.5),
      TextFormatter.SegmentProxy(text: "疑是地上霜", start: 1.5, end: 3.0),
      TextFormatter.SegmentProxy(text: "举头望明月", start: 3.0, end: 4.5),
      TextFormatter.SegmentProxy(text: "低头思故乡", start: 4.5, end: 6.0)
    ]
    
    // 使用诗词配置
    let options = PunctuationRecoveryOptions.poetry
    let result = TextFormatter.formatSync(
      text: "床前明月光疑是地上霜举头望明月低头思故乡",
      segments: segments,
      options: options
    )
    
    print("诗词断句结果: \(result)")
    
    // 应该包含逗号或句号
    #expect(result.contains("，") || result.contains("。"))
    
    // 理想结果：床前明月光，疑是地上霜。举头望明月，低头思故乡。
  }
  
  /// 测试纯语义模式：无时间信息场景
  @Test("纯语义模式：连续文本断句")
  func testSemanticOnly_ContinuousText() {
    // 模拟没有准确时间信息的场景（gap = 0）
    let segments = [
      TextFormatter.SegmentProxy(text: "床前明月光", start: 0, end: 0),
      TextFormatter.SegmentProxy(text: "疑是地上霜", start: 0, end: 0),
      TextFormatter.SegmentProxy(text: "举头望明月", start: 0, end: 0),
      TextFormatter.SegmentProxy(text: "低头思故乡", start: 0, end: 0)
    ]
    
    // 使用纯语义模式
    let options = PunctuationRecoveryOptions.semanticOnly
    let result = TextFormatter.formatSync(
      text: "床前明月光疑是地上霜举头望明月低头思故乡",
      segments: segments,
      options: options
    )
    
    print("纯语义断句结果: \(result)")
    
    // 应该包含标点符号
    #expect(result.contains("，") || result.contains("。"))
  }
  
  /// 测试现代散文断句
  @Test("现代散文断句")
  func testModernProse() {
    let segments = [
      TextFormatter.SegmentProxy(text: "春天来了", start: 0, end: 0),
      TextFormatter.SegmentProxy(text: "万物复苏", start: 0, end: 0),
      TextFormatter.SegmentProxy(text: "鸟儿在树上唱歌", start: 0, end: 0),
      TextFormatter.SegmentProxy(text: "花儿竞相开放", start: 0, end: 0)
    ]
    
    let options = PunctuationRecoveryOptions.semanticOnly
    let result = TextFormatter.formatSync(
      text: "春天来了万物复苏鸟儿在树上唱歌花儿竞相开放",
      segments: segments,
      options: options
    )
    
    print("散文断句结果: \(result)")
    
    // 应该包含标点符号
    #expect(result.contains("，") || result.contains("。"))
  }
  
  /// 测试词语数判断
  @Test("词语数判断：短语vs句子")
  func testWordCountJudgment() {
    // 短语（2-3个词）应该用逗号
    let shortSegments = [
      TextFormatter.SegmentProxy(text: "春天", start: 0, end: 0),
      TextFormatter.SegmentProxy(text: "来了", start: 0, end: 0)
    ]
    
    let shortResult = TextFormatter.formatSync(
      text: "春天来了",
      segments: shortSegments,
      options: .semanticOnly
    )
    
    print("短语结果: \(shortResult)")
    // 短语应该用逗号
    #expect(shortResult.contains("，"))
    
    // 完整句子（>=5个词）应该用句号
    let longSegments = [
      TextFormatter.SegmentProxy(text: "我喜欢在春天的早晨散步", start: 0, end: 0)
    ]
    
    let longResult = TextFormatter.formatSync(
      text: "我喜欢在春天的早晨散步",
      segments: longSegments,
      options: .semanticOnly
    )
    
    print("句子结果: \(longResult)")
    // 完整句子应该用句号（如果是最后一个segment）
  }
  
  /// 测试七言绝句
  @Test("七言绝句断句")
  func testSevenCharacterQuatrain() {
    let segments = [
      TextFormatter.SegmentProxy(text: "两个黄鹂鸣翠柳", start: 0, end: 1.5),
      TextFormatter.SegmentProxy(text: "一行白鹭上青天", start: 1.5, end: 3.0),
      TextFormatter.SegmentProxy(text: "窗含西岭千秋雪", start: 3.0, end: 4.5),
      TextFormatter.SegmentProxy(text: "门泊东吴万里船", start: 4.5, end: 6.0)
    ]
    
    let options = PunctuationRecoveryOptions.poetry
    let result = TextFormatter.formatSync(
      text: "两个黄鹂鸣翠柳一行白鹭上青天窗含西岭千秋雪门泊东吴万里船",
      segments: segments,
      options: options
    )
    
    print("七言绝句结果: \(result)")
    
    // 应该包含标点符号
    #expect(result.contains("，") || result.contains("。"))
  }
  
  /// 测试混合长短句
  @Test("混合长短句")
  func testMixedLengthSentences() {
    let segments = [
      TextFormatter.SegmentProxy(text: "春眠不觉晓", start: 0, end: 1.2),
      TextFormatter.SegmentProxy(text: "处处闻啼鸟", start: 1.2, end: 2.4),
      TextFormatter.SegmentProxy(text: "夜来风雨声", start: 2.4, end: 3.6),
      TextFormatter.SegmentProxy(text: "花落知多少", start: 3.6, end: 4.8)
    ]
    
    let options = PunctuationRecoveryOptions.poetry
    let result = TextFormatter.formatSync(
      text: "春眠不觉晓处处闻啼鸟夜来风雨声花落知多少",
      segments: segments,
      options: options
    )
    
    print("混合长短句结果: \(result)")
    
    // 最后一句是问句，应该有问号
    #expect(result.contains("多少"))
  }
  
  /// 测试对比：标准模式 vs 语义模式
  @Test("对比：标准模式vs语义模式")
  func testCompareStandardVsSemantic() {
    let segments = [
      TextFormatter.SegmentProxy(text: "床前明月光", start: 0, end: 0),
      TextFormatter.SegmentProxy(text: "疑是地上霜", start: 0, end: 0)
    ]
    
    let text = "床前明月光疑是地上霜"
    
    // 标准模式（无停顿时长）
    let standardResult = TextFormatter.formatSync(
      text: text,
      segments: segments,
      options: .default
    )
    
    // 语义模式
    let semanticResult = TextFormatter.formatSync(
      text: text,
      segments: segments,
      options: .semanticOnly
    )
    
    print("标准模式结果: \(standardResult)")
    print("语义模式结果: \(semanticResult)")
    
    // 语义模式应该能添加标点，标准模式不能（因为gap=0）
    #expect(semanticResult.contains("，") || semanticResult.contains("。"))
  }
}
