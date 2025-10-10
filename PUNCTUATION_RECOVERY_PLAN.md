# 标点符号智能恢复功能实施计划

## 项目目标

为 SpeechToTextKit 添加智能标点符号恢复功能，基于语音识别的时间片段信息，自动为识别文本添加合理的标点符号，提升文本可读性。

**核心约束**：
- ✅ 保留并优化原有标点符号
- ✅ 支持中文和英文（自动检测）
- ✅ 使用默认停顿时长阈值（可配置）
- ✅ **不进行换行分割**，仅添加标点符号
- ✅ 不改变原词序和语义

## 技术方案

### 方案选择
1. **架构层面**：添加专门的 `TextFormatter` 工具类
2. **模型层面**：在 `RecognitionResult` 中提供 `formattedText` 计算属性
3. **配置层面**：在 `RecognitionConfig` 中添加可选配置项

### 智能标点规则

#### 停顿时长映射（简化版：仅使用逗号和句号）
- **短停顿** (0.3-1.0秒) → 逗号
  - 中文：，
  - 英文：,
- **长停顿** (1.0-2.0秒) → 句号
  - 中文：。
  - 英文：.
- **超长停顿** (>2.0秒) → 句号 + 空格（营造段落感）
  - 中文：。 
  - 英文：.

#### 语言检测
- 统计 CJK 字符占比（Unicode: \u4E00-\u9FFF, \u3400-\u4DBF）
- 占比 > 30% → 中文
- 占比 ≤ 30% → 英文

#### 标点优先级
- 终止符号 (.?!。？！) > 句号(.) > 逗号(,)
- 已存在更强标点时，不追加弱标点

---

## Stage 1: 配置模型定义
**Goal**: 定义标点恢复配置结构

**Success Criteria**: 
- RecognitionConfig 新增配置选项编译通过
- 提供合理的默认值

**Status**: [ ]

**任务清单**:
- [ ] 在 `RecognitionConfig.swift` 中定义 `PunctuationRecoveryOptions` 结构体
- [ ] 添加配置属性：停顿阈值、语言检测阈值、启用开关
- [ ] 提供 `.default` 静态工厂方法
- [ ] 在 `RecognitionConfig` 中添加可选属性 `punctuationRecovery`
- [ ] 完善文档注释

---

## Stage 2: TextFormatter 工具类实现
**Goal**: 实现核心标点恢复算法

**Success Criteria**: 
- 算法正确处理中英文
- 正确保留原有标点
- 按停顿时长合理添加标点
- 不插入换行符

**Status**: [ ]

**任务清单**:
- [ ] 创建 `Sources/SpeechToTextKit/Utilities/TextFormatter.swift`
- [ ] 定义 `SegmentProxy` 轻量数据结构
- [ ] 实现语言检测函数 `detectLanguage(text:)`
- [ ] 实现标点选择函数 `pickPunctuation(for:language:options:)`
- [ ] 实现核心算法 `formatSync(text:segments:options:)`
- [ ] 处理边界情况（空segments、缺失时间戳等）
- [ ] 完善文档注释

---

## Stage 3: RecognitionResult 扩展
**Goal**: 提供便捷的 formattedText 属性

**Success Criteria**: 
- `result.formattedText` 返回格式化后的文本
- 禁用时返回原始 text
- 向后兼容不影响现有功能

**Status**: [ ]

**任务清单**:
- [ ] 在 `RecognitionResult.swift` 中添加 `formattedText` 计算属性
- [ ] 实现 segments 到 SegmentProxy 的转换
- [ ] 调用 TextFormatter.formatSync 处理
- [ ] 处理配置为 nil 或 disabled 的情况
- [ ] 完善文档注释

---

## Stage 4: 示例应用集成
**Goal**: 在 Example-UIKit 中展示新功能

**Success Criteria**: 
- 示例应用可切换显示原始/格式化文本
- UI 布局合理美观
- 用户体验流畅

**Status**: [ ]

