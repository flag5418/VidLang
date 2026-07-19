import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 🧪 极简方向测试页面
///
/// **目的**：排除播放器复杂逻辑，单独验证方向切换是否生效
/// **参考代码**：VideoPlayerBase (deepenglish_app)
class OrientationTestPage extends StatefulWidget {
  const OrientationTestPage({super.key});

  @override
  State<OrientationTestPage> createState() => _OrientationTestPageState();
}

class _OrientationTestPageState extends State<OrientationTestPage>
    with WidgetsBindingObserver {
  // ─── 状态 ──────────────────────────────────────

  /// 当前方向（用于 UI 显示）
  String _currentOrientation = 'Unknown';

  /// didChangeMetrics 触发次数
  int _metricsCount = 0;

  /// 日志列表
  final List<String> _logs = [];

  // ─── 生命周期 ──────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // ✅ 关键1：添加 Observer
    WidgetsBinding.instance.addObserver(this);

    // ✅ 关键2：允许所有方向旋转（与参考代码完全一致）
    _log('🎬 [initState] Step1: 允许所有方向旋转');
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // ✅ 关键3：开启屏幕常亮
    WakelockPlus.enable();
    _log('🎬 [initState] Step2: WakelockPlus.enable');

    // 延迟读取初始方向
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final orientation = MediaQuery.of(context).orientation;
      _updateOrientation(orientation, source: 'initState');
      _handleOrientationChange(orientation);
    });
  }

  @override
  void dispose() {
    _log('🗑️ [dispose] 清理资源');
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 核心方法：与参考代码 VideoPlayerBase 完全一致
  // ═══════════════════════════════════════════════════════════

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;

    _metricsCount++;
    _log('📐 [didChangeMetrics] ⚡️ 第$_metricsCount 次触发！');

    // 与参考代码完全一致的延迟执行逻辑
    Future.microtask(() {
      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        try {
          final orientation = MediaQuery.of(context).orientation;
          _log('📱 [didChangeMetrics] 屏幕方向变化：$orientation');
          _updateOrientation(orientation, source: 'didChangeMetrics');
          _handleOrientationChange(orientation);
        } catch (e) {
          _log('⚠️ [didChangeMetrics] 获取屏幕方向失败: $e');
        }
      });
    });
  }

  /// 处理屏幕方向变化（与参考代码 _handleOrientationChange 完全一致）
  void _handleOrientationChange(Orientation orientation) {
    _log('🔄 [_handleOrientationChange] 开始处理: $orientation');

    if (orientation == Orientation.landscape) {
      // 横屏：进入全屏模式（隐藏状态栏和导航栏）
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [], // 隐藏所有系统UI
      );
      _log('✅ [_handleOrientationChange] → immersiveSticky (隐藏状态栏)');
    } else {
      // 竖屏：恢复正常模式（显示状态栏和导航栏）
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values, // 显示所有系统UI
      );
      _log('✅ [_handleOrientationChange] → manual (显示状态栏)');
    }

    // 触发 UI 重绘
    if (mounted) {
      setState(() {});
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 辅助方法
  // ═══════════════════════════════════════════════════════════

  /// 清空日志
  void _clearLogs() {
    setState(() {
      _logs.clear();
      _metricsCount = 0;
    });
  }

  void _updateOrientation(Orientation orientation, {required String source}) {
    setState(() {
      _currentOrientation = orientation.name;
    });
  }

  void _log(String message) {
    debugPrint('🧪 [OrientationTest] $message');
    setState(() {
      final time = DateTime.now().toString().substring(11, 19);
      _logs.insert(0, '[$time] $message');
      // 只保留最近 50 条日志
      if (_logs.length > 50) {
        _logs.removeLast();
      }
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 UI 构建
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    final screenSize = MediaQuery.of(context).size;

    // 🎯 横屏和竖屏使用完全不同的 UI 结构，便于一眼区分
    if (isLandscape) {
      return _buildLandscapeLayout(orientation, screenSize);
    } else {
      return _buildPortraitLayout(orientation, screenSize);
    }
  }

  /// 竖屏布局：蓝色主题，纵向排列
  Widget _buildPortraitLayout(Orientation orientation, Size screenSize) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text('📱 竖屏模式 (Portrait)'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空日志',
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(orientation, false, screenSize),
            const SizedBox(height: 16),
            _buildSectionTitle('📊 统计信息'),
            _buildStatsRow(),
            const SizedBox(height: 16),
            _buildSectionTitle('📝 日志输出'),
            _buildLogPanel(maxHeight: 250),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// 横屏布局：橙色主题，左右分栏
  Widget _buildLandscapeLayout(Orientation orientation, Size screenSize) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      appBar: AppBar(
        title: const Text('🖥️ 横屏模式 (Landscape)'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空日志',
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Row(
        children: [
          // 左侧：状态 + 按钮
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(orientation, true, screenSize),
                  const SizedBox(height: 12),
                  _buildSectionTitle('📊 统计信息'),
                  _buildStatsRow(),
                ],
              ),
            ),
          ),
          // 右侧：日志
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('📝 日志输出'),
                  const SizedBox(height: 8),
                  Expanded(child: _buildLogPanel(maxHeight: double.infinity)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    Orientation orientation,
    bool isLandscape,
    Size screenSize,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLandscape
              ? [Colors.orange.shade700, Colors.red.shade700]
              : [Colors.blue.shade700, Colors.indigo.shade700],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isLandscape ? Colors.orange : Colors.blue).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 大号方向标识
          Center(
            child: Text(
              isLandscape ? '🖥️ 横屏' : '📱 竖屏',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '屏幕尺寸: ${screenSize.width.toInt()} × ${screenSize.height.toInt()}',
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
          Text(
            'didChangeMetrics 次数: $_metricsCount',
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('方向', _currentOrientation),
          _buildStatItem('日志条数', '${_logs.length}'),
          _buildStatItem('Metrics次数', '$_metricsCount'),
        ],
      ),
    );
  }

  Widget _buildLogPanel({required double maxHeight}) {
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: _logs.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '暂无日志，点击上方按钮开始测试...',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              physics: maxHeight == double.infinity
                  ? const AlwaysScrollableScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Text(
                    _logs[index],
                    style: TextStyle(
                      color: _logs[index].contains('❌')
                          ? Colors.redAccent
                          : _logs[index].contains('✅')
                              ? Colors.lightGreenAccent
                              : Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
