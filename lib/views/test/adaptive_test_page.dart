/// 自适应缩放测试页面
/// 用于验证 Adaptive 缩放是否正确工作
library;

import 'package:flutter/material.dart';import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vidlang/models/device_type.dart';
import 'package:vidlang/providers/device_type_provider.dart';

class AdaptiveTestPage extends ConsumerWidget {
  const AdaptiveTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceType = ref.watch(deviceTypeProvider);
    final isIpad = deviceType.isTablet;

    return Scaffold(
      appBar: AppBar(
        title: const Text('自适应缩放测试'),
        actions: [
          // 切换设备类型按钮
          IconButton(
            icon: Icon(isIpad ? Icons.phone_android : Icons.tablet),
            onPressed: () {
              final newType = isIpad ? AppDeviceType.iphone : AppDeviceType.ipad;
              ref.read(deviceTypeProvider.notifier).setDeviceType(newType);
            },
            tooltip: isIpad ? '切换到 iPhone' : '切换到 iPad',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 设备信息
            _buildSection('设备信息', [
              _buildInfoRow('当前设备类型', deviceType.name),
              _buildInfoRow('isTablet', isIpad.toString()),
              _buildInfoRow('屏幕宽度', MediaQuery.of(context).size.width.toStringAsFixed(1)),
              _buildInfoRow('屏幕高度', MediaQuery.of(context).size.height.toStringAsFixed(1)),
              _buildInfoRow('最短边', MediaQuery.of(context).size.shortestSide.toStringAsFixed(1)),
            ]),
            SizedBox(height: 24),

            // 缩放系数测试
            _buildSection('缩放系数测试', [
              _buildScaleRow('sp(16)', 16, '字体'),
              _buildScaleRow('w(16)', 16, '宽度'),
              _buildScaleRow('h(16)', 16, '高度'),
              _buildScaleRow('r(12)', 12, '圆角'),
              _buildScaleRow('icon(24)', 24, '图标'),
            ]),
            SizedBox(height: 24),

            // 扩展方法测试
            _buildSection('扩展方法测试', [
              _buildScaleRow('context.ts(16)', context.ts(16), '字体'),
              _buildScaleRow('context.s(16)', context.s(16), '宽度'),
              _buildScaleRow('context.rs(12)', context.rs(12), '圆角'),
              _buildScaleRow('context.is_(24)', context.is_(24), '图标'),
            ]),
            SizedBox(height: 24),

            // 实际组件测试
            _buildSection('实际组件测试', [
              // 按钮测试
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('ElevatedButton'),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('OutlinedButton'),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('TextButton'),
                  ),
                ],
              ),
              SizedBox(height: 12),
              // 输入框测试
              const TextField(
                decoration: InputDecoration(
                  labelText: '测试输入框',
                  hintText: '请输入内容',
                ),
              ),
            ]),
            SizedBox(height: 24),

            // 对话框测试
            _buildSection('对话框测试', [
              ElevatedButton(
                onPressed: () => _showTestDialog(context),
                child: const Text('显示测试对话框'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildScaleRow(String method, double value, String type) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$method ($type)'),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value.toStringAsFixed(2),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showTestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('测试对话框'),
        content: const Text('这是一个测试对话框，用于验证对话框的自适应效果。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}
