# Example-UIKit 设置说明

## 📦 添加 SpeechToTextKit 依赖

由于我们无法通过命令行直接修改 Xcode 项目文件，请按以下步骤手动添加本地包依赖：

### 步骤 1：打开项目

```bash
cd /Users/didong/Desktop/work/project/SpeechToText
open Example-UIKit/Example-UIKit.xcodeproj
```

### 步骤 2：添加本地 Swift Package

1. 在 Xcode 中，选择项目导航器中的 `Example-UIKit` 项目（最顶部的蓝色图标）
2. 选择 `Example-UIKit` target
3. 点击顶部的 `General` 标签页
4. 滚动到 `Frameworks, Libraries, and Embedded Content` 部分
5. 点击 `+` 按钮
6. 选择 `Add Other...` → `Add Package Dependency...`
7. 点击左下角的 `Add Local...` 按钮
8. 导航到 `/Users/didong/Desktop/work/project/SpeechToText` 目录
9. 选择整个 `SpeechToText` 文件夹（包含 Package.swift 的根目录）
10. 点击 `Add Package`
11. 在弹出的产品选择对话框中，确保 `SpeechToTextKit` 被选中
12. 点击 `Add Package`

### 步骤 3：验证集成

确认 `SpeechToTextKit` 出现在：
- Project Navigator 的 `Package Dependencies` 部分
- Target 的 `Frameworks, Libraries, and Embedded Content` 列表中

### 步骤 4：编译项目

1. 选择模拟器：**iPhone 16 Pro**（根据您的规则要求）
2. 按 `Cmd + B` 编译项目
3. 按 `Cmd + R` 运行项目

## ✅ 已配置内容

以下内容已经自动配置完成：

### 1. Info.plist 权限

已添加语音识别权限说明：
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>需要访问语音识别功能以将您的音频文件转换为文本</string>
```

### 2. ViewController 实现

完整实现包括：
- ✅ Frame 布局（无 Auto Layout）
- ✅ 权限请求和状态显示
- ✅ 文件选择（UIDocumentPicker）
- ✅ 音频识别和结果展示
- ✅ 错误处理
- ✅ 中文界面

### 3. 功能特性

- 自动检查权限状态
- 支持请求语音识别权限
- 文件选择器（支持音频和视频文件）
- 实时显示识别状态
- 展示识别文本和置信度
- 完善的错误提示

## 🎯 使用流程

1. **首次启动**：应用会检查权限状态
2. **请求权限**：点击"请求权限"按钮，允许语音识别权限
3. **选择文件**：点击"选择音频文件"按钮，从设备选择音频文件
4. **查看结果**：等待识别完成，查看转换的文本和置信度

## 📱 测试准备

### 准备测试音频文件

您可以使用以下方式准备测试音频：

1. **使用系统录音**：使用 iPhone 的"语音备忘录"录制一段中文音频
2. **从电脑传输**：
   - 在 Finder 中，将音频文件拖到模拟器窗口
   - 文件会保存到"文件"应用中
3. **支持的格式**：.m4a, .wav, .mp3, .aiff 等

### 测试建议

- 音频时长：建议 10-30 秒（较短的音频识别更快）
- 音频质量：清晰的录音效果更好
- 语言配置：当前配置为中文识别（`RecognitionConfig.chinese`）

## 🐛 故障排除

### 问题 1：无法导入 SpeechToTextKit

**解决方案**：
1. 确认包依赖已正确添加
2. Clean Build Folder（Product → Clean Build Folder 或 Shift + Cmd + K）
3. 重新编译项目

### 问题 2：权限被拒绝

**解决方案**：
1. 在模拟器中打开"设置"
2. 找到"Example-UIKit"应用
3. 开启"语音识别"权限
4. 重启应用

### 问题 3：无法选择文件

**解决方案**：
1. 确保已授予语音识别权限
2. 确认"文件"应用中有音频文件
3. 尝试从其他位置选择文件

### 问题 4：识别失败

**检查项**：
- 文件是否损坏
- 文件格式是否支持
- 网络连接是否正常（在线识别需要网络）
- 音频语言是否与配置匹配

## 📝 修改识别语言

如果需要识别英文音频，修改 `ViewController.swift` 第 408 行：

```swift
// 中文识别
let config = RecognitionConfig.chinese

// 改为英文识别
let config = RecognitionConfig.english

// 或自定义配置
let config = RecognitionConfig(
    locale: Locale(identifier: "ja-JP"),  // 日语
    requiresOnDeviceRecognition: false,
    taskHint: .dictation
)
```

## 🚀 下一步

项目已经完全配置好，您只需要：

1. 在 Xcode 中添加 SpeechToTextKit 包依赖（见上方步骤）
2. 选择 iPhone 16 Pro 模拟器
3. 编译并运行
4. 开始测试语音转文本功能！

---

如有问题，请参考主 README.md 或检查 SpeechToTextKit 源码。
