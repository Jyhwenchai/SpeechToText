//
//  RecognitionResult.swift
//  SpeechToTextKit
//
//  语音识别结果模型
//

import Foundation

/// 识别文本片段
public struct RecognitionSegment: Sendable, Equatable {
  /// 片段文本内容
  public let text: String
  
  /// 片段时间戳（秒）
  public let timestamp: Double
  
  /// 片段持续时间（秒）
  public let duration: Double
  
  /// 片段置信度（0.0 - 1.0）
  public let confidence: Double
  
  public init(
    text: String,
    timestamp: Double,
    duration: Double,
    confidence: Double
  ) {
    self.text = text
    self.timestamp = timestamp
    self.duration = duration
    self.confidence = confidence
  }
}

/// 语音识别结果
public struct RecognitionResult: Sendable, Equatable {
  /// 完整的识别文本
  public let text: String
  
  /// 总体置信度（0.0 - 1.0）
  /// 如果无法计算，则为 nil
  public let confidence: Double?
  
  /// 识别文本片段（可选）
  /// 包含每个词或短语的详细信息
  public let segments: [RecognitionSegment]?
  
  /// 识别所用语言区域
  public let locale: Locale?
  
  /// 初始化识别结果
  /// - Parameters:
  ///   - text: 完整的识别文本
  ///   - confidence: 总体置信度，如无法计算则为 nil
  ///   - segments: 识别文本片段，可选
  ///   - locale: 识别所用语言区域，可选
  public init(
    text: String,
    confidence: Double? = nil,
    segments: [RecognitionSegment]? = nil,
    locale: Locale? = nil
  ) {
    self.text = text
    self.confidence = confidence
    self.segments = segments
    self.locale = locale
  }
  
  /// 格式化后的识别文本（添加智能标点符号）
  /// 
  /// 基于时间片段信息自动添加标点符号，提升文本可读性。
  /// 
  /// ## 特性
  /// - 自动检测中英文，使用相应标点符号
  /// - 根据停顿时长智能添加逗号、分号、句号
  /// - 保留并优化原有标点符号，不重复添加
  /// - **不插入换行符**，仅添加标点
  /// - 不改变原词序和语义
  /// 
  /// ## 配置
  /// 使用默认配置 `PunctuationRecoveryOptions.default`。
  /// 如需自定义配置，请使用 `formattedText(with:)` 方法。
  /// 
  /// ## 示例
  /// ```swift
  /// let result = try await transcriber.transcribe(fileURL: url, config: .chinese)
  /// print("原始文本：", result.text)
  /// print("格式化文本：", result.formattedText)
  /// ```
  /// 
  /// - Note: 如果 segments 为空或 nil，返回原始 text
  @available(iOS 13.0, macOS 10.15, *)
  public var formattedText: String {
    formattedText(with: .default)
  }
  
  /// 格式化文本（带标点）
  /// - Parameter options: 标点符号恢复配置
  /// - Returns: 格式化后的文本
  @available(iOS 13.0, macOS 10.15, *)
  public func formattedText(with options: PunctuationRecoveryOptions) -> String {
    // 检查配置是否启用
    guard options.enabled else {
      return text
    }
    
    // 检查是否有 segments
    guard let segments = segments, !segments.isEmpty else {
      return text
    }
    
    // 将 RecognitionSegment 转换为 TextFormatter.SegmentProxy
    let proxies = segments.map { segment in
      TextFormatter.SegmentProxy(
        text: segment.text,
        start: segment.timestamp,
        end: segment.timestamp + segment.duration
      )
    }
    
    // 调用 TextFormatter 格式化
    return TextFormatter.formatSync(
      text: text,
      segments: proxies,
      options: options
    )
  }
}
