// 详细调试测试代码
// 将此代码添加到你的 ViewController 中

import SpeechToTextKit

@objc private func debugPoetryAudio() {
    Task {
        do {
            guard let audioURL = Bundle.main.url(forResource: "test", withExtension: "m4a") else {
                print("❌ 找不到 test.m4a 文件")
                return
            }
            
            print("📁 音频文件: \(audioURL.path)")
            print("========================================\n")
            
            // 步骤1：先获取原始识别结果（不使用标点恢复）
            print("🔍 步骤1：获取原始识别结果（无标点恢复）")
            print("========================================")
            let configRaw = RecognitionConfig(
                locale: Locale(identifier: "zh-CN"),
                punctuationRecovery: nil  // 禁用标点恢复
            )
            
            let transcriberRaw = SpeechFileTranscriber()
            let resultRaw = try await transcriberRaw.transcribe(fileURL: audioURL, config: configRaw)
            
            print("原始文本: \(resultRaw.formattedText)")
            print("片段数量: \(resultRaw.segments.count)")
            print("置信度: \(resultRaw.confidence ?? 0)")
            print("\n详细片段信息:")
            
            // 打印每个片段的详细信息
            for (index, segment) in resultRaw.segments.enumerated() {
                let gap = index < resultRaw.segments.count - 1 
                    ? resultRaw.segments[index + 1].start - segment.end 
                    : 0
                
                let duration = segment.end - segment.start
                
                print("  [\(index)] 时间: \(String(format: "%5.2f", segment.start))s - \(String(format: "%5.2f", segment.end))s")
                print("       时长: \(String(format: "%.2f", duration))s | 间隔: \(String(format: "%.2f", gap))s")
                print("       文本: \"\(segment.text)\"")
                print("       置信度: \(String(format: "%.2f", segment.confidence))")
                print()
            }
            
            // 步骤2：手动测试 TextFormatter
            print("\n🧪 步骤2：手动应用 TextFormatter")
            print("========================================")
            
            let segments = resultRaw.segments.map { segment in
                TextFormatter.SegmentProxy(
                    text: segment.text,
                    start: segment.start,
                    end: segment.end
                )
            }
            
            // 测试诗词模式
            print("\n📝 诗词模式 (.poetry):")
            let poetryFormatted = TextFormatter.formatSync(
                text: resultRaw.formattedText,
                segments: segments,
                options: .poetry
            )
            print("  原文: \(resultRaw.formattedText)")
            print("  结果: \(poetryFormatted)")
            print("  标点数: \(poetryFormatted.filter { "，。？！".contains($0) }.count)")
            print("  是否相同: \(poetryFormatted == resultRaw.formattedText)")
            
            // 测试纯语义模式
            print("\n📝 纯语义模式 (.semanticOnly):")
            let semanticFormatted = TextFormatter.formatSync(
                text: resultRaw.formattedText,
                segments: segments,
                options: .semanticOnly
            )
            print("  原文: \(resultRaw.formattedText)")
            print("  结果: \(semanticFormatted)")
            print("  标点数: \(semanticFormatted.filter { "，。？！".contains($0) }.count)")
            print("  是否相同: \(semanticFormatted == resultRaw.formattedText)")
            
            // 测试标准模式
            print("\n📝 标准模式 (.default):")
            let defaultFormatted = TextFormatter.formatSync(
                text: resultRaw.formattedText,
                segments: segments,
                options: .default
            )
            print("  原文: \(resultRaw.formattedText)")
            print("  结果: \(defaultFormatted)")
            print("  标点数: \(defaultFormatted.filter { "，。？！".contains($0) }.count)")
            print("  是否相同: \(defaultFormatted == resultRaw.formattedText)")
            
            // 步骤3：检查配置
            print("\n⚙️ 步骤3：验证配置")
            print("========================================")
            print("诗词模式配置:")
            print("  enableSemanticMode: \(PunctuationRecoveryOptions.poetry.enableSemanticMode)")
            print("  minWordsForSentence: \(PunctuationRecoveryOptions.poetry.minWordsForSentence)")
            print("  shortPauseThreshold: \(PunctuationRecoveryOptions.poetry.shortPauseThreshold)")
            print("  longPauseThreshold: \(PunctuationRecoveryOptions.poetry.longPauseThreshold)")
            
            print("\n纯语义模式配置:")
            print("  enableSemanticMode: \(PunctuationRecoveryOptions.semanticOnly.enableSemanticMode)")
            print("  minWordsForSentence: \(PunctuationRecoveryOptions.semanticOnly.minWordsForSentence)")
            print("  shortPauseThreshold: \(PunctuationRecoveryOptions.semanticOnly.shortPauseThreshold)")
            
            // 步骤4：使用 transcribe 方法测试
            print("\n🎤 步骤4：使用 transcribe 直接测试")
            print("========================================")
            
            let config = RecognitionConfig(
                locale: Locale(identifier: "zh-CN"),
                punctuationRecovery: .poetry
            )
            
            let transcriber = SpeechFileTranscriber()
            let result = try await transcriber.transcribe(fileURL: audioURL, config: config)
            
            print("识别结果: \(result.formattedText)")
            print("片段数量: \(result.segments.count)")
            print("标点数量: \(result.formattedText.filter { "，。？！".contains($0) }.count)")
            
            // 步骤5：诊断建议
            print("\n💡 步骤5：诊断分析")
            print("========================================")
            
            if resultRaw.segments.isEmpty {
                print("⚠️  问题：没有识别到任何片段")
                print("   建议：检查音频文件是否正常，是否能被语音识别")
            } else if resultRaw.segments.count == 1 {
                print("⚠️  问题：只识别到一个片段")
                print("   说明：语音识别将整段话识别为一个连续片段")
                print("   解决：使用纯语义模式（.semanticOnly）应该能解决")
                print("   如果语义模式也失败，说明 TextFormatter 有问题")
            } else {
                print("✅ 片段数量正常：\(resultRaw.segments.count) 个")
                print("   各片段间隔：")
                for i in 0..<resultRaw.segments.count-1 {
                    let gap = resultRaw.segments[i+1].start - resultRaw.segments[i].end
                    print("     片段\(i) → 片段\(i+1): \(String(format: "%.2f", gap))s")
                }
            }
            
            print("\n✅ 调试完成")
            
        } catch {
            print("❌ 错误: \(error)")
            if let recError = error as? RecognitionError {
                print("   错误类型: \(recError)")
            }
        }
    }
}
