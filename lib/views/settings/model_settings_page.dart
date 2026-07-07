import 'package:flutter/material.dart';
import 'package:vidlang/services/local_model_service.dart';
import 'package:vidlang/theme/theme.dart';

/// 模型设置页面
/// 只显示 MarianMT 翻译模型状态
class ModelSettingsPage extends StatefulWidget {
  const ModelSettingsPage({super.key});

  @override
  State<ModelSettingsPage> createState() => _ModelSettingsPageState();
}

class _ModelSettingsPageState extends State<ModelSettingsPage> {
  final LocalModelService _localModelService = LocalModelService.instance;
  bool _isLoading = true;
  LocalModelStatus _modelStatus = LocalModelStatus.unknown;

  @override
  void initState() {
    super.initState();
    _loadModelStatus();
  }

  Future<void> _loadModelStatus() async {
    setState(() => _isLoading = true);
    _modelStatus = await _localModelService.checkModelsStatus();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('模型设置'),
        backgroundColor: AppColors.surface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  _buildModelInfo(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final cs = Theme.of(context).colorScheme;
    final color = _modelStatus == LocalModelStatus.ready ? AppColors.success : AppColors.error;
    final icon = _modelStatus == LocalModelStatus.ready ? AppIcons.checkCircle : AppIcons.warning;

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _modelStatus.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _modelStatus.description,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '已安装模型',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('• MarianMT 翻译模型 — 免费模式本地翻译', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            const Text('• TTS — 使用 iOS 原生语音合成（无需下载模型）', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            const Text('• STT — 免费模式不可用，收费模式使用云端声通', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
