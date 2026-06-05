library;

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/services/wifi_transfer_service.dart';
import 'package:vidlang/theme/theme.dart';

class WifiTransferPage extends StatefulWidget {
  const WifiTransferPage({super.key});

  @override
  State<WifiTransferPage> createState() => _WifiTransferPageState();
}

class _WifiTransferPageState extends State<WifiTransferPage> {
  final service = WifiTransferService.instance;
  bool _starting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    service.addListener(_onServiceChanged);
    _start();
  }

  @override
  void dispose() {
    service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _start() async {
    try {
      await service.start(preferredPort: 9999);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
        });
      }
    }
  }

  Future<void> _stop() async {
    await service.stop();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = service.primaryUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi 传输'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: service.isRunning ? _stop : null,
            child: Text('停止', style: TextStyle(color: service.isRunning ? colorScheme.error : colorScheme.outline)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: AppRadius.all('lg'),
                color: colorScheme.surfaceContainerHighest,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('状态', style: TextStyle(fontSize: AppTypography.fontSizeLarge, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  if (_starting) ...[
                    Row(
                      children: [
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 10),
                        Text('正在启动（端口 9999）…', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ] else if (_error != null) ...[
                    Text('启动失败：$_error', style: TextStyle(color: colorScheme.error)),
                  ] else if (service.isRunning) ...[
                    Text('已启动', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('在电脑浏览器打开：', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    SelectableText(url ?? '-', style: TextStyle(fontSize: 16, color: colorScheme.onSurface)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: url == null
                                ? null
                                : () {
                                    TDToast.showText(url, context: context);
                                  },
                            child: const Text('复制/提示地址'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _stop,
                            child: const Text('停止并返回'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('说明：Web 端仅支持新建/重命名文件夹与上传视频，不提供删除。', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  ] else ...[
                    Text('未启动', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView(
                children: [
                  Text('可用地址', style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  if (service.addresses.isEmpty) Text('-', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  for (final ip in service.addresses)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.all('md'),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Text('http://$ip:${service.port ?? 9999}/', style: TextStyle(color: colorScheme.onSurface)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