**任务清单**:
- [ ] 在 ViewController 中添加 UISegmentedControl（原始/格式化）
- [ ] 实现切换逻辑，动态更新显示内容
- [ ] 调整布局以容纳新控件
- [ ] 默认选中"格式化"模式
- [ ] 测试切换功能

---

## Stage 5: 单元测试
**Goal**: 确保功能正确性和稳定性

**Success Criteria**: 
- 所有测试用例通过
- 覆盖中英文场景
- 覆盖边界情况

**Status**: [ ]

**任务清单**:
- [ ] 创建 `TextFormatterTests.swift`
- [ ] 测试语言检测（边界阈值）
- [ ] 测试停顿区间映射
- [ ] 测试原标点保留
- [ ] 测试连续标点合并
- [ ] 测试中英文空格规则
- [ ] 测试禁用配置
- [ ] 测试无时间戳情况
- [ ] 断言无换行符插入

---

## Stage 6: 手动验证与文档
**Goal**: 完整验证功能并完善文档

**Success Criteria**: 
- iPhone 16 Pro 模拟器运行正常
- 实际音频测试效果良好
- 文档完整清晰

**Status**: [ ]

**任务清单**:
- [ ] 在模拟器上编译运行
- [ ] 使用真实音频文件测试
- [ ] 验证中文音频效果
- [ ] 验证英文音频效果
- [ ] 对比原始/格式化文本可读性
- [ ] 更新 README.md 说明新功能
- [ ] 更新 DELIVERY_SUMMARY.md

---

## 提交策略

建议分6次增量提交：

1. **feat(config): 新增标点恢复配置模型**
   ```
   在 RecognitionConfig 中新增 PunctuationRecoveryOptions 结构体，
   定义停顿阈值、语言检测阈值等配置项，提供合理的默认值。
   支持通过配置控制标点恢复行为。
   ```

2. **feat(formatter): 实现 TextFormatter 核心算法**
   ```
   新增 TextFormatter 工具类，实现基于时间片段的智能标点恢复。
   支持中英文自动检测、停顿时长映射、原标点保留等功能。
   采用纯函数设计，确保线程安全。
   ```

3. **feat(model): RecognitionResult 新增 formattedText**
   ```
   在 RecognitionResult 中添加 formattedText 计算属性，
   自动调用 TextFormatter 生成格式化文本。
   保持向后兼容，不影响现有 text 属性。
   ```

4. **feat(example): 示例应用支持格式化文本展示**
   ```
   在 Example-UIKit 中添加原始/格式化文本切换功能，
   默认展示格式化文本，用户可实时对比效果。
   调整 UI 布局以容纳切换控件。
   ```

5. **test: 添加 TextFormatter 单元测试**
   ```
   覆盖中英文语言检测、停顿映射、标点优先级、
   边界情况等核心场景，确保功能正确性。
   ```

6. **docs: 更新文档说明标点恢复功能**
   ```
   在 README 和 DELIVERY_SUMMARY 中说明新增的智能标点恢复功能，
   包括使用方法、配置选项和效果展示。
   ```

---

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| segments 时间单位不一致 | 标点位置错误 | 在适配层统一转换为秒 |
| 语言混合文本 | 标点类型混乱 | 使用全局语言判定 |
| 已有密集标点 | 重复添加 | 检测并保留原标点 |
| 性能影响 | 格式化耗时 | 使用纯函数算法，O(n)复杂度 |

**回退方案**：
- 用户可通过 `enabled=false` 或 `punctuationRecovery=nil` 禁用功能
- 直接使用 `result.text` 获取原始文本

---

## 验收标准

- [x] 编译无警告
- [ ] 所有单元测试通过
- [ ] 中文音频文本可读性显著提升
- [ ] 英文音频文本可读性显著提升
- [ ] 原有标点得到保留和优化
- [ ] 未引入换行符
- [ ] 示例应用切换功能正常
- [ ] 文档完整准确

---

## 参考资料

- 现有实现计划：`IMPLEMENTATION_PLAN.md`
- 项目规范：遵循团队规则（2空格缩进、中文注释）
- 测试环境：iPhone 16 Pro 模拟器
