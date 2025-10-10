//
//  RecognitionError.swift
//  SpeechToTextKit
//
//  语音识别错误类型定义
//

import Foundation

/// 语音识别错误
public enum RecognitionError: Error, Equatable, Sendable {
  // MARK: - 权限相关错误
  
  /// 权限状态未确定（用户尚未授权或拒绝）
  case notDetermined
  
  /// 权限被拒绝
  case denied
  
  /// 权限受限（例如家长控制）
  case restricted
  
  // MARK: - 系统相关错误
  
  /// 语音识别服务不可用
  case notAvailable
  
  /// 不支持的语言区域
  case localeUnsupported
  
  // MARK: - 文件相关错误
  
  /// 音频文件不存在
  case fileNotFound
  
  /// 无效的音频文件格式
  case invalidFile
  
  // MARK: - 操作相关错误
  
  /// 识别操作被取消
  case cancelled
  
  /// 其他底层错误
  case underlying(message: String)
}

// MARK: - CustomStringConvertible

extension RecognitionError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .notDetermined:
      return "语音识别权限状态未确定"
    case .denied:
      return "语音识别权限被拒绝"
    case .restricted:
      return "语音识别权限受限"
    case .notAvailable:
      return "语音识别服务不可用"
    case .localeUnsupported:
      return "不支持的语言区域"
    case .fileNotFound:
      return "音频文件不存在"
    case .invalidFile:
      return "无效的音频文件格式"
    case .cancelled:
      return "识别操作被取消"
    case .underlying(let message):
      return "识别错误: \(message)"
    }
  }
}

// MARK: - LocalizedError

extension RecognitionError: LocalizedError {
  public var errorDescription: String? {
    description
  }
  
  public var failureReason: String? {
    switch self {
    case .notDetermined:
      return "用户尚未授权语音识别权限"
    case .denied:
      return "用户拒绝了语音识别权限请求"
    case .restricted:
      return "设备限制了语音识别功能（可能是家长控制或其他限制）"
    case .notAvailable:
      return "系统语音识别服务当前不可用，可能是网络问题或系统限制"
    case .localeUnsupported:
      return "当前语言区域不支持语音识别"
    case .fileNotFound:
      return "指定的音频文件路径不存在"
    case .invalidFile:
      return "音频文件格式不正确或已损坏"
    case .cancelled:
      return "用户或系统取消了识别操作"
    case .underlying(let message):
      return message
    }
  }
  
  public var recoverySuggestion: String? {
    switch self {
    case .notDetermined, .denied:
      return "请在系统设置中允许应用使用语音识别功能"
    case .restricted:
      return "请检查设备的家长控制或其他限制设置"
    case .notAvailable:
      return "请检查网络连接，或稍后再试"
    case .localeUnsupported:
      return "请尝试使用其他支持的语言区域"
    case .fileNotFound:
      return "请确认文件路径正确"
    case .invalidFile:
      return "请使用支持的音频格式（如 m4a, wav, mp3 等）"
    case .cancelled:
      return nil
    case .underlying:
      return "请稍后重试，如问题持续请联系技术支持"
    }
  }
}
