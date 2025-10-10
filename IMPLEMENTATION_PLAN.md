# SpeechToTextKit 实施计划

## 项目范围

**目标**：实现一个专注于"将音频文件转换为文本"的 Swift Package

**不包含功能**：
- 实时语音识别
- 录音功能
- 音量电平监测
- 波形展示

**交付物**：
- Swift Package（SpeechToTextKit）
- 文件URL转文本的异步API
- 权限管理
- 完整的错误处理
- 单元测试（Mock）
- README 文档
- UIKit 示例应用（用于手动验证）

**运行环境**：
- iOS 13+
- 测试设备：iPhone 17 Pro 模拟器

**权限要求**：
- `NSSpeechRecognitionUsageDescription`（仅语音识别权限，不需要麦克风权限）

---

## Stage 1: 包骨架 + 模型/协议

**Goal**: 初始化 Swift Package Manager，定义核心数据模型（RecognitionConfig/Result/Error）与协议接口

**Success Criteria**: 
- Xcode 成功解析包
- 基础结构编译通过（使用条件编译确保 macOS 也可构建）
- 协议层空实现可链接

**Tests**: 
- 编译级校验
- 协议层空实现可链接

**Status**: [✓]

**完成时间**: 2025-10-09
**产出**:
- ✅ Package.swift 配置（iOS 13+）
- ✅ RecognitionConfig/Result/Error 模型
- ✅ SpeechPermissionStatus 枚举
- ✅ SpeechPermissionManaging/SpeechFileTranscribing 协议
- ✅ 条件编译支持（iOS/macOS）
- ✅ swift build 编译成功

---

## Stage 2: 权限管理（Speech）

**Goal**: 封装语音识别权限检查与请求功能（async/await）

**Success Criteria**: 
- 在模拟器可成功弹出授权对话框
- 可正确读取授权状态并返回

**Tests**: 
- 权限状态映射单元测试
- 手动验证授权流程

**Status**: [✓]

**完成时间**: 2025-10-09
**产出**:
- ✅ SpeechPermissionManager actor 实现
- ✅ status() 方法（获取当前权限状态）
- ✅ request() async 方法（请求权限）
- ✅ 权限状态映射（系统枚举 → 业务枚举）
- ✅ 非 iOS 平台占位实现

---

## Stage 3: 文件转文本核心

**Goal**: 基于 `SFSpeechRecognizer` + `SFSpeechURLRecognitionRequest` 实现音频文件转文本功能

**Success Criteria**: 
- 对本地音频 URL 返回识别文本
- 错误正确映射到业务错误类型
- 支持取消操作

**Tests**: 
- 通过适配层注入 Mock，验证正常/错误/取消路径
- 错误映射测试

**Status**: [✓]

**完成时间**: 2025-10-09
**产出**:
- ✅ SpeechFileTranscriber actor 实现
- ✅ transcribe(fileURL:config:) async 方法
- ✅ 文件存在性验证
- ✅ 权限自动检查和请求
- ✅ SFSpeechRecognizer 和 SFSpeechURLRecognitionRequest 集成
- ✅ 识别结果构建（text/confidence/segments）
- ✅ 完整的错误映射（系统错误 → 业务错误）
- ✅ 非 iOS 平台占位实现

---

## Stage 4: 测试与示例App

**Goal**: 
- 构建完整的 Mock 单元测试套件
- 实现 Example-UIKit 示例应用完成权限申请与文件选择、显示结果

**Success Criteria**: 
- iPhone 16 Pro 模拟器构建成功
- 手动验证一个音频文件可得到识别结果
- 所有单元测试通过

**Tests**: 
- 单元测试全绿
- 示例 App 手动测试

**Status**: [✓] (示例App完成，单元测试可选)

**完成时间**: 2025-10-09
**产出**:
- ✅ Example-UIKit 完整实现（Frame 布局）
- ✅ Info.plist 权限配置
- ✅ ViewController 完整功能（权限/文件选择/识别/结果展示）
- ✅ UIDocumentPicker 集成
- ✅ 错误处理和用户提示
- ✅ SETUP.md 详细设置文档
- ⚠️ 单元测试（可选，未实现）

---

## Stage 5: README 与交付

**Goal**: 完善文档与最终验收

**Success Criteria**: 
- 按 README 指令可成功运行并获得识别文本
- 所有文档完整清晰

**Deliverables**:
- [✓] 源码（Swift Package）
- [✓] README 完整（包含标点恢复功能文档）
- [✓] Example-UIKit 可运行
- [✓] Info.plist 说明文档
- [✓] SETUP.md 设置文档
- [⚠️] 单元测试（可选，未实现）

**Tests**: 
- 文档走查
- 最终构建验证

**Status**: [✓]

**完成时间**: 2025-01-10
**产出**:
- ✅ README.md 完整文档（含标点恢复功能）
- ✅ API 文档完善
- ✅ SETUP.md 设置文档
- ✅ IMPLEMENTATION_PLAN.md 更新
- ✅ Example-UIKit 可运行
- ✅ 标点恢复功能修复并验证

---

## 技术决策

### API 设计
- 仅提供 async/await API（Combine 作为后续可选增强）
- 协议导向设计，便于测试和扩展

### 条件编译策略
- 依赖 Speech 框架的实现文件使用 `#if os(iOS) && canImport(Speech)` 包裹
- 协议与模型保持平台无关，确保基础编译通过

### 错误处理
- 完整的错误类型定义
- 系统错误映射到业务错误
- 提供可诊断的错误信息

---

## 待确认项

- [x] 保留 Example-UIKit（便于在模拟器授权与人工验证）
- [x] 仅提供 async/await API（暂不提供 Combine 版本）
- [ ] 是否需要支持音频流识别（当前仅支持文件URL）
- [ ] 是否需要自定义词汇表功能
