import 'dart:convert';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vidlang/theme/theme.dart';

/// 声通网络连通性测试页面
/// 用于排查 WebSocket 连接问题
class NetworkDebugPage extends StatefulWidget {
  const NetworkDebugPage({super.key});

  @override
  State<NetworkDebugPage> createState() => _NetworkDebugPageState();
}

class _NetworkDebugPageState extends State<NetworkDebugPage> {
  String _log = '';

  void _addLog(String msg) {
    setState(() {
      _log += '[$_now] $msg\n';
    });
    debugPrint('[NetworkDebug] $msg');
  }

  String get _now {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  Future<void> _testHttpConnection() async {
    _log = '';
    _addLog('🚀 测试 HTTP 连接到声通服务器');

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      _addLog('🔗 尝试连接 http://api.stkouyu.com:8080');
      final request = await client.get('api.stkouyu.com', 8080, '/');
      _addLog('📤 HTTP 请求已发送');

      final response = await request.close().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('HTTP 响应超时');
        },
      );

      _addLog('📥 HTTP 响应状态: ${response.statusCode}');
      _addLog('📥 响应头:');
      response.headers.forEach((name, values) {
        for (final value in values) {
          _addLog('   $name: $value');
        }
      });

      final body = await response.transform(utf8.decoder).join();
      _addLog(
        '📥 响应体: ${body.substring(0, body.length > 200 ? 200 : body.length)}',
      );

      client.close();
      _addLog('✅ HTTP 测试完成');
    } catch (e) {
      _addLog('❌ HTTP 测试失败: $e');
    }
  }

  Future<void> _testRawSocket() async {
    _log = '';
    _addLog('🚀 测试原始 Socket 连接');

    try {
      _addLog('🔗 连接 api.stkouyu.com:8080');
      final socket = await Socket.connect(
        'api.stkouyu.com',
        8080,
      ).timeout(const Duration(seconds: 10));
      _addLog('✅ TCP 连接成功');

      // 发送 HTTP GET 请求
      final request =
          'GET /sent.eval HTTP/1.1\r\n'
          'Host: api.stkouyu.com:8080\r\n'
          'Connection: Upgrade\r\n'
          'Upgrade: websocket\r\n'
          'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n'
          'Sec-WebSocket-Version: 13\r\n'
          '\r\n';

      socket.write(request);
      await socket.flush();
      _addLog('📤 WebSocket 握手请求已发送');

      // 读取响应
      _addLog('⏳ 等待响应...');
      final data = await socket.first;
      _addLog('📥 收到 ${data.length} bytes');
      _addLog('📥 数据: ${utf8.decode(data)}');

      socket.close();
      _addLog('✅ Socket 测试完成');
    } catch (e) {
      _addLog('❌ Socket 测试失败: $e');
    }
  }

  Future<void> _testDnsResolution() async {
    _log = '';
    _addLog('🚀 测试 DNS 解析');

    try {
      _addLog('🔍 解析 api.stkouyu.com');
      final addresses = await InternetAddress.lookup('api.stkouyu.com');
      _addLog('✅ 解析成功:');
      for (final addr in addresses) {
        _addLog('   ${addr.address} (${addr.type.name})');
      }
    } catch (e) {
      _addLog('❌ DNS 解析失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('网络连通性测试'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _testDnsResolution,
              icon: const Icon(AppIcons.dns),
              label: const Text('测试 DNS 解析'),
            ),
            SizedBox(height: adaptive.Adaptive.h(8)),
            ElevatedButton.icon(
              onPressed: _testHttpConnection,
              icon: const Icon(AppIcons.http),
              label: const Text('测试 HTTP 连接'),
            ),
            SizedBox(height: adaptive.Adaptive.h(8)),
            ElevatedButton.icon(
              onPressed: _testRawSocket,
              icon: const Icon(AppIcons.cable),
              label: const Text('测试原始 Socket'),
            ),
            SizedBox(height: adaptive.Adaptive.h(16)),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _log.isEmpty ? '点击上方按钮开始测试...' : _log,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: adaptive.Adaptive.sp(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
