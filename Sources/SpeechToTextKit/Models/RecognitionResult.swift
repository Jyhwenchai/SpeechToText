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
}
