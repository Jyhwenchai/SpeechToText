# Natural Language 增强 - 智能标点符号恢复

## 概述

本文档介绍了 TextFormatter 使用 Apple Natural Language 框架实现的智能标点符号恢复功能。该功能结合了语义分析和停顿时长，能够更准确地在语音识别文本中插入标点符号。

## 功能特性

### 1. 智能分词

使用 `NLTokenizer` 对文本进行分词处理，支持中英文自动识别：

```swift
let tokenizer = NLTokenizer(unit: .word)
tokenizer.setLanguage(.simplifiedChinese)  // 或 .english
```

### 2. 问句识别

#### 中文问句
识别常见疑问词：
- 什么、为什么、怎么、如何
- 哪里、谁、哪、几、多少
- 是否、吗、呢

#### 英文问句
识别疑问词开头：
- what, why, how, where
- who, which, when, whose, whom

**示例**：
```swift
输入: "What is your name"
输出: "What is your name?"  // 自动添加问号
```

### 3. 感叹句识别

#### 中文感叹词
- 太、真、好
- 哇、啊、呀、哦
- 哎呀、天啊、糟糕

#### 英文感叹词
- wow, oh, ah
- great, amazing, terrible, awesome

**示例**：
```swift
输入: "太好了"
输出: "太好了！"  // 自动添加感叹号
```

### 4. 句子边界检测

基于以下规则判断句子结束：
1. 当前片段词语数量 >= 3（相对完整的句子）
2. 下一片段以大写字母或新主题开头（英文）
3. 语义连贯性判断（检测连接词）

**中文连接词**：但是、然后、接着、而且、并且、所以、因此、不过、可是

**英文连接词**：but, and, then, so, however, therefore, moreover

**示例**：
```swift
输入: "我喜欢编程它很有趣"
输出: "我喜欢编程。它很有趣"  // 自动识别句子边界
```

### 5. 停顿时长配合

标点符号的插入结合了停顿时长和语义分析：

| 停顿时长 | 语义判断 | 插入标点 |
|---------|---------|---------|
| 短 (0.3s+) | - | 逗号 |
| 长 (0.8s+) | 问句 | 问号 |
| 长 (0.8s+) | 感叹句 | 感叹号 |
| 长 (0.8s+) | 句子结束 | 句号 |
| 超长 (1.5s+) | - | 句号 + 空格 |

## 使用方法

### 基本用法

```swift
import SpeechToTextKit

let segments = [
  TextFormatter.SegmentProxy(text: "你叫什么名字", start: 0, end: 2.0),
  TextFormatter.SegmentProxy(text: "我叫小明", start: 3.0, end: 5.0)
]

let options = PunctuationRecoveryOptions.default
let result = TextFormatter.formatSync(
  text: "你叫什么名字我叫小明",
  segments: segments,
  options: options
)

print(result)  // "你叫什么名字？我叫小明"
```

### 自定义配置

```swift
let options = PunctuationRecoveryOptions(
  enabled: true,
  shortPauseThreshold: 0.3,      // 短停顿阈值（秒）
  longPauseThreshold: 0.8,       // 长停顿阈值（秒）
  superLongPauseThreshold: 1.5,  // 超长停顿阈值（秒）
  chineseRatioThreshold: 0.3,    // 中文字符比例阈值
  preserveExistingPunctuation: true  // 保留现有标点
)
```

## 技术实现

### 核心方法

#### 1. extractWords
```swift
/// 使用 NLTokenizer 提取文本中的词语
nonisolated static func extractWords(
  from text: String,
  tokenizer: NLTokenizer
) -> [String]
```

#### 2. pickPunctuationWithNL
```swift
/// 使用 Natural Language 语义分析结合停顿时长选择标点
nonisolated static func pickPunctuationWithNL(
  currentText: String,
  nextText: String,
  currentWords: [String],
  nextWords: [String],
  gap: Double,
  language: Language,
  options: PunctuationRecoveryOptions
) -> String
```

