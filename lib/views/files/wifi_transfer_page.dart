library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/services/settings_service.dart';
import 'package:vidlang/services/files/wifi_transfer_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

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
      final port = await SettingsService.getWifiPort();
      await service.start(preferredPort: port);
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
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'WiFi 传输',
          style: TextStyle(fontSize: Adaptive.sp(16), fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrowBackIosNew, size: Adaptive.sp(20)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _starting
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 3, color: colorScheme.primary),
                  SizedBox(height: Adaptive.h(16)),
                  Text(
                    '正在启动服务...',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: Adaptive.sp(14)),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: Adaptive.w(24), vertical: Adaptive.h(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 头部图标与状态
                    Container(
                      padding: EdgeInsets.all(Adaptive.w(16)),
                      decoration: BoxDecoration(
                        color: service.isRunning ? colorScheme.primary.withValues(alpha: 0.08) : colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        service.isRunning ? AppIcons.wifiTethering : AppIcons.wifiTetheringOff,
                        size: Adaptive.w(40),
                        color: service.isRunning ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: Adaptive.h(16)),
                    Text(
                      service.isRunning ? '服务已启动' : '服务未启动',
                      style: TextStyle(fontSize: Adaptive.sp(18), fontWeight: FontWeight.bold, color: colorScheme.onSurface, letterSpacing: 0.5),
                    ),
                    SizedBox(height: Adaptive.h(6)),
                    Text(
                      '请确保手机与电脑连接在同一局域网下',
                      style: TextStyle(fontSize: Adaptive.sp(12), color: colorScheme.onSurfaceVariant),
                    ),

                    SizedBox(height: Adaptive.h(32)),

                    // 错误信息提示
                    if (_error != null)
                      Container(
                        padding: EdgeInsets.all(Adaptive.w(12)),
                        margin: EdgeInsets.only(bottom: Adaptive.h(20)),
                        decoration: BoxDecoration(color: colorScheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(Adaptive.r(12))),
                        child: Text(
                          _error!,
                          style: TextStyle(color: colorScheme.error, fontSize: Adaptive.sp(13)),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // 核心操作区
                    if (service.isRunning && url != null) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: Adaptive.h(24), horizontal: Adaptive.w(16)),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(Adaptive.r(20)),
                          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '在电脑浏览器中输入以下地址',
                              style: TextStyle(fontSize: Adaptive.sp(12), color: colorScheme.onSurfaceVariant),
                            ),
                            SizedBox(height: Adaptive.h(12)),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SelectableText(
                                url,
                                style: TextStyle(fontSize: Adaptive.sp(20), fontWeight: FontWeight.w600, color: colorScheme.primary, letterSpacing: 0.5),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Adaptive.h(24)),

                      // 按钮组
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionBtn(
                              icon: AppIcons.copy,
                              label: '复制地址',
                              isPrimary: true,
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: url));
                                TDToast.showText('已复制地址', context: context);
                              },
                            ),
                          ),
                          SizedBox(width: Adaptive.w(12)),
                          Expanded(
                            child: _buildActionBtn(icon: AppIcons.stopCircle, label: '停止服务', isPrimary: false, onTap: _stop),
                          ),
                        ],
                      ),
                    ] else if (!service.isRunning && _error == null) ...[
                      SizedBox(
                        width: Adaptive.w(200),
                        child: _buildActionBtn(icon: AppIcons.playCircleFill, label: '重新启动', isPrimary: true, onTap: _start),
                      ),
                    ],

                    // 备用地址列表
                    if (service.isRunning && service.addresses.length > 1) ...[
                      SizedBox(height: Adaptive.h(32)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '备用地址',
                          style: TextStyle(fontSize: Adaptive.sp(13), fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      SizedBox(height: Adaptive.h(10)),
                      ...service.addresses.where((ip) => 'http://$ip:${service.port}' != url).map((ip) {
                        final altUrl = 'http://$ip:${service.port ?? 9999}';
                        return Container(
                          margin: EdgeInsets.only(bottom: Adaptive.h(8)),
                          padding: EdgeInsets.symmetric(horizontal: Adaptive.w(16), vertical: Adaptive.h(12)),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(Adaptive.r(12)),
                            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(AppIcons.link, size: Adaptive.sp(14), color: colorScheme.onSurfaceVariant),
                              SizedBox(width: Adaptive.w(10)),
                              Expanded(
                                child: Text(
                                  altUrl,
                                  style: TextStyle(fontSize: Adaptive.sp(13), color: colorScheme.onSurface),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: altUrl));
                                  TDToast.showText('已复制备用地址', context: context);
                                },
                                child: Icon(AppIcons.copy, size: Adaptive.sp(16), color: colorScheme.primary),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildActionBtn({required IconData icon, required String label, required bool isPrimary, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: isPrimary ? colorScheme.primary : colorScheme.surface,
      borderRadius: BorderRadius.circular(Adaptive.r(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Adaptive.r(12)),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: Adaptive.h(14)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Adaptive.r(12)),
            border: isPrimary ? null : Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.8)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: Adaptive.sp(18), color: isPrimary ? colorScheme.onPrimary : colorScheme.onSurface),
              SizedBox(width: Adaptive.w(6)),
              Text(
                label,
                style: TextStyle(fontSize: Adaptive.sp(15), fontWeight: FontWeight.w600, color: isPrimary ? colorScheme.onPrimary : colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
