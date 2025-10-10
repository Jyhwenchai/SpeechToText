//
//  RecognitionConfig.swift
//  SpeechToTextKit
//
//  语音识别配置模型
//

import Foundation

/// 语音识别任务提示类型
public enum TaskHint: Sendable {
  /// 未指定
  case unspecified
  /// 听写
  case dictation
  /// 搜索
  case search
  /// 确认
  case confirmation
}

/// 标点符号恢复配置选项
public struct PunctuationRecoveryOptions: Sendable, Equatable {
  /// 是否启用标点符号恢复
  /// 默认：true
  public let enabled: Bool
  
  /// 短停顿阈值（秒）
  /// 默认：0.8 秒
  /// 停顿时长 >= 此值且 < longPauseThreshold 时添加逗号
  /// 对应标点：中文（，）英文（,）
  public let shortPauseThreshold: Double
  
  /// 长停顿阈值（秒）
  /// 默认：1.5 秒
  /// 停顿时长 >= 此值且 < superLongPauseThreshold 时添加句号
  /// 对应标点：中文（。）英文（.）
  public let longPauseThreshold: Double
  
  /// 超长停顿阈值（秒）
  /// 默认：2.5 秒
  /// 停顿时长 >= 此值时添加句号+空格，营造段落感
  public let superLongPauseThreshold: Double
  
  /// 中文字符占比阈值（用于语言检测）
  /// 默认：0.3（30%）
  /// 文本中 CJK 字符占比超过此值判定为中文，否则判定为英文
  public let chineseRatioThreshold: Double
  
  /// 是否保留原有标点符号
  /// 默认：true
  /// 启用时，已存在的标点符号会被保留和优化，不会重复添加
  public let preserveExistingPunctuation: Bool
  
  /// 是否启用纯语义模式
  /// 默认：false
  /// 启用时，即使没有停顿时间或停顿时间不足，也会基于语义分析插入标点
  /// 适用于：古诗词、连续文本、时间信息不准确的场景
  public let enableSemanticMode: Bool
  
  /// 语义模式下的最小词语数（用于判断句子完整性）
  /// 默认：5
  /// 当一个片段的词语数 >= 此值时，认为是相对完整的句子
  public let minWordsForSentence: Int
  
  /// 初始化标点符号恢复配置
  /// - Parameters:
  ///   - enabled: 是否启用，默认 true
  ///   - shortPauseThreshold: 短停顿阈值（逗号），默认 0.8 秒
  ///   - longPauseThreshold: 长停顿阈值（句号），默认 1.5 秒
  ///   - superLongPauseThreshold: 超长停顿阈值，默认 2.5 秒
  ///   - chineseRatioThreshold: 中文字符占比阈值，默认 0.3
  ///   - preserveExistingPunctuation: 是否保留原有标点，默认 true
  ///   - enableSemanticMode: 是否启用纯语义模式，默认 false
  ///   - minWordsForSentence: 语义模式下的最小词语数，默认 5
  public init(
    enabled: Bool = true,
    shortPauseThreshold: Double = 0.8,
    longPauseThreshold: Double = 1.5,
    superLongPauseThreshold: Double = 2.5,
    chineseRatioThreshold: Double = 0.3,
    preserveExistingPunctuation: Bool = true,
    enableSemanticMode: Bool = false,
    minWordsForSentence: Int = 5
  ) {
    self.enabled = enabled
    self.shortPauseThreshold = shortPauseThreshold
    self.longPauseThreshold = longPauseThreshold
    self.superLongPauseThreshold = superLongPauseThreshold
    self.chineseRatioThreshold = chineseRatioThreshold
    self.preserveExistingPunctuation = preserveExistingPunctuation
    self.enableSemanticMode = enableSemanticMode
    self.minWordsForSentence = minWordsForSentence
  }
  
  /// 默认配置
  public static var `default`: PunctuationRecoveryOptions {
    PunctuationRecoveryOptions()
  }
  
  /// 诗词断句配置
  /// 适用于古诗词、现代诗等需要基于韵律和语义断句的场景
  public static var poetry: PunctuationRecoveryOptions {
    PunctuationRecoveryOptions(
      enabled: true,
      shortPauseThreshold: 0.3,
      longPauseThreshold: 0.6,
      superLongPauseThreshold: 1.0,
      chineseRatioThreshold: 0.5,
      preserveExistingPunctuation: true,
      enableSemanticMode: true,
      minWordsForSentence: 4  // 诗词一般 5-7 字一句
    )
  }
  
  /// 纯语义分析配置
  /// 适用于没有时间信息或时间信息不准确的场景
  public static var semanticOnly: PunctuationRecoveryOptions {
    PunctuationRecoveryOptions(
      enabled: true,
      shortPauseThreshold: 0.0,  // 忽略停顿时长
      longPauseThreshold: 0.0,
      superLongPauseThreshold: 0.0,
      chineseRatioThreshold: 0.3,
      preserveExistingPunctuation: true,
      enableSemanticMode: true,
      minWordsForSentence: 5
    )
  }
}

/// 语音识别配置
public struct RecognitionConfig: Sendable {
  /// 识别语言区域
  /// 默认：Locale.autoupdatingCurrent（系统当前语言）
  public let locale: Locale
  
  /// 是否要求设备本地识别（离线识别）
  /// 默认：false（使用在线识别，准确率更高）
  public let requiresOnDeviceRecognition: Bool
  
  /// 任务提示，帮助优化识别结果
  /// 默认：.unspecified
  public let taskHint: TaskHint
  
  /// 标点符号恢复配置
  /// 默认：nil（使用默认配置）
  /// 设置为 nil 或 enabled = false 可禁用标点符号恢复功能
  public let punctuationRecovery: PunctuationRecoveryOptions?
  
  /// 初始化识别配置
  /// - Parameters:
  ///   - locale: 识别语言区域，默认为系统当前语言
  ///   - requiresOnDeviceRecognition: 是否要求设备本地识别，默认 false
  ///   - taskHint: 任务提示类型，默认 .unspecified
  ///   - punctuationRecovery: 标点符号恢复配置，默认 nil（使用默认配置）
  public init(
    locale: Locale = .autoupdatingCurrent,
    requiresOnDeviceRecognition: Bool = false,
    taskHint: TaskHint = .unspecified,
    punctuationRecovery: PunctuationRecoveryOptions? = nil
  ) {
    self.locale = locale
    self.requiresOnDeviceRecognition = requiresOnDeviceRecognition
    self.taskHint = taskHint
    self.punctuationRecovery = punctuationRecovery
  }
  
  /// 创建中文识别配置
  public static var chinese: RecognitionConfig {
    RecognitionConfig(
      locale: Locale(identifier: "zh-CN"),
      requiresOnDeviceRecognition: false,
      taskHint: .dictation
    )
  }
  
  /// 创建英文识别配置
  public static var english: RecognitionConfig {
    RecognitionConfig(
      locale: Locale(identifier: "en-US"),
      requiresOnDeviceRecognition: false,
      taskHint: .dictation
    )
  }
}
