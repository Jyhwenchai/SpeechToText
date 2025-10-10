#!/usr/bin/env swift
//
// 验证标点恢复修复效果的测试脚本
// 使用方式：swift VERIFY_FIX.swift
//

import Foundation
import NaturalLanguage

// ===== 复制 TextFormatter 的核心逻辑 =====

enum Language {
    case chinese
    case english
}

struct PunctuationRecoveryOptions {
    let enabled: Bool
    let shortPauseThreshold: Double
    let longPauseThreshold: Double
    let superLongPauseThreshold: Double
    let chineseRatioThreshold: Double
    let preserveExistingPunctuation: Bool
    let enableSemanticMode: Bool
    let minWordsForSentence: Int
    
    static var poetry: PunctuationRecoveryOptions {
        PunctuationRecoveryOptions(
            enabled: true,
            shortPauseThreshold: 0.3,
            longPauseThreshold: 0.6,
            superLongPauseThreshold: 1.0,
            chineseRatioThreshold: 0.5,
            preserveExistingPunctuation: true,
            enableSemanticMode: true,
            minWordsForSentence: 4
        )
    }
    
    static var semanticOnly: PunctuationRecoveryOptions {
        PunctuationRecoveryOptions(
            enabled: true,
            shortPauseThreshold: 0.0,
            longPauseThreshold: 0.0,
            superLongPauseThreshold: 0.0,
            chineseRatioThreshold: 0.3,
            preserveExistingPunctuation: true,
            enableSemanticMode: true,
            minWordsForSentence: 5
        )
    }
}

struct SegmentProxy {
    let text: String
    let start: Double
    let end: Double
}

// 检测语言
func detectLanguage(text: String, threshold: Double) -> Language {
    guard !text.isEmpty else { return .english }
    
    func isCJKCharacter(_ char: Character) -> Bool {
        guard let scalar = char.unicodeScalars.first else { return false }
        let value = scalar.value
        return (value >= 0x4E00 && value <= 0x9FFF) ||
               (value >= 0x3400 && value <= 0x4DBF) ||
               (value >= 0x20000 && value <= 0x2A6DF)
    }
    
    let chineseCount = text.reduce(0) { count, char in
        count + (isCJKCharacter(char) ? 1 : 0)
    }
    
    let ratio = Double(chineseCount) / Double(text.count)
    return ratio > threshold ? .chinese : .english
}

// 提取词语
func extractWords(from text: String) -> [String] {
    let tokenizer = NLTokenizer(unit: .word)
    tokenizer.string = text
    tokenizer.setLanguage(.simplifiedChinese)
    
    var words: [String] = []
    tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
        let word = String(text[tokenRange])
        words.append(word)
        return true
    }
    
    return words
}

// 判断是否为问句
func isQuestion(_ text: String, language: Language) -> Bool {
    if language == .chinese {
        let questionWords = ["什么", "为什么", "怎么", "如何", "哪里", "谁", "哪", "几", "多少", "是否", "吗", "呢"]
        return questionWords.contains { text.contains($0) }
    }
    return false
}

// 判断是否为感叹句
func isExclamation(_ text: String, currentWords: [String], language: Language) -> Bool {
    if language == .chinese {
        let exclamationWords = ["太", "真", "好", "哇", "啊", "呀", "哦", "哎呀", "天啊", "糟糕"]
        return currentWords.contains { exclamationWords.contains($0) }
    }
    return false
}

