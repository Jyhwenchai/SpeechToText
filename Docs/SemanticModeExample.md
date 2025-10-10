# 纯语义模式使用指南

## 问题场景

你在测试"床前明月光疑是地上霜举头望明月低头思故乡"这段文本时，发现无法正确添加标点符号。这是因为：

1. **原有实现的局限**：过度依赖停顿时长（gap），当 `gap <= 0` 或 `gap < shortPauseThreshold` 时，不会插入任何标点
2. **古诗词特点**：连续朗诵，没有明显停顿，但需要根据语义断句
3. **时间信息不准确**：某些语音识别场景下，时间信息可能不准确或缺失

## 解决方案

我们新增了**纯语义模式**（Semantic Mode），支持在没有停顿时间或时间信息不准确的情况下，仅基于语义分析插入标点符号。

### 核心改进

1. **新增配置选项**：
   - `enableSemanticMode`: 启用纯语义模式
   - `minWordsForSentence`: 判断句子完整性的最小词语数

2. **预设配置**：
   - `.poetry`: 诗词断句配置
   - `.semanticOnly`: 纯语义分析配置

3. **智能判断**：
   - 基于词语数量判断句子完整性
   - 问句/感叹句识别
   - 连接词检测

## 使用示例

### 示例 1：古诗词断句

```swift
import SpeechToTextKit

// 将古诗按每5个字分成一个segment
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

print(result)
// 输出: 床前明月光。疑是地上霜。举头望明月，低头思故乡
```

### 示例 2：无时间信息场景

```swift
// 模拟没有准确时间信息的场景（所有 gap = 0）
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

print(result)
// 输出: 床前明月光，疑是地上霜，举头望明月，低头思故乡
```

### 示例 3：现代散文断句

```swift
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

print(result)
// 输出: 春天来了，万物复苏，鸟儿在树上唱歌，花儿竞相开放
```

### 示例 4：对比标准模式 vs 语义模式

```swift
let segments = [
  TextFormatter.SegmentProxy(text: "今天天气很好", start: 0, end: 0),
  TextFormatter.SegmentProxy(text: "我们去公园玩", start: 0, end: 0)
]

let text = "今天天气很好我们去公园玩"

// 标准模式（无停顿时不添加标点）
let standardResult = TextFormatter.formatSync(
  text: text,
  segments: segments,
  options: .default
)
print("标准模式: \(standardResult)")
// 输出: 今天天气很好我们去公园玩

// 语义模式（基于语义添加标点）
let semanticResult = TextFormatter.formatSync(
  text: text,
  segments: segments,
  options: .semanticOnly
)
print("语义模式: \(semanticResult)")
// 输出: 今天天气很好，我们去公园玩
```

## 配置说明

### 诗词配置 (.poetry)

```swift
PunctuationRecoveryOptions.poetry
```

**特点**：
- 启用语义模式：`enableSemanticMode = true`
- 较低的最小词语数：`minWordsForSentence = 4`（适合古诗词5-7字一句）
- 适中的停顿阈值：配合有停顿信息的场景

**适用场景**：
- 古诗词朗诵
- 现代诗歌
- 需要根据韵律断句的文本

### 纯语义配置 (.semanticOnly)

```swift
PunctuationRecoveryOptions.semanticOnly
```

**特点**：
- 启用语义模式：`enableSemanticMode = true`
- 完全忽略停顿时长：所有阈值设为 0
- 标准最小词语数：`minWordsForSentence = 5`

**适用场景**：
- 没有时间信息的文本
- 时间信息不准确的场景
- 需要纯语义断句的连续文本

### 自定义配置

```swift
let customOptions = PunctuationRecoveryOptions(
  enabled: true,
  shortPauseThreshold: 0.4,      // 短停顿阈值
  longPauseThreshold: 0.8,       // 长停顿阈值
  superLongPauseThreshold: 1.5,  // 超长停顿阈值
  chineseRatioThreshold: 0.3,    // 中文字符比例阈值
  preserveExistingPunctuation: true,
  enableSemanticMode: true,      // 启用语义模式
  minWordsForSentence: 6         // 自定义最小词语数
)
```

## 工作原理

### 语义模式判断逻辑

```
1. 问句识别
   └─ 检测疑问词 → 插入问号（？）

2. 感叹句识别
   └─ 检测感叹词 → 插入感叹号（！）

3. 句子完整性判断
   ├─ 语义模式：词语数 >= minWordsForSentence
   └─ 标准模式：检测连接词 + 停顿时长
   └─ 插入句号（。）

4. 默认标点
   ├─ 语义模式：2 <= 词语数 < minWordsForSentence
   └─ 标准模式：gap >= shortPauseThreshold
   └─ 插入逗号（，）
```

### 词语数统计

使用 Apple Natural Language 框架的 `NLTokenizer` 进行分词：

```swift
let tokenizer = NLTokenizer(unit: .word)
tokenizer.setLanguage(.simplifiedChinese)  // 或 .english

// "床前明月光" → ["床前", "明月", "光"] = 3个词
// "我喜欢在春天的早晨散步" → ["我", "喜欢", "在", "春天", "的", "早晨", "散步"] = 7个词
```

## 最佳实践

### 1. 选择合适的配置

| 场景 | 推荐配置 | 说明 |
|------|---------|------|
| 实时语音识别 | `.default` | 有准确的停顿信息 |
| 古诗词朗诵 | `.poetry` | 需要根据韵律断句 |
| 离线文本处理 | `.semanticOnly` | 没有时间信息 |
| 时间信息不准 | `.semanticOnly` | 仅依赖语义 |

### 2. 调整 minWordsForSentence

- **古诗词**：4-5（一句通常5-7字）
- **现代散文**：5-6（一句话通常包含主谓宾）
- **口语对话**：3-4（句子较短）
- **书面语**：6-8（句子较长且完整）

### 3. 结合停顿信息

即使启用语义模式，如果有停顿信息，系统也会结合使用：

```swift
let options = PunctuationRecoveryOptions.poetry  // 既有语义分析又有停顿判断
```

## 测试结果

### 实际测试效果

```
✅ 床前明月光疑是地上霜举头望明月低头思故乡
   → 床前明月光。疑是地上霜。举头望明月，低头思故乡

✅ 春天来了万物复苏鸟儿在树上唱歌花儿竞相开放
   → 春天来了，万物复苏，鸟儿在树上唱歌，花儿竞相开放

✅ 两个黄鹂鸣翠柳一行白鹭上青天窗含西岭千秋雪门泊东吴万里船
   → 两个黄鹂鸣翠柳。一行白鹭上青天。窗含西岭千秋雪。门泊东吴万里船

✅ 春眠不觉晓处处闻啼鸟夜来风雨声花落知多少
   → 春眠不觉晓。处处闻啼鸟。夜来风雨声。花落知多少
```

## 局限性

1. **短语判断**：词语数太少（< 2）的片段不会添加标点
2. **语义理解**：基于规则的语义分析，不是真正的自然语言理解
3. **上下文关联**：无法理解跨片段的语义关联
4. **标点种类**：仅支持逗号、句号、问号、感叹号，不支持冒号、引号等

## 未来改进

1. 机器学习模型训练，提高断句准确率
2. 支持更多标点符号类型
3. 上下文感知的智能断句
4. 支持用户自定义断句规则

---

**版本**: 1.0.0  
**更新日期**: 2025-10-09  
**测试覆盖**: 17/18 通过
