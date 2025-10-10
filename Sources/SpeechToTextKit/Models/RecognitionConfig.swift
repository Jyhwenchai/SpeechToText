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
  
  /// 初始化识别配置
  /// - Parameters:
  ///   - locale: 识别语言区域，默认为系统当前语言
  ///   - requiresOnDeviceRecognition: 是否要求设备本地识别，默认 false
  ///   - taskHint: 任务提示类型，默认 .unspecified
  public init(
    locale: Locale = .autoupdatingCurrent,
    requiresOnDeviceRecognition: Bool = false,
    taskHint: TaskHint = .unspecified
  ) {
    self.locale = locale
    self.requiresOnDeviceRecognition = requiresOnDeviceRecognition
    self.taskHint = taskHint
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
