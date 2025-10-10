//
//  TextFormatter.swift
//  SpeechToTextKit
//
//  文本格式化工具 - 智能标点符号恢复
//

import Foundation

#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// 文本格式化工具
/// 
/// 基于语音识别的时间片段信息，智能添加标点符号，提升文本可读性。
/// 
/// ## 功能特性
/// - 自动检测中英文
/// - 根据停顿时长智能添加标点
/// - 保留并优化原有标点
/// - 纯函数实现，线程安全
/// 
/// ## 使用示例
/// ```swift
/// let options = PunctuationRecoveryOptions.default
/// let formatted = TextFormatter.formatSync(
///   text: originalText,
///   segments: segments,
///   options: options
/// )
/// ```
@available(iOS 13.0, macOS 10.15, *)
public actor TextFormatter {
  
  private let options: PunctuationRecoveryOptions
  
  /// 初始化文本格式化器
  /// - Parameter options: 标点符号恢复配置，默认使用 .default
  public init(options: PunctuationRecoveryOptions = .default) {
    self.options = options
  }
  
  /// 格式化文本（异步方法）
  /// - Parameters:
  ///   - text: 原始文本
  ///   - segments: 时间片段数组
  /// - Returns: 格式化后的文本
  public func format(text: String, segments: [SegmentProxy]) async -> String {
    Self.formatSync(text: text, segments: segments, options: options)
  }
  
  /// 格式化文本（同步纯函数）
  /// 
  /// 使用 Natural Language 框架进行智能分词和语义分析，结合停顿时长添加标点
  /// 
  /// - Parameters:
  ///   - text: 原始文本
  ///   - segments: 时间片段数组
  ///   - options: 标点符号恢复配置
  /// - Returns: 格式化后的文本
  public nonisolated static func formatSync(
    text: String,
    segments: [SegmentProxy],
    options: PunctuationRecoveryOptions
  ) -> String {
    // 禁用或空segments时直接返回原文
    guard options.enabled, !segments.isEmpty else {
      return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // 检测语言
    let detectedLanguage = detectLanguage(text: text, threshold: options.chineseRatioThreshold)
    let nlLanguage: NLLanguage = detectedLanguage == .chinese ? .simplifiedChinese : .english
    
    // 使用 Natural Language 框架进行分词
    let tokenizer = NLTokenizer(unit: .word)
    tokenizer.string = text
    tokenizer.setLanguage(nlLanguage)
    
    // 构建每个 segment 的词语信息
    var segmentWords: [[String]] = []
    for segment in segments {
      let words = extractWords(from: segment.text, tokenizer: tokenizer)
      segmentWords.append(words)
    }
    
    // 构建格式化文本
    var result = ""
    
    for (index, segment) in segments.enumerated() {
      let trimmedText = segment.text.trimmingCharacters(in: .whitespaces)
      guard !trimmedText.isEmpty else { continue }
      
      // 添加当前片段文本
      result += trimmedText
      
      // 非最后一个片段时，检查是否需要添加标点
      if index < segments.count - 1 {
        let nextSegment = segments[index + 1]
        let gap = nextSegment.start - segment.end
        
        // 检查当前文本是否已有标点符号
        if options.preserveExistingPunctuation, hasPunctuation(trimmedText) {
          if hasTerminalPunctuation(trimmedText) {
            if gap >= options.superLongPauseThreshold {
              result += " "
            }
          }
          continue
        }
        
        // 使用 Natural Language 语义分析 + 停顿时长决定标点
        // 语义模式：即使 gap = 0 也可以插入标点
        // 非语义模式：需要 gap > 0
        if options.enableSemanticMode || gap > 0 {
          let currentWords = segmentWords[index]
          let nextWords = segmentWords[index + 1]
          
          let punctuation = pickPunctuationWithNL(
            currentText: trimmedText,
            nextText: nextSegment.text.trimmingCharacters(in: .whitespaces),
            currentWords: currentWords,
            nextWords: nextWords,
            gap: gap,
            language: detectedLanguage,
            options: options
          )
          
          if !punctuation.isEmpty {
            result += punctuation
          }
        }
      } else {
        // 处理最后一个片段：在语义模式下添加句号
        if options.enableSemanticMode {
          // 如果文本未以标点结尾，添加句号
          if !hasPunctuation(trimmedText) {
            let currentWords = segmentWords[index]
            let textLength = trimmedText.count
            
            // 诗词场景：4-8 字的完整句子
            if detectedLanguage == .chinese && textLength >= 4 && textLength <= 8 {
              result += "。"
            } else if currentWords.count >= options.minWordsForSentence - 1 {
              // 一般场景：词数足够的完整句子
              result += detectedLanguage == .chinese ? "。" : "."
            }
          }
        }
      }
    }
    
    // 清理多余空格和重复标点
    result = cleanupPunctuation(result, language: detectedLanguage)
    
    return result
  }
}
	
// MARK: - 辅助方法

@available(iOS 13.0, macOS 10.15, *)
extension TextFormatter {
  
  /// 语言类型
  public enum Language {
    case chinese
    case english
  }
  
  /// 时间片段代理结构
  public struct SegmentProxy: Sendable, Equatable {
    public let text: String
    public let start: TimeInterval
    public let end: TimeInterval
    
    public init(text: String, start: TimeInterval, end: TimeInterval) {
      self.text = text
      self.start = start
      self.end = end
    }
  }
  
  /// 检测文本语言
  /// - Parameters:
  ///   - text: 待检测文本
  ///   - threshold: 中文字符占比阈值
  /// - Returns: 检测到的语言类型
  nonisolated static func detectLanguage(
    text: String,
    threshold: Double
  ) -> Language {
    guard !text.isEmpty else { return .english }
    
    let chineseCount = text.reduce(0) { count, char in
      count + (isCJKCharacter(char) ? 1 : 0)
    }
    
    let ratio = Double(chineseCount) / Double(text.count)
    return ratio > threshold ? .chinese : .english
  }
  
  /// 判断字符是否为 CJK 字符
  /// - Parameter char: 待判断字符
  /// - Returns: 是否为 CJK 字符
  nonisolated static func isCJKCharacter(_ char: Character) -> Bool {
    guard let scalar = char.unicodeScalars.first else { return false }
    let value = scalar.value
    
    // CJK 统一汉字 (U+4E00 - U+9FFF)
    // CJK 扩展A (U+3400 - U+4DBF)
    // CJK 扩展B (U+20000 - U+2A6DF)
    return (value >= 0x4E00 && value <= 0x9FFF) ||
           (value >= 0x3400 && value <= 0x4DBF) ||
           (value >= 0x20000 && value <= 0x2A6DF)
  }
  
  /// 检查文本是否以标点符号结尾
  /// - Parameter text: 待检查文本
  /// - Returns: 是否以任何标点结尾
  nonisolated static func hasPunctuation(_ text: String) -> Bool {
    let punctuations: Set<Character> = [".", "?", "!", "。", "？", "！", ",", "，"]
    return text.last.map { punctuations.contains($0) } ?? false
  }
  
  /// 检查文本是否以终止标点结尾（句号、问号、叹号）
  /// - Parameter text: 待检查文本
  /// - Returns: 是否以终止标点结尾
  nonisolated static func hasTerminalPunctuation(_ text: String) -> Bool {
    let terminals: Set<Character> = [".", "?", "!", "。", "？", "！"]
    return text.last.map { terminals.contains($0) } ?? false
  }
  
  /// 使用 NLTokenizer 提取文本中的词语
  /// - Parameters:
  ///   - text: 待提取文本
  ///   - tokenizer: NLTokenizer 实例
  /// - Returns: 词语列表
  nonisolated static func extractWords(
    from text: String,
    tokenizer: NLTokenizer
  ) -> [String] {
    var words: [String] = []
    tokenizer.string = text
    
    tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
      let word = String(text[tokenRange])
      words.append(word)
      return true
    }
    
    return words
  }
  
  /// 使用 Natural Language 语义分析结合停顿时长选择标点
  /// 
  /// 基于以下策略：
  /// 1. 问句识别：检测疑问词或问号结尾
  /// 2. 感叹句识别：检测感叹词或语气强烈
  /// 3. 句子结束识别：基于停顿时长和语义完整性
  /// 4. 逗号插入：较短停顿时使用
  /// 
  /// - Parameters:
  ///   - currentText: 当前片段文本
  ///   - nextText: 下一片段文本
  ///   - currentWords: 当前片段的词语列表
  ///   - nextWords: 下一片段的词语列表
  ///   - gap: 停顿时长(秒)
  ///   - language: 检测到的语言
  ///   - options: 标点恢复配置
  /// - Returns: 选择的标点符号
  nonisolated static func pickPunctuationWithNL(
    currentText: String,
    nextText: String,
    currentWords: [String],
    nextWords: [String],
    gap: Double,
    language: Language,
    options: PunctuationRecoveryOptions
  ) -> String {
    // 纯语义模式：忽略停顿时长，仅基于语义分析
    let useSemanticOnly = options.enableSemanticMode
    
    // 1. 检查是否为问句(以疑问词或问号结尾)
    if isQuestion(currentText, language: language) {
      if useSemanticOnly || gap >= options.longPauseThreshold {
        return language == .chinese ? "？" : "? "
      }
    }
    
    // 2. 检查是否为感叹句(包含感叹词或语气强烈)
    if isExclamation(currentText, currentWords: currentWords, language: language) {
      if useSemanticOnly || gap >= options.longPauseThreshold {
        return language == .chinese ? "！" : "! "
      }
    }
    
    // 3. 检查是否为句子结束(基于语义完整性)
    // 语义模式：依据 minWordsForSentence 判断
    // 非语义模式：依据停顿时长 + 语义完整性
    let isSemanticallyComplete = useSemanticOnly 
      ? (currentWords.count >= options.minWordsForSentence)
      : isSentenceEnd(currentWords: currentWords, nextWords: nextWords, language: language)
    
    if isSemanticallyComplete {
      if useSemanticOnly || gap >= options.longPauseThreshold {
        return language == .chinese ? "。" : ". "
      }
    }
    
    // 4. 较短停顿或语义模式下的默认逗号
    if useSemanticOnly {
      // 语义模式改进：根据文本长度和结构判断
      // 对于较短片段（如诗词），优先使用句号而非逗号
      let textLength = currentText.count
      
      // 诗词场景：5-7 字为一句（如五言诗、七言诗）
      // 如果文本长度在 4-8 字之间，判定为完整句子，使用句号
      if language == .chinese && textLength >= 4 && textLength <= 8 {
        return "。"
      }
      
      // 一般场景：至少 2 个词才添加标点
      if currentWords.count >= 2 {
        // 如果接近 minWordsForSentence，使用句号
        if currentWords.count >= options.minWordsForSentence - 1 {
          return language == .chinese ? "。" : ". "
        }
        // 否则使用逗号
        return language == .chinese ? "，" : ", "
      }
    } else if gap >= options.shortPauseThreshold {
      return language == .chinese ? "，" : ", "
    }
    
    return ""
  }
  
  /// 判断是否为问句
  /// - Parameters:
  ///   - text: 待判断文本
  ///   - language: 语言类型
  /// - Returns: 是否为问句
  nonisolated static func isQuestion(_ text: String, language: Language) -> Bool {
    if language == .chinese {
      // 中文疑问词
      let questionWords = ["什么", "为什么", "怎么", "如何", "哪里", "谁", "哪", "几", "多少", "是否", "吗", "呢"]
      return questionWords.contains { text.contains($0) }
    } else {
      // 英文疑问词
      let questionWords = ["what", "why", "how", "where", "who", "which", "when", "whose", "whom"]
      let lowercasedText = text.lowercased()
      return questionWords.contains { lowercasedText.hasPrefix($0) }
    }
  }
  
  /// 判断是否为感叹句
  /// - Parameters:
  ///   - text: 待判断文本
  ///   - currentWords: 当前词语列表
  ///   - language: 语言类型
  /// - Returns: 是否为感叹句
  nonisolated static func isExclamation(
    _ text: String,
    currentWords: [String],
    language: Language
  ) -> Bool {
    if language == .chinese {
      // 中文感叹词和语气词
      let exclamationWords = ["太", "真", "好", "哇", "啊", "呀", "哦", "哎呀", "天啊", "糟糕"]
      return currentWords.contains { exclamationWords.contains($0) }
    } else {
      // 英文感叹词
      let exclamationWords = ["wow", "oh", "ah", "great", "amazing", "terrible", "awesome"]
      let lowercasedWords = currentWords.map { $0.lowercased() }
      return exclamationWords.contains { lowercasedWords.contains($0) }
    }
  }
  
  /// 判断是否为句子结束
  /// 
  /// 基于以下规则：
  /// 1. 当前片段词语数量 >= 3(相对完整的句子)
  /// 2. 下一片段以大写字母或新主题开头
  /// 3. 语义连贯性判断
  /// 
  /// - Parameters:
  ///   - currentWords: 当前片段词语列表
  ///   - nextWords: 下一片段词语列表
  ///   - language: 语言类型
  /// - Returns: 是否为句子结束
  nonisolated static func isSentenceEnd(
    currentWords: [String],
    nextWords: [String],
    language: Language
  ) -> Bool {
    // 当前片段词语太少，不太可能是完整句子
    guard currentWords.count >= 3 else { return false }
    
    // 下一片段为空
    guard !nextWords.isEmpty else { return true }
    
    if language == .chinese {
      // 中文：检查是否以连接词开头
      let connectors = ["但是", "然后", "接着", "而且", "并且", "所以", "因此", "不过", "可是"]
      let firstWord = nextWords[0]
      return !connectors.contains(firstWord)
    } else {
      // 英文：检查首字母大写 + 非连接词
      let connectors = ["but", "and", "then", "so", "however", "therefore", "moreover"]
      let firstWord = nextWords[0].lowercased()
      let isCapitalized = nextWords[0].first?.isUppercase ?? false
      return isCapitalized && !connectors.contains(firstWord)
    }
  }
  
  /// 根据停顿时长选择标点符号
  /// - Parameters:
  ///   - gap: 停顿时长(秒)
  ///   - language: 语言类型
  ///   - options: 配置选项
  /// - Returns: 对应的标点符号
  nonisolated static func pickPunctuation(
    for gap: TimeInterval,
    language: Language,
    options: PunctuationRecoveryOptions
  ) -> String {
    // 停顿过短，不添加标点
    guard gap >= options.shortPauseThreshold else {
      return ""
    }
    
    // 超长停顿：句号 + 空格
    if gap >= options.superLongPauseThreshold {
      return language == .chinese ? "。 " : ". "
    }
    
    // 长停顿：句号
    if gap >= options.longPauseThreshold {
      return language == .chinese ? "。" : "."
    }
    
    // 短停顿：逗号
    return language == .chinese ? "，" : ","
  }
  
  /// 清理标点符号（移除多余空格、合并重复标点）
  /// - Parameters:
  ///   - text: 待清理文本
  ///   - language: 语言类型
  /// - Returns: 清理后的文本
  nonisolated static func cleanupPunctuation(
    _ text: String,
    language: Language
  ) -> String {
    var result = text
    
    // 移除标点前的空格
    let punctuations = ["，", "。", "？", "！", ",", ".", "?", "!"]
    for punct in punctuations {
      result = result.replacingOccurrences(of: " \(punct)", with: punct)
    }
    
    // 英文标点后确保单空格（句号、逗号）
    if language == .english {
      let needsSpace = [",", "."]
      for punct in needsSpace {
        // 移除多余空格
        result = result.replacingOccurrences(of: "\(punct)  ", with: "\(punct) ")
        result = result.replacingOccurrences(of: "\(punct)   ", with: "\(punct) ")
        
        // 确保标点后有空格（除非是句末或后续是右括号/引号）
        result = result.replacingOccurrences(of: "\(punct)", with: "\(punct) ")
        result = result.replacingOccurrences(of: "\(punct) )", with: "\(punct))")
        result = result.replacingOccurrences(of: "\(punct) \"", with: "\(punct)\"")
        result = result.replacingOccurrences(of: "\(punct) '", with: "\(punct)'")
      }
    }
    
    // 合并连续标点（优先级：终止符 > 句号 > 分号 > 逗号）
    result = mergeDuplicatePunctuation(result)
    
    // 移除句首标点
    result = result.trimmingCharacters(in: .whitespacesAndNewlines)
    while let first = result.first, punctuations.contains(String(first)) {
      result.removeFirst()
      result = result.trimmingCharacters(in: .whitespaces)
    }
    
    return result
  }
  
  /// 合并重复的标点符号
  /// - Parameter text: 待处理文本
  /// - Returns: 处理后的文本
  nonisolated static func mergeDuplicatePunctuation(_ text: String) -> String {
    var result = text
    
    // 定义标点优先级（数字越大优先级越高）
    let priority: [Character: Int] = [
      "，": 1, ",": 1,
      "。": 2, ".": 2,
      "？": 3, "?": 3,
      "！": 3, "!": 3
    ]
    
    // 合并连续的相同标点
    let duplicates = ["，，", "。。", "？？", "！！", ",,", "..", "??", "!!"]
    for dup in duplicates {
      let single = String(dup.prefix(1))
      result = result.replacingOccurrences(of: dup, with: single)
    }
    
    // 合并不同标点（保留优先级高的）
    let mixedPairs = [
      ("，", ","), ("。", "."), ("？", "?"), ("！", "!"),
      (",", "，"), (".", "。"), ("?", "？"), ("!", "！"),
      ("，", "。"), (",", ".")
    ]
    
    for (p1, p2) in mixedPairs {
      let pair = "\(p1)\(p2)"
      if result.contains(pair) {
        let char1 = p1.first!
        let char2 = p2.first!
        let priority1 = priority[char1] ?? 0
        let priority2 = priority[char2] ?? 0
        let keep = priority1 >= priority2 ? p1 : p2
        result = result.replacingOccurrences(of: pair, with: keep)
      }
    }
    
    return result
  }
}