// 改进后的标点选择逻辑
func pickPunctuationWithNL(
    currentText: String,
    nextText: String,
    currentWords: [String],
    nextWords: [String],
    gap: Double,
    language: Language,
    options: PunctuationRecoveryOptions
) -> String {
    let useSemanticOnly = options.enableSemanticMode
    
    // 1. 检查是否为问句
    if isQuestion(currentText, language: language) {
        if useSemanticOnly || gap >= options.longPauseThreshold {
            return language == .chinese ? "？" : "? "
        }
    }
    
    // 2. 检查是否为感叹句
    if isExclamation(currentText, currentWords: currentWords, language: language) {
        if useSemanticOnly || gap >= options.longPauseThreshold {
            return language == .chinese ? "！" : "! "
        }
    }
    
    // 3. 检查是否为句子结束
    let isSemanticallyComplete = useSemanticOnly 
        ? (currentWords.count >= options.minWordsForSentence)
        : false  // 简化版，不实现完整的 isSentenceEnd
    
    if isSemanticallyComplete {
        if useSemanticOnly || gap >= options.longPauseThreshold {
            return language == .chinese ? "。" : ". "
        }
    }
    
    // 4. 改进后的语义模式逻辑 ⭐
    if useSemanticOnly {
        let textLength = currentText.count
        
        // 诗词场景：5-7 字为一句
        // 如果文本长度在 4-8 字之间，判定为完整句子，使用句号
        if language == .chinese && textLength >= 4 && textLength <= 8 {
            return "。"
        }
        
        // 一般场景
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

// 格式化文本
func formatText(
    text: String,
    segments: [SegmentProxy],
    options: PunctuationRecoveryOptions
) -> String {
    guard options.enabled, !segments.isEmpty else {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    let detectedLanguage = detectLanguage(text: text, threshold: options.chineseRatioThreshold)
    
    var segmentWords: [[String]] = []
    for segment in segments {
        let words = extractWords(from: segment.text)
        segmentWords.append(words)
    }
    
    var result = ""
    
    for (index, segment) in segments.enumerated() {
        let trimmedText = segment.text.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { continue }
        
        result += trimmedText
        
        if index < segments.count - 1 {
            let nextSegment = segments[index + 1]
            let gap = nextSegment.start - segment.end
            
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
    
    return result
}

// ===== 测试用例 =====

print("🧪 验证标点恢复修复效果")
print("=" * 60)

// 测试场景 1：五言诗 - 每句独立片段
print("\n📖 场景 1：五言诗（每句独立片段）")
let poemSegments1: [SegmentProxy] = [
    SegmentProxy(text: "床前明月光", start: 0.0, end: 1.0),
    SegmentProxy(text: "疑是地上霜", start: 1.2, end: 2.2),
    SegmentProxy(text: "举头望明月", start: 2.4, end: 3.4),
    SegmentProxy(text: "低头思故乡", start: 3.6, end: 4.6)
]
let originalText1 = "床前明月光疑是地上霜举头望明月低头思故乡"

print("原文: \(originalText1)")
print("\n诗词模式 (.poetry):")
let result1 = formatText(text: originalText1, segments: poemSegments1, options: .poetry)
print("  结果: \(result1)")
print("  期望: 床前明月光。疑是地上霜。举头望明月。低头思故乡。")
print("  ✅ 测试通过: \(result1 == "床前明月光。疑是地上霜。举头望明月。低头思故乡。")")

// 测试场景 2：连续识别（无停顿间隔）
print("\n📖 场景 2：连续识别（无停顿间隔）")
let poemSegments2: [SegmentProxy] = [
    SegmentProxy(text: "床前明月光", start: 0.0, end: 1.0),
    SegmentProxy(text: "疑是地上霜", start: 1.0, end: 2.0),  // gap = 0
    SegmentProxy(text: "举头望明月", start: 2.0, end: 3.0),  // gap = 0
    SegmentProxy(text: "低头思故乡", start: 3.0, end: 4.0)   // gap = 0
]

print("原文: \(originalText1)")
print("\n纯语义模式 (.semanticOnly) - 无停顿间隔:")
let result2 = formatText(text: originalText1, segments: poemSegments2, options: .semanticOnly)
print("  结果: \(result2)")
print("  期望: 床前明月光。疑是地上霜。举头望明月。低头思故乡。")
print("  ✅ 测试通过: \(result2 == "床前明月光。疑是地上霜。举头望明月。低头思故乡。")")

// 测试场景 3：不同长度的文本
print("\n📖 场景 3：不同长度的文本片段")
let mixedSegments: [SegmentProxy] = [
    SegmentProxy(text: "春眠", start: 0.0, end: 0.5),        // 2字 - 短
    SegmentProxy(text: "不觉晓", start: 0.5, end: 1.0),      // 3字
    SegmentProxy(text: "处处闻啼鸟", start: 1.0, end: 2.0),  // 5字 - 完整句
    SegmentProxy(text: "夜来风雨声", start: 2.0, end: 3.0),  // 5字 - 完整句
    SegmentProxy(text: "花落知多少", start: 3.0, end: 4.0)   // 5字 - 完整句
]
let mixedText = "春眠不觉晓处处闻啼鸟夜来风雨声花落知多少"

print("原文: \(mixedText)")
print("\n诗词模式 (.poetry):")
let result3 = formatText(text: mixedText, segments: mixedSegments, options: .poetry)
print("  结果: \(result3)")
print("  说明: 2-3字片段用逗号，5字片段用句号")

// 显示词语分析
print("\n🔍 词语分析（帮助理解分词结果）:")
for (index, segment) in poemSegments1.enumerated() {
    let words = extractWords(from: segment.text)
    print("  [\(index)] \"\(segment.text)\" → 词数: \(words.count), 词语: \(words)")
}

print("\n" + "=" * 60)
print("✅ 测试完成")

// 辅助函数
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
