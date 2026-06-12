import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:omni_player/omni_player.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/models/word_card_data.dart';
import 'package:vidlang/providers/player_engine_provider.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/ai_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/native_service.dart';
import 'package:vidlang/services/thumbnail_service.dart';
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/device_utils.dart';
import 'package:vidlang/widgets/selectable_english_line.dart';
import 'package:vidlang/widgets/word_card.dart';

class PlayerPage extends ConsumerStatefulWidget {
  final String videoCode;
  final List<VideoInfo>? folderVideos;
  const PlayerPage({super.key, required this.videoCode, this.folderVideos});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> with WidgetsBindingObserver {
  bool _initialized = false;
  bool _showVideoList = false;
  bool _showSettings = false;
  bool _showSpeedPicker = false;
  bool _showReadAloud = false;
  bool _isRecording = false;
  List<VideoInfo>? _folderVideosOverride;

  final List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  double _playbackSpeed = 1.0;
  double _subtitleFontSize = 20.0;

  int _timerSeconds = 0;
  Timer? _shutdownTimer;

  final List<Map<String, dynamic>> _timerOptions = [
    {'label': '不开启', 'value': 0},
    {'label': '15:00', 'value': 900},
    {'label': '30:00', 'value': 1800},
    {'label': '60:00', 'value': 3600},
  ];

  String _playMode = 'single_play';
  final List<Map<String, String>> _playModeOptions = [
    {'label': '单集播放', 'value': 'single_play'},
    {'label': '单集循环', 'value': 'single_loop'},
    {'label': '列表循环', 'value': 'list_loop'},
  ];

  // TTS playback
  final ap.AudioPlayer _aliAudioPlayer = ap.AudioPlayer();
  bool _isTtsSpeaking = false;

  bool _showWordPopup = false;
  List<_WordItem> _selectedWords = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockLandscape();
    _loadSettings();
    Future.microtask(() => _initializePlayer());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shutdownTimer?.cancel();
    _aliAudioPlayer.dispose();
    _unlockOrientation();
    super.dispose();
  }