#### 3. 辅助判断方法
- `isQuestion(_:language:)` - 判断是否为问句
- `isExclamation(_:currentWords:language:)` - 判断是否为感叹句
- `isSentenceEnd(currentWords:nextWords:language:)` - 判断是否为句子结束

### 架构设计

```
TextFormatter.formatSync()
    ↓
检测语言 (中文/英文)
    ↓
使用 NLTokenizer 分词
    ↓
遍历 segments
    ↓
pickPunctuationWithNL()
    ├─→ isQuestion()      → 问号 (?)
    ├─→ isExclamation()   → 感叹号 (!)
    ├─→ isSentenceEnd()   → 句号 (.)
    └─→ gap >= threshold  → 逗号 (,)
    ↓
清理标点 (去除重复和多余空格)
```

## 性能优化

1. **纯函数设计**：`formatSync()` 是纯函数，线程安全
2. **单次分词**：每个 segment 只分词一次，结果缓存使用
3. **惰性评估**：优先级判断（问句 > 感叹句 > 句子结束 > 逗号）

## 测试覆盖

项目包含完整的单元测试套件：

- ✅ 中文问句识别
- ✅ 英文问句识别
- ✅ 中文感叹句识别
- ✅ 英文感叹句识别
- ✅ 中文句子边界检测
- ✅ 英文句子边界检测
- ✅ 短停顿添加逗号
- ✅ 长停顿添加句号
- ✅ 保留现有标点
- ✅ 空segments处理
- ✅ 禁用标点恢复
- ✅ 混合中英文

测试文件：`Tests/SpeechToTextKitTests/TextFormatterTests.swift`

## 兼容性

- **iOS**: 13.0+
- **macOS**: 10.15+
- **框架**: Natural Language (Apple)
- **语言支持**: 中文（简体）、英文

## 最佳实践

### 1. 选择合适的阈值

不同场景需要不同的停顿阈值：

```swift
// 快速对话场景
let quickOptions = PunctuationRecoveryOptions(
  enabled: true,
  shortPauseThreshold: 0.2,
  longPauseThreshold: 0.6,
  superLongPauseThreshold: 1.0,
  chineseRatioThreshold: 0.3,
  preserveExistingPunctuation: true
)

// 正式演讲场景
let formalOptions = PunctuationRecoveryOptions(
  enabled: true,
  shortPauseThreshold: 0.4,
  longPauseThreshold: 1.0,
  superLongPauseThreshold: 2.0,
  chineseRatioThreshold: 0.3,
  preserveExistingPunctuation: true
)
```

### 2. 保留现有标点

建议始终启用 `preserveExistingPunctuation`，避免覆盖用户已有的标点符号。

### 3. 混合语言处理

对于中英文混合文本，系统会根据 `chineseRatioThreshold` 自动判断主要语言：
- 中文字符占比 > 30% → 使用中文规则
- 中文字符占比 ≤ 30% → 使用英文规则

## 未来改进

### 计划中的功能
1. 支持更多语言（日文、韩文等）
2. 机器学习模型训练，提高准确率
3. 用户自定义词典支持
4. 上下文感知的标点选择

### 已知限制
1. 不支持省略号（...）和破折号（——）的自动插入
2. 引号配对需要额外处理
3. 数字和标点的组合（如日期、时间）可能需要优化

## 参考资料

- [Apple Natural Language Framework](https://developer.apple.com/documentation/naturallanguage)
- [NLTokenizer Documentation](https://developer.apple.com/documentation/naturallanguage/nltokenizer)
- [Speech Recognition Best Practices](https://developer.apple.com/documentation/speech)

## 更新日志

### v1.0.0 (2025-10-09)
- ✨ 新增：基于 Natural Language 的智能标点恢复
- ✨ 新增：问句和感叹句自动识别
- ✨ 新增：句子边界智能检测
- ✨ 新增：中英文混合处理
- ✅ 新增：完整的单元测试套件
- 📝 新增：详细的文档和使用示例

---

**作者**: SpeechToTextKit Team  
**最后更新**: 2025-10-09  
**版本**: 1.0.0
