library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/services/settings_service.dart';
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
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20.sp),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _starting
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 3, color: colorScheme.primary),
                  SizedBox(height: 16.h),
                  Text(
                    '正在启动服务...',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14.sp),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 头部图标与状态
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: service.isRunning ? colorScheme.primary.withValues(alpha: 0.08) : colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        service.isRunning ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
                        size: 40.w,
                        color: service.isRunning ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      service.isRunning ? '服务已启动' : '服务未启动',
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: colorScheme.onSurface, letterSpacing: 0.5),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      '请确保手机与电脑连接在同一局域网下',
                      style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
                    ),

                    SizedBox(height: 32.h),

                    // 错误信息提示
                    if (_error != null)
                      Container(
                        padding: EdgeInsets.all(12.w),
                        margin: EdgeInsets.only(bottom: 20.h),
                        decoration: BoxDecoration(color: colorScheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12.r)),
                        child: Text(
                          _error!,
                          style: TextStyle(color: colorScheme.error, fontSize: 13.sp),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // 核心操作区
                    if (service.isRunning && url != null) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '在电脑浏览器中输入以下地址',
                              style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
                            ),
                            SizedBox(height: 12.h),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SelectableText(
                                url,
                                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: colorScheme.primary, letterSpacing: 0.5),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24.h),

                      // 按钮组
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionBtn(
                              icon: Icons.copy_rounded,
                              label: '复制地址',
                              isPrimary: true,
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: url));
                                TDToast.showText('已复制地址', context: context);
                              },
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildActionBtn(icon: Icons.stop_circle_rounded, label: '停止服务', isPrimary: false, onTap: _stop),
                          ),
                        ],
                      ),
                    ] else if (!service.isRunning && _error == null) ...[
                      SizedBox(
                        width: 200.w,
                        child: _buildActionBtn(icon: Icons.play_circle_fill_rounded, label: '重新启动', isPrimary: true, onTap: _start),
                      ),
                    ],

                    // 备用地址列表
                    if (service.isRunning && service.addresses.length > 1) ...[
                      SizedBox(height: 32.h),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '备用地址',
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      ...service.addresses.where((ip) => 'http://$ip:${service.port}' != url).map((ip) {
                        final altUrl = 'http://$ip:${service.port ?? 9999}';
                        return Container(
                          margin: EdgeInsets.only(bottom: 8.h),
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.link_rounded, size: 14.sp, color: colorScheme.onSurfaceVariant),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  altUrl,
                                  style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurface),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: altUrl));
                                  TDToast.showText('已复制备用地址', context: context);
                                },
                                child: Icon(Icons.copy_rounded, size: 16.sp, color: colorScheme.primary),
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
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: isPrimary ? null : Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.8)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18.sp, color: isPrimary ? colorScheme.onPrimary : colorScheme.onSurface),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: isPrimary ? colorScheme.onPrimary : colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