  void _lockLandscape() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  List<DeviceOrientation> _defaultOrientations() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
    if (shortestSide >= 600) {
      return [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight];
    }
    return [DeviceOrientation.portraitUp];
  }

  void _unlockOrientation() {
    SystemChrome.setPreferredOrientations(_defaultOrientations());
  }

  Future<void> _loadSettings() async {
    if (mounted) setState(() {});
  }

  Future<void> _initializePlayer() async {
    if (_initialized) return;
    _initialized = true;
    final notifier = ref.read(playerEngineProvider.notifier);
    await notifier.openVideoByCode(widget.videoCode);
    await notifier.reloadSubtitles(widget.videoCode);
    if (widget.folderVideos != null) {
      if (mounted) setState(() => _folderVideosOverride = widget.folderVideos);
    } else {
      await _loadFolderVideos();
    }
  }

  Future<void> _loadFolderVideos() async {
    final videos = await DatabaseService.findByCondition(() => VideoInfo(), where: 'code = ? AND is_deleted = 0', whereArgs: [widget.videoCode]);
    if (videos.isEmpty) return;
    final fc = videos.first.folderCode;
    if (fc.isEmpty) return;
    final fv = await DatabaseService.findByCondition(
      () => VideoInfo(),
      where: 'folder_code = ? AND is_deleted = 0',
      whereArgs: [fc],
      orderBy: 'created_at ASC',
    );
    if (mounted) setState(() => _folderVideosOverride = fv);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerEngineProvider);
    final notifier = ref.read(playerEngineProvider.notifier);
    final subtitlesList = notifier.subtitles;
    final isTablet = DeviceUtils.isTablet(context); // MediaQuery.of(context).size.shortestSide >= 600;
    final hasSubtitles = subtitlesList.isNotEmpty;
    final idx = state.currentSubtitleIndex;
    final currentSub = (hasSubtitles && idx != null && idx >= 0 && idx < subtitlesList.length) ? subtitlesList[idx] : null;
    final drawerOpen = _showVideoList || _showSettings;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Video fills screen
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: VideoWidget(player: notifier.player, fit: BoxFit.contain, backgroundColor: Colors.black),
              ),
            ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 40.w,
                padding: EdgeInsets.symmetric(horizontal: pageH(context)),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black87, Colors.transparent]),
                ),
                child: Row(
                  // alignment: Alignment.center,
                  children: [
                    _topBtn(Icons.arrow_back_ios_new_rounded, () {
                      _unlockOrientation();
                      Navigator.pop(context);
                    }),

                    Expanded(
                      child: Text(
                        state.title,
                        style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Row(
                      spacing: 10.w,
                      children: [
                        _topBtn(
                          Icons.format_list_bulleted_rounded,
                          () => setState(() {
                            _showVideoList = !_showVideoList;
                            _showSettings = false;
                            _showSpeedPicker = false;
                          }),
                          active: _showVideoList,
                        ),

                        _topBtn(
                          Icons.settings_rounded,
                          () => setState(() {
                            _showSettings = !_showSettings;
                            _showVideoList = false;
                            _showSpeedPicker = false;
                          }),
                          active: _showSettings,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom area
            if (!drawerOpen)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
                  ),
                  child: _buildBottomArea(state, notifier, subtitlesList, isTablet, hasSubtitles, idx, currentSub),
                ),
              ),

            // Drawer overlay
            if (drawerOpen && !_showWordPopup)
              GestureDetector(
                onTap: () => setState(() {
                  _showVideoList = false;
                  _showSettings = false;
                }),
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.black38),
              ),

            // Drawer panel
            if (drawerOpen && !_showWordPopup)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  width: isTablet ? 500 : 340,
                  color: AppColors.surface,
                  child: _showVideoList ? _buildVideoListContent(state, notifier) : _buildSettingsContent(state, notifier),
                ),
              ),

            // Word selection popup
            if (_showWordPopup) ...[
              // Tap-outside barrier
              GestureDetector(
                onTap: () => setState(() {
                  _showWordPopup = false;
                  _selectedWords = [];
                }),
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.black45),
              ),
              _buildWordSelectionPopup(isTablet),
            ],

            // Read-aloud popup
            if (_showReadAloud) _buildReadAloudPopup(state, notifier, currentSub, isTablet),
          ],
        ),
      ),
    );
  }

  double pageH(BuildContext c) => 14.w;

  Widget _topBtn(IconData icon, VoidCallback onTap, {bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32.r,
        height: 32.r,
        alignment: Alignment.center,
        child: Icon(icon, color: active ? AppColors.primary : Colors.white, size: 12.sp),
      ),
    );
  }

  // ─── Bottom Area ────────────────────────────────
  Widget _buildBottomArea(PlayerEngineState s, PlayerEngineNotifier n, List<Subtitles> sl, bool t, bool hs, int? idx, Subtitles? cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cs != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pageH(context)),
            child: _buildSelectableSubtitle(s, cs, t),
          ),
        _buildProgressBar(s, n),
        Padding(
          padding: EdgeInsets.fromLTRB(pageH(context), 0, pageH(context), 6),
          child: Row(
            children: [
              // 时间显示（始终可见，纯白）
              Text(
                _fmtDuration(s.position),
                style: TextStyle(color: Colors.white, fontSize: 8.sp),
              ),
              Text(
                ' / ',
                style: TextStyle(color: Colors.white, fontSize: 8.sp),
              ),
              Text(
                _fmtDuration(s.duration),
                style: TextStyle(color: Colors.white, fontSize: 8.sp),
              ),
              const SizedBox(width: 6),
              // 上一句（仅字幕可用时显示）
              if (hs) _smallCtrl(Icons.skip_previous_rounded, (idx ?? 0) > 0 ? () => n.previousSentence() : null, t),
              // 播放/暂停（始终可见，日落渐变）
              Container(
                width: 36.r,
                height: 36.r,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.sunsetGradient),
                child: IconButton(
                  icon: Icon(s.playerState == PlayerState.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 8.sp),
                  padding: EdgeInsets.zero,
                  onPressed: () => n.togglePlayPause(),
                ),
              ),
              // 下一句（仅字幕可用时显示）
              if (hs) _smallCtrl(Icons.skip_next_rounded, (idx ?? 0) < sl.length - 1 ? () => n.nextSentence() : null, t),
              const Spacer(),
              // 以下功能按钮：仅字幕可用时显示，无字幕时完全隐藏
              if (hs) ...[
                const SizedBox(width: 8),
                _featureTextBtn(
                  "跟读",
                  _showReadAloud,
                  () => setState(() {
                    _showReadAloud = !_showReadAloud;
                  }),
                  t,
                ),
              ],
              const SizedBox(width: 8),
              // 清晰朗读：始终可见，仅字幕存在时可点击
              // 付费模式走 Edge Function ai_tts，免费模式走阿里云/系统 TTS
              _featureTextBtn(
                "清晰朗读",
                hs ? _isTtsSpeaking : false,
                (hs && !_isTtsSpeaking)
                    ? () {
                        final wasPlaying = s.playerState == PlayerState.playing;
                        setState(() => _isTtsSpeaking = true);
                        if (wasPlaying) {
                          n.player.pause();
                        }
                        final subState = ref.read(subscriptionProvider);
                        if (subState.mode == SubscriptionMode.premium) {
                          _speakClarityPremium(cs!.content, wasPlaying, n);
                        } else {
                          TtsService().speakClarity(
                            text: cs!.content,
                            audioPlayer: _aliAudioPlayer,
                            onComplete: () {
                              if (!mounted) return;
                              setState(() => _isTtsSpeaking = false);
                              if (wasPlaying && !ref.read(playerEngineProvider).singleSentencePause) {
                                n.player.play();
                              }
                            },
                          );
                        }
                      }
                    : null,
                t,
                highlightBg: true,
              ),
              if (hs) ...[
                const SizedBox(width: 8),
                _featureTextBtn("字幕", s.subtitleVisible, () => n.toggleSubtitleVisible(), t),
                const SizedBox(width: 8),
                _featureTextBtn("翻译", s.translateVisible, () => n.toggleTranslateVisible(), t),
                const SizedBox(width: 8),
                _featureTextBtn("单句暂停", s.singleSentencePause, () => n.toggleSingleSentencePause(), t),
                const SizedBox(width: 8),
                _featureTextBtn("由慢到快", s.slowToFastActive, () => n.toggleSlowToFastCurrentSentence(), t),
              ],
              const SizedBox(width: 8),
              // 速度按钮：始终可见，放在功能按钮最后
              _featureTextBtn(
                "${s.speed.toStringAsFixed(1)}X",
                s.speed != 1.0,
                () => setState(() {
                  _showSpeedPicker = !_showSpeedPicker;
                }),
                t,
              ),
            ],
          ),
        ),
        if (_showSpeedPicker)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: pageH(context)),
            child: _buildSpeedPicker(t, n),
          ),
      ],
    );
  }

  Widget _smallCtrl(IconData icon, VoidCallback? onTap, bool t) {
    return IconButton(
      icon: Icon(icon, color: onTap != null ? Colors.white : Colors.white24, size: 18.w),
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: 34.w, minHeight: 34.w),
    );
  }

  Widget _featureTextBtn(String label, bool active, VoidCallback? onTap, bool t, {bool highlightBg = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: (highlightBg && active) ? EdgeInsets.symmetric(horizontal: 10, vertical: 5) : EdgeInsets.zero,
        decoration: (highlightBg && active)
            ? BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14))
            : null,
        child: Text(
          label,
          style: TextStyle(
            color: onTap == null ? Colors.white24 : (active ? AppColors.primary : Colors.white),
            fontSize: 8.sp,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ─── Selectable Subtitle (word-level swipe-to-select) ──
  Widget _buildSelectableSubtitle(PlayerEngineState s, Subtitles sub, bool t) {
    return Container(
      margin: EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.playerSubtitleBg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.subtitleVisible && sub.content.isNotEmpty)
            SelectableEnglishLine(
              text: sub.content,
              fontSize: _subtitleFontSize,
              fontColor: Colors.white,
              selectedBgColor: AppColors.primary.withValues(alpha: 0.7),
              onStartSelection: () {
                setState(() {
                  _showWordPopup = false;
                });
              },
              onSelectionChanged: (words) {
                setState(() {
                  if (words.isNotEmpty) {
                    _selectedWords = words.map((w) => _WordItem(text: w, key: GlobalKey())).toList();
                    _showWordPopup = true;
                  }
                });
              },
            ),
          if (s.translateVisible && sub.contentTranslate != null && sub.contentTranslate!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                sub.contentTranslate!,
                style: TextStyle(color: AppColors.playerSubtitleTranslate, fontSize: _subtitleFontSize - 2, height: 1.3),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  // ─── Word Selection Popup（双模式：免费→NativeService，付费→AiService）➠
  Widget _buildWordSelectionPopup(bool t) {
    final selectedText = _selectedWords.map((w) => w.text).join(' ');
    final subState = ref.watch(subscriptionProvider);
    final isPremium = subState.mode == SubscriptionMode.premium;

    // 付费模式下调用 AI，免费模式调用原生
    final future = isPremium ? _lookupWordPremium(selectedText) : _lookupWordFree(selectedText);

    return FutureBuilder<WordCardData>(
      future: future,
      builder: (ctx, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        if (loading) {
          return Center(
            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
          );
        }
        final data = snap.data;
        if (data == null) {
          return Center(
            child: Text('暂无数据', style: TextStyle(color: Colors.white54)),
          );
        }
        return WordCard(
          data: data,
          onClose: () => setState(() {
            _showWordPopup = false;
            _selectedWords = [];
          }),
          onGoRecharge: _navigateToProfile,
          onSpeak: () => _speakSelectedWord(data.word),
        );
      },
    );
  }

  /// 免费模式：原生翻译 + 本地词典
  Future<WordCardData> _lookupWordFree(String word) async {
    return NativeService.lookupWord(word);
  }

  /// 付费模式：AI 释义
  Future<WordCardData> _lookupWordPremium(String word) async {
    return AiService.getDefinition(word: word);
  }

  /// 单词朗读：免费模式走系统 TTS，付费模式走 Edge Function ai_tts
  Future<void> _speakSelectedWord(String word) async {
    final subState = ref.read(subscriptionProvider);
    if (subState.mode == SubscriptionMode.premium) {
      try {
        final result = await AiService.getTtsAudio(text: word);
        if (result == null || !mounted) return;
        final audioBase64 = result['audioBase64'] as String?;
        if (audioBase64 == null || audioBase64.isEmpty) return;
        final tmpDir = Directory.systemTemp;
        final file = File('${tmpDir.path}/tts_word_premium.mp3');
        await file.writeAsBytes(base64.decode(audioBase64));
        await _aliAudioPlayer.stop();
        await _aliAudioPlayer.play(ap.DeviceFileSource(file.path));
      } catch (_) {}
    } else {
      TtsService().speakWord(word);
    }
  }

  /// 付费模式清晰朗读：Edge Function ai_tts
  Future<void> _speakClarityPremium(String text, bool wasPlaying, PlayerEngineNotifier n) async {
    try {
      final result = await AiService.getTtsAudio(text: text);
      if (result == null || !mounted) {
        setState(() => _isTtsSpeaking = false);
        return;
      }

      final audioBase64 = result['audioBase64'] as String?;
      if (audioBase64 == null || audioBase64.isEmpty) {
        setState(() => _isTtsSpeaking = false);
        return;
      }

      // 将 base64 写入临时文件并播放
      final tmpDir = Directory.systemTemp;
      final file = File('${tmpDir.path}/tts_premium.mp3');
      await file.writeAsBytes(base64.decode(audioBase64));

      await _aliAudioPlayer.stop();
      await _aliAudioPlayer.play(ap.DeviceFileSource(file.path));

      // 等待播放完成
      _aliAudioPlayer.onPlayerComplete.first.then((_) {
        if (!mounted) return;
        setState(() => _isTtsSpeaking = false);
        if (wasPlaying && !ref.read(playerEngineProvider).singleSentencePause) {
          n.player.play();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isTtsSpeaking = false);
    }
  }

  /// 导航到个人页面（用于充值）
  void _navigateToProfile() {
    // 先关闭当前播放页面回到主页，然后切换到我的 tab
    Navigator.of(context).pop();
  }

  Widget _buildProgressBar(PlayerEngineState s, PlayerEngineNotifier n) {
    final p = s.duration.inMilliseconds > 0 ? s.position.inMilliseconds / s.duration.inMilliseconds : 0.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pageH(context)),
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 4,
          activeTrackColor: AppColors.secondary,
          inactiveTrackColor: Colors.white10,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
          thumbColor: AppColors.primary,
        ),
        child: Slider(value: p.clamp(0.0, 1.0), onChanged: (v) => n.seekToMs((v * s.duration.inMilliseconds).round())),
      ),
    );
  }

  Widget _buildSpeedPicker(bool t, PlayerEngineNotifier n) {
    return Container(
      margin: EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(10)),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _speedOptions.map((sp) {
          final active = _playbackSpeed == sp;
          return GestureDetector(
            onTap: () {
              _playbackSpeed = sp;
              n.setSpeed(sp);
              setState(() => _showSpeedPicker = false);
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: active ? AppColors.primary : AppColors.surfaceHighest, borderRadius: BorderRadius.circular(8)),
              child: Text(
                '${sp}X',
                style: TextStyle(
                  color: active ? Colors.white : Colors.white,
                  fontSize: 13.sp,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVideoListContent(PlayerEngineState s, PlayerEngineNotifier n) {
    final list = s.folderVideos.isNotEmpty ? s.folderVideos : (_folderVideosOverride ?? const <VideoInfo>[]);
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            border: Border(bottom: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              Text(
                '视频列表',
                style: TextStyle(color: Colors.white, fontSize: 17.sp, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '共 ${list.length} 集',
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.video_library_outlined, size: 48, color: Colors.white24),
                      const SizedBox(height: 8),
                      Text(
                        '暂无可播视频',
                        style: TextStyle(color: Colors.white, fontSize: 14.sp),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _VideoListItem(
                    video: list[i],
                    isCurrent: list[i].code == s.videoCode,
                    onTap: () {
                      final code = list[i].code;
                      if (code != null && code != s.videoCode) {
                        setState(() => _showVideoList = false);
                        n.switchToVideo(code);
                      }
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSettingsContent(PlayerEngineState s, PlayerEngineNotifier n) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            border: Border(bottom: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              Text(
                '播放设置',
                style: TextStyle(color: Colors.white, fontSize: 17.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _secTitle('播放模式'),
                _toggleGroup(_playModeOptions.map((m) => m['label']!).toList(), _playModeOptions.indexWhere((m) => m['value'] == _playMode), (i) {
                  setState(() => _playMode = _playModeOptions[i]['value']!);
                  n.setLoopingMode(_playModeOptions[i]['value']!);
                }),
                _divider(),
                _secTitle('定时关闭'),
                _toggleGroup(
                  _timerOptions.map((m) => m['label'] as String).toList(),
                  _timerOptions.indexWhere((m) => (m['value'] as int) == _timerSeconds),
                  (i) => _setTimer(_timerOptions[i]['value'] as int),
                ),
                _divider(),
                _secTitle('播放速度'),
                _toggleGroup(_speedOptions.map((s) => '${s}X').toList(), _speedOptions.indexOf(s.speed), (i) {
                  _playbackSpeed = _speedOptions[i];
                  n.setSpeed(_speedOptions[i]);
                }),
                _divider(),
                _secTitle('字幕字号'),
                _buildFontSlider(),
                _divider(),
                _secTitle('字幕与翻译'),
                _toggleRow(Icons.subtitles, '字幕显示', null, s.subtitleVisible, (_) => n.toggleSubtitleVisible()),
                const SizedBox(height: 8),
                _toggleRow(Icons.translate, '翻译显示', null, s.translateVisible, (_) => n.toggleTranslateVisible()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _secTitle(String text) => Padding(
    padding: EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
    ),
  );

  Widget _divider() => Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Divider(color: Colors.white12, height: 1),
  );

  Widget _toggleGroup(List<String> opts, int si, void Function(int) onTap) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(10)),
      padding: EdgeInsets.all(4),
      child: Row(
        children: List.generate(opts.length, (i) {
          final a = i == si;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: a ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  opts[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(color: a ? Colors.white : Colors.white, fontSize: 14.sp, fontWeight: a ? FontWeight.bold : FontWeight.normal),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFontSlider() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '小',
                style: TextStyle(color: Colors.white, fontSize: 13.sp),
              ),
              Text(
                '${_subtitleFontSize.toInt()}',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
              Text(
                '大',
                style: TextStyle(color: Colors.white, fontSize: 13.sp),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white12,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
              thumbColor: AppColors.primary,
            ),
            child: Slider(value: _subtitleFontSize, min: 12, max: 40, onChanged: (v) => setState(() => _subtitleFontSize = v)),
          ),
        ],
      ),
    );
  }

  Widget _toggleRow(IconData icon, String title, String? sub, bool v, ValueChanged<bool> onChanged) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.white, fontSize: 15.sp),
                ),
                if (sub != null)
                  Text(
                    sub,
                    style: TextStyle(color: Colors.white, fontSize: 12.sp),
                  ),
              ],
            ),
          ),
          Switch(value: v, onChanged: onChanged, activeThumbColor: AppColors.primary, activeTrackColor: AppColors.primary.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  void _setTimer(int seconds) {
    _shutdownTimer?.cancel();
    setState(() => _timerSeconds = seconds);
    ref.read(playerEngineProvider.notifier).setShutdownTimer(seconds);
    if (seconds > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('定时关闭已设置: ${seconds ~/ 60}分钟'), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating),
      );
    }
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildReadAloudPopup(PlayerEngineState s, PlayerEngineNotifier n, Subtitles? cs, bool t) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: t ? 600 : 360),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '跟读',
                style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (cs != null)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surfaceHighest, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    cs.content,
                    style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (cs != null && cs.contentTranslate != null && cs.contentTranslate!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    cs.contentTranslate!,
                    style: TextStyle(color: AppColors.playerSubtitleTranslate, fontSize: 13.sp),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (cs != null) await TtsService().speakSubtitle(cs.content);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 22.w),
                          const SizedBox(width: 6),
                          Text(
                            '朗读字幕',
                            style: TextStyle(color: AppColors.primary, fontSize: 12.sp, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      if (cs != null && !_isTtsSpeaking) {
                        setState(() => _isTtsSpeaking = true);
                        await TtsService().speakClarity(
                          text: cs.content,
                          audioPlayer: _aliAudioPlayer,
                          onComplete: () {
                            if (mounted) setState(() => _isTtsSpeaking = false);
                          },
                        );
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isTtsSpeaking ? AppColors.success.withValues(alpha: 0.25) : AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isTtsSpeaking ? Icons.volume_up : Icons.record_voice_over_rounded,
                            color: _isTtsSpeaking ? AppColors.success : AppColors.primary,
                            size: 22.w,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isTtsSpeaking ? '播放中' : '清晰朗读',
                            style: TextStyle(
                              color: _isTtsSpeaking ? AppColors.success : AppColors.primary,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      if (cs != null) {
                        n.seekToMs(cs.startPosition.toInt());
                        n.togglePlayPause();
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.replay_rounded, color: AppColors.primary, size: 22.w),
                          const SizedBox(width: 6),
                          Text(
                            '重播本句',
                            style: TextStyle(color: AppColors.primary, fontSize: 12.sp, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => setState(() => _isRecording = !_isRecording),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: _isRecording ? Colors.red : AppColors.primary,
                            size: 22.w,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isRecording ? '停止录音' : '开始录音',
                            style: TextStyle(color: _isRecording ? Colors.red : AppColors.primary, fontSize: 12.sp, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setState(() => _showReadAloud = false),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '关闭',
                    style: TextStyle(color: Colors.white, fontSize: 12.sp),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordItem {
  final String text;
  final GlobalKey key;
  const _WordItem({required this.text, required this.key});
}

class _VideoListItem extends ConsumerStatefulWidget {
  final VideoInfo video;
  final bool isCurrent;
  final VoidCallback onTap;
  const _VideoListItem({required this.video, required this.isCurrent, required this.onTap});
  @override
  ConsumerState<_VideoListItem> createState() => _VideoListItemState();
}

class _VideoListItemState extends ConsumerState<_VideoListItem> {
  String? _resolvedCoverPath;
  @override
  void initState() {
    super.initState();
    _resolveCover();
  }

  @override
  void didUpdateWidget(_VideoListItem old) {
    super.didUpdateWidget(old);
    if (old.video.cover != widget.video.cover || old.video.currentCover != widget.video.currentCover) _resolveCover();
  }

  Future<void> _resolveCover() async {
    final cover = (widget.video.currentCover != null && widget.video.currentCover!.isNotEmpty) ? widget.video.currentCover : widget.video.cover;
    if (cover == null || cover.isEmpty) return;
    final fp = await ThumbnailService.getFullPath(cover);
    if (mounted) setState(() => _resolvedCoverPath = fp);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    final cur = widget.isCurrent;
    final t = MediaQuery.of(context).size.shortestSide >= 600;
    final cover = _resolvedCoverPath;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: t ? 88 : 76,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: cur ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceElevated,
              border: cur ? Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5) : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                  child: Container(
                    width: t ? 140 : 110,
                    color: AppColors.cardThumbnailBg,
                    child: (cover != null && File(cover).existsSync())
                        ? Image.file(File(cover), fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder(t))
                        : _placeholder(t),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          v.name,
                          style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: cur ? FontWeight.bold : FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 12, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              v.durationString,
                              style: TextStyle(color: Colors.white, fontSize: 11.sp),
                            ),
                            if (v.hasSubtitles) ...[
                              SizedBox(width: 8),
                              Icon(Icons.subtitles, size: 12, color: AppColors.primary.withValues(alpha: 0.7)),
                              SizedBox(width: 3),
                              Text(
                                '字幕',
                                style: TextStyle(color: AppColors.primary.withValues(alpha: 0.7), fontSize: t ? 12 : 10),
                              ),
                            ],
                            if (cur) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                                child: Text(
                                  '播放中',
                                  style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (cur) Container(width: 3, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(bool t) => Center(
    child: Icon(Icons.movie_outlined, size: 22.w * 1.2, color: Colors.white24),
  );
}
