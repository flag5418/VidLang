library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omni_player/omni_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/settings_service.dart';

final playerEngineProvider = StateNotifierProvider.autoDispose<PlayerEngineNotifier, PlayerEngineState>((ref) => PlayerEngineNotifier(ref));

class PlayerEngineState {
  static const Object _unset = Object();
  final String? videoCode;
  final String title;
  final PlayerState playerState;
  final Duration position;
  final Duration duration;
  final double buffered;
  final VideoSize? videoSize;
  final double speed;
  final bool looping;
  final bool controlsVisible;
  final int? currentSubtitleIndex;
  final bool subtitleVisible;
  final bool translateVisible;
  final bool singleSentencePause;
  final bool slowToFastActive;
  final String? errorMessage;
  final String loopingMode;
  final int shutdownTimerSeconds;
  final bool hasSubtitles;
  final List<VideoInfo> folderVideos;

  const PlayerEngineState({
    this.videoCode,
    this.title = '',
    this.playerState = PlayerState.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = 0.0,
    this.videoSize,
    this.speed = 1.0,
    this.looping = false,
    this.controlsVisible = true,
    this.currentSubtitleIndex,
    this.subtitleVisible = true,
    this.translateVisible = true,
    this.singleSentencePause = false,
    this.slowToFastActive = false,
    this.errorMessage,
    this.loopingMode = 'single_play',
    this.shutdownTimerSeconds = 0,
    this.hasSubtitles = false,
    this.folderVideos = const [],
  });

  PlayerEngineState copyWith({
    String? videoCode,
    String? title,
    PlayerState? playerState,
    Duration? position,
    Duration? duration,
    double? buffered,
    Object? videoSize = _unset,
    double? speed,
    bool? looping,
    bool? controlsVisible,
    Object? currentSubtitleIndex = _unset,
    bool? subtitleVisible,
    bool? translateVisible,
    bool? singleSentencePause,
    bool? slowToFastActive,
    String? errorMessage,
    String? loopingMode,
    int? shutdownTimerSeconds,
    bool? hasSubtitles,
    List<VideoInfo>? folderVideos,
  }) {
    return PlayerEngineState(
      videoCode: videoCode ?? this.videoCode,
      title: title ?? this.title,
      playerState: playerState ?? this.playerState,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      videoSize: identical(videoSize, _unset) ? this.videoSize : videoSize as VideoSize?,
      speed: speed ?? this.speed,
      looping: looping ?? this.looping,
      controlsVisible: controlsVisible ?? this.controlsVisible,
      currentSubtitleIndex: identical(currentSubtitleIndex, _unset) ? this.currentSubtitleIndex : currentSubtitleIndex as int?,
      subtitleVisible: subtitleVisible ?? this.subtitleVisible,
      translateVisible: translateVisible ?? this.translateVisible,
      singleSentencePause: singleSentencePause ?? this.singleSentencePause,
      slowToFastActive: slowToFastActive ?? this.slowToFastActive,
      errorMessage: errorMessage,
      loopingMode: loopingMode ?? this.loopingMode,
      shutdownTimerSeconds: shutdownTimerSeconds ?? this.shutdownTimerSeconds,
      hasSubtitles: hasSubtitles ?? this.hasSubtitles,
      folderVideos: folderVideos ?? this.folderVideos,
    );
  }
}

class PlayerEngineNotifier extends StateNotifier<PlayerEngineState> {
  final Ref ref;
  final OmniPlayer _player = OmniPlayer.instance;
  final List<StreamSubscription> _subs = [];

  bool _initialized = false;
  bool _closed = false;
  int _opSeq = 0;
  VideoInfo? _video;
  VideoFolder? _folder;
  List<Subtitles> _subtitles = const [];

  DateTime? _lastProgressSavedAt;
  int? _lastPausedSubtitleIndex;
  int? _currentSentenceIdx; // 正在播放的句子索引，用于单句暂停精确控制

  bool _slowToFastActive = false;
  bool _slowToFastTransitioning = false;
  int _slowToFastStep = 0;
  int _slowStartMs = 0;
  int _slowEndMs = 0;
  double _slowOriginalSpeed = 1.0;
  List<double> _slowSpeedSeq = const [];
  Timer? _shutdownTimer;

  PlayerEngineNotifier(this.ref) : super(const PlayerEngineState()) {
    ref.onDispose(() {
      unawaited(disposePlayer());
    });
  }

  OmniPlayer get player => _player;

  Future<void> openVideoByCode(String videoCode) async {
    final op = ++_opSeq;
    await _ensureInitialized();
    if (_closed || op != _opSeq) return;

    final video = await _findVideo(videoCode);
    if (_closed || op != _opSeq) return;
    if (video == null) return;
    final folder = await _findFolder(video.folderCode);
    if (_closed || op != _opSeq) return;

    _video = video;
    _folder = folder;
    _lastProgressSavedAt = null;
    _lastPausedSubtitleIndex = null;
    _currentSentenceIdx = null;

    final speed = await SettingsService.getPlayerPlaybackSpeed();
    if (_closed || op != _opSeq) return;
    final subtitleVisible = await SettingsService.getPlayerSubtitleVisible();
    if (_closed || op != _opSeq) return;
    final translateVisible = await SettingsService.getPlayerTranslateVisible();
    if (_closed || op != _opSeq) return;
    final singleSentencePause = await SettingsService.getPlayerSingleSentencePause();
    if (_closed || op != _opSeq) return;

    _setStateSafely(
      state.copyWith(
        videoCode: videoCode,
        title: video.name,
        speed: speed,
        subtitleVisible: subtitleVisible,
        translateVisible: translateVisible,
        singleSentencePause: singleSentencePause,
        playerState: PlayerState.loading,
        position: Duration(milliseconds: video.currentPosition.clamp(0, 1 << 30)),
        duration: Duration(milliseconds: video.duration.clamp(0, 1 << 30)),
        buffered: 0.0,
        videoSize: null,
        currentSubtitleIndex: null,
        slowToFastActive: false,
      ),
    );
    if (_closed || op != _opSeq) return;

    var url = _asPlayableUrl(video.filePath);

    if (url.startsWith('file://')) {
      final path = url.substring(7);
      var exists = await File(path).exists();
      if (!exists) {
        final resolved = await _resolveCurrentPath(video.filePath);
        if (resolved != null) {
          url = _asPlayableUrl(resolved);
          exists = true;
        }
      }
      if (!exists) {
        _setStateSafely(state.copyWith(errorMessage: '视频文件不存在：$path', playerState: PlayerState.error));
        return;
      }
    }

    await _player.open(MediaItem(url: url, title: video.name.isEmpty ? url : video.name, isVideo: true), autoPlay: false);
    if (_closed || op != _opSeq) return;
    await _player.setSpeed(speed);
    if (_closed || op != _opSeq) return;

    final startMs = video.currentPosition;
    if (startMs > 0) {
      await _player.seek(Duration(milliseconds: startMs));
    } else {
      await _seekToEffectiveStartIfNeeded();
    }
    if (_closed || op != _opSeq) return;
    await _loadFolderVideos();
    await _player.play();
  }

  void setSubtitles(List<Subtitles> list) {
    _subtitles = List<Subtitles>.from(list)..sort((a, b) => (a.startPosition).compareTo(b.startPosition));
    _setStateSafely(state.copyWith(hasSubtitles: _subtitles.isNotEmpty));
    _syncSubtitleIndexForPosition(state.position.inMilliseconds);
  }

  Future<void> reloadSubtitles(String videoCode) async {
    final list = await DatabaseService.findByCondition(
      () => Subtitles(),
      where: 'video_code = ? AND is_deleted = 0',
      whereArgs: [videoCode],
      orderBy: 'start_position ASC',
    );
    setSubtitles(list);
  }

  Future<void> togglePlayPause() async {
    if (state.playerState == PlayerState.playing) {
      await _player.pause();
      return;
    }
    // 单句暂停模式：点击播放回到当前句开头
    if (state.singleSentencePause) {
      final idx = _lastPausedSubtitleIndex ?? state.currentSubtitleIndex;
      if (idx != null && idx >= 0 && idx < _subtitles.length) {
        final sub = _subtitles[idx];
        await _player.seek(Duration(milliseconds: sub.startPosition.toInt()));
        _lastPausedSubtitleIndex = null;
        _currentSentenceIdx = null;
      }
    }
    await _player.play();
  }

  void toggleControlsVisible() {
    // 控制栏常驻显示，不再隐藏
  }

  Future<void> seekToMs(int ms) async {
    final safe = ms.clamp(0, state.duration.inMilliseconds > 0 ? state.duration.inMilliseconds : 1 << 30);
    await _player.seek(Duration(milliseconds: safe));
  }

  Future<void> setSpeed(double speed, {bool persist = true}) async {
    final v = speed.clamp(0.5, 2.0);
    await _player.setSpeed(v);
    _setStateSafely(state.copyWith(speed: v));
    if (persist) {
      await SettingsService.setPlayerPlaybackSpeed(v);
    }
  }

  Future<void> toggleSubtitleVisible() async {
    final v = !state.subtitleVisible;
    _setStateSafely(state.copyWith(subtitleVisible: v));
    await SettingsService.setPlayerSubtitleVisible(v);
  }

  Future<void> toggleTranslateVisible() async {
    final v = !state.translateVisible;
    _setStateSafely(state.copyWith(translateVisible: v));
    await SettingsService.setPlayerTranslateVisible(v);
  }

  Future<void> toggleSingleSentencePause() async {
    final v = !state.singleSentencePause;
    _setStateSafely(state.copyWith(singleSentencePause: v));
    _lastPausedSubtitleIndex = null;
    _currentSentenceIdx = null;
    await SettingsService.setPlayerSingleSentencePause(v);
  }

  Future<void> previousSentence() async {
    if (_subtitles.isEmpty) return;
    final idx = state.currentSubtitleIndex ?? _indexForPosition(state.position.inMilliseconds) ?? 0;
    final next = (idx - 1).clamp(0, _subtitles.length - 1);
    await _jumpToSubtitle(next, restartSlowToFast: true);
  }

  Future<void> nextSentence() async {
    if (_subtitles.isEmpty) return;
    final idx = state.currentSubtitleIndex ?? _indexForPosition(state.position.inMilliseconds) ?? 0;
    final next = (idx + 1).clamp(0, _subtitles.length - 1);
    await _jumpToSubtitle(next, restartSlowToFast: true);
  }

  Future<void> toggleSlowToFastCurrentSentence() async {
    if (_slowToFastActive) {
      await _stopSlowToFast();
      return;
    }
    await _startSlowToFast();
  }

  void setLoopingMode(String mode) {
    _setStateSafely(state.copyWith(loopingMode: mode));
  }

  void setShutdownTimer(int seconds) {
    _shutdownTimer?.cancel();
    _shutdownTimer = null;
    _setStateSafely(state.copyWith(shutdownTimerSeconds: seconds));
    if (seconds > 0) {
      _shutdownTimer = Timer(Duration(seconds: seconds), () {
        if (_closed) return;
        _setStateSafely(state.copyWith(shutdownTimerSeconds: 0));
        unawaited(_player.pause());
      });
    }
  }

  void _handlePlayerStateChange(PlayerState newState) {
    if (newState != PlayerState.completed) return;
    switch (state.loopingMode) {
      case 'single_loop':
        unawaited(_player.seek(Duration.zero).then((_) => _player.play()));
        break;
      case 'single_play':
        break;
    }
  }

  Future<void> disposePlayer() async {
    if (_closed) return;
    _shutdownTimer?.cancel();
    _shutdownTimer = null;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    if (_initialized) {
      await _saveProgress(force: true);
      await _player.dispose();
    }
    _initialized = false;
  }

  @override
  void dispose() {
    _closed = true;
    _opSeq++;
    unawaited(disposePlayer());
    super.dispose();
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _player.initialize();
    _subs.addAll([
      _player.stateStream.listen((s) {
        if (_closed) return;
        _handlePlayerStateChange(s);
        _setStateSafely(state.copyWith(playerState: s));
      }),
      _player.positionStream.listen((p) {
        if (_closed) return;
        _setStateSafely(state.copyWith(position: p));
        final ms = p.inMilliseconds;
        _syncSubtitleIndexForPosition(ms);
        unawaited(_saveProgress());
        _handleSingleSentencePauseIfNeeded(ms);
        _handleSlowToFastIfNeeded(ms);
      }),
      _player.durationStream.listen((d) {
        if (_closed) return;
        _setStateSafely(state.copyWith(duration: d));
      }),
      _player.bufferedStream.listen((b) {
        if (_closed) return;
        _setStateSafely(state.copyWith(buffered: b));
      }),
      _player.videoSizeStream.listen((s) {
        if (_closed) return;
        _setStateSafely(state.copyWith(videoSize: s));
      }),
      _player.errorStream.listen((msg) {
        if (_closed) return;
        _setStateSafely(state.copyWith(errorMessage: msg, playerState: PlayerState.error));
      }),
    ]);
    _initialized = true;
  }

  Future<VideoInfo?> _findVideo(String code) async {
    final list = await DatabaseService.findByCondition(() => VideoInfo(), where: 'code = ? AND is_deleted = 0', whereArgs: [code], limit: 1);
    return list.isNotEmpty ? list.first : null;
  }

  Future<VideoFolder?> _findFolder(String folderCode) async {
    if (folderCode.isEmpty) return null;
    final list = await DatabaseService.findByCondition(() => VideoFolder(), where: 'code = ? AND is_deleted = 0', whereArgs: [folderCode], limit: 1);
    return list.isNotEmpty ? list.first : null;
  }

  String _asPlayableUrl(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return v;
    if (v.startsWith('http://') || v.startsWith('https://') || v.startsWith('rtsp://') || v.startsWith('rtmp://')) {
      return v;
    }
    if (v.startsWith('file://')) return v;
    if (v.startsWith('/')) return 'file://$v';
    if (Platform.isAndroid || Platform.isIOS) {
      return 'file://$v';
    }
    return v;
  }

  Future<String?> _resolveCurrentPath(String storedPath) async {
    final idx = storedPath.indexOf('Documents/');
    if (idx == -1) return null;
    final relative = storedPath.substring(idx + 'Documents/'.length);
    final currentDocs = (await getApplicationDocumentsDirectory()).path;
    final candidate = '$currentDocs/$relative';
    if (await File(candidate).exists()) return candidate;
    return null;
  }

  Future<void> _saveProgress({bool force = false}) async {
    if (_closed) return;
    final video = _video;
    if (video == null || video.code == null) return;

    final now = DateTime.now();
    final last = _lastProgressSavedAt;
    if (!force && last != null && now.difference(last).inSeconds < 5) return;

    _lastProgressSavedAt = now;
    final pos = state.position.inMilliseconds;
    video.currentPosition = pos;
    video.playDate = now;

    try {
      await DatabaseService.update(video);
      final folder = _folder;
      if (folder != null && folder.code != null) {
        folder.lastVideoCode = video.code!;
        folder.lastPlayDate = now;
        folder.lastPlayDuration = pos;
        await DatabaseService.update(folder);
      }
    } catch (_) {}
  }

  void _syncSubtitleIndexForPosition(int positionMs) {
    if (_closed) return;
    final idx = _indexForPosition(positionMs);
    if (idx == null) return;
    if (state.currentSubtitleIndex != idx) {
      _setStateSafely(state.copyWith(currentSubtitleIndex: idx));
      if (idx != _lastPausedSubtitleIndex) {
        _lastPausedSubtitleIndex = null;
      }
    }
  }

  int? _indexForPosition(int positionMs) {
    if (_subtitles.isEmpty) return null;
    final ms = positionMs;
    for (int i = 0; i < _subtitles.length; i++) {
      final s = _subtitles[i];
      final start = s.startPosition.toInt();
      final end = s.endPosition.toInt();
      if (ms >= start && ms < end) return i;
    }
    if (ms < _subtitles.first.startPosition.toInt()) return 0;
    if (ms >= _subtitles.last.endPosition.toInt()) return _subtitles.length - 1;
    int lo = 0;
    int hi = _subtitles.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final s = _subtitles[mid];
      final start = s.startPosition.toInt();
      final end = s.endPosition.toInt();
      if (ms < start) {
        hi = mid - 1;
      } else if (ms >= end) {
        lo = mid + 1;
      } else {
        return mid;
      }
    }
    return lo.clamp(0, _subtitles.length - 1);
  }

  Future<void> _jumpToSubtitle(int index, {required bool restartSlowToFast}) async {
    if (_subtitles.isEmpty) return;
    final i = index.clamp(0, _subtitles.length - 1);
    final s = _subtitles[i];
    _setStateSafely(state.copyWith(currentSubtitleIndex: i));
    _lastPausedSubtitleIndex = null;
    _currentSentenceIdx = null;
    await _player.seek(Duration(milliseconds: s.startPosition.toInt()));
    if (restartSlowToFast && _slowToFastActive) {
      await _startSlowToFast();
      return;
    }
    await _player.play();
  }

  void _handleSingleSentencePauseIfNeeded(int positionMs) {
    if (!state.singleSentencePause) return;
    if (_slowToFastActive) return;
    if (state.playerState != PlayerState.playing) return;
    if (_subtitles.isEmpty) return;

    final actualIdx = _indexForPosition(positionMs);
    if (actualIdx == null) return;

    // 开始跟踪当前正在播放的句子
    _currentSentenceIdx ??= actualIdx;

    final trackedIdx = _currentSentenceIdx!;
    if (trackedIdx >= _subtitles.length) return;

    // 等待句子真正播放完（位置超过其结束时间）
    final trackedEnd = _subtitles[trackedIdx].endPosition.toInt();
    if (positionMs < trackedEnd) return;

    // 句子已完整播放完，暂停
    if (_lastPausedSubtitleIndex == trackedIdx) return;
    _lastPausedSubtitleIndex = trackedIdx;
    _currentSentenceIdx = null;
    unawaited(_player.pause());
  }

  Future<void> _startSlowToFast() async {
    if (_subtitles.isEmpty) return;
    final idx = state.currentSubtitleIndex ?? _indexForPosition(state.position.inMilliseconds);
    if (idx == null) return;
    final s = _subtitles[idx];
    _slowStartMs = s.startPosition.toInt();
    _slowEndMs = s.endPosition.toInt();
    _slowOriginalSpeed = state.speed;
    _slowToFastStep = 0;
    _slowSpeedSeq = _buildSlowToFastSeq(_slowOriginalSpeed);
    if (_slowSpeedSeq.isEmpty) return;

    _slowToFastActive = true;
    _setStateSafely(state.copyWith(slowToFastActive: true));
    await _applySlowToFastStep(0);
  }

  Future<void> _stopSlowToFast() async {
    if (!_slowToFastActive) return;
    _slowToFastActive = false;
    _slowToFastTransitioning = false;
    _setStateSafely(state.copyWith(slowToFastActive: false));
    await _player.setSpeed(_slowOriginalSpeed);
    _setStateSafely(state.copyWith(speed: _slowOriginalSpeed));
  }

  List<double> _buildSlowToFastSeq(double base) {
    final factors = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final set = <double>{};
    for (final f in factors) {
      final v = (base * f).clamp(0.5, 2.0);
      set.add(double.parse(v.toStringAsFixed(2)));
    }
    final list = set.toList()..sort();
    return list;
  }

  void _handleSlowToFastIfNeeded(int positionMs) {
    if (!_slowToFastActive) return;
    if (_slowToFastTransitioning) return;
    if (state.playerState != PlayerState.playing) return;
    if (positionMs < _slowEndMs - 120) return;
    unawaited(_advanceSlowToFastStep());
  }

  Future<void> _advanceSlowToFastStep() async {
    if (!_slowToFastActive) return;
    if (_slowToFastTransitioning) return;
    _slowToFastTransitioning = true;
    try {
      final next = _slowToFastStep + 1;
      if (next < _slowSpeedSeq.length) {
        _slowToFastStep = next;
        await _applySlowToFastStep(next);
        return;
      }
      _slowToFastActive = false;
      _setStateSafely(state.copyWith(slowToFastActive: false));
      await _player.setSpeed(_slowOriginalSpeed);
      _setStateSafely(state.copyWith(speed: _slowOriginalSpeed));
      await _player.seek(Duration(milliseconds: _slowEndMs));
      await _player.play();
    } finally {
      _slowToFastTransitioning = false;
    }
  }

  Future<void> _applySlowToFastStep(int step) async {
    if (!_slowToFastActive) return;
    _slowToFastTransitioning = true;
    try {
      final v = _slowSpeedSeq[step].clamp(0.5, 2.0);
      await _player.setSpeed(v);
      _setStateSafely(state.copyWith(speed: v));
      await _player.seek(Duration(milliseconds: _slowStartMs));
      await _player.play();
    } finally {
      _slowToFastTransitioning = false;
    }
  }

  void _setStateSafely(PlayerEngineState next) {
    if (_closed) return;
    state = next;
  }

  Future<void> _loadFolderVideos() async {
    final folderCode = _video?.folderCode;
    if (folderCode == null || folderCode.isEmpty) return;
    final videos = await DatabaseService.findByCondition(
      () => VideoInfo(),
      where: 'folder_code = ? AND is_deleted = 0',
      whereArgs: [folderCode],
      orderBy: 'created_at ASC',
    );
    _setStateSafely(state.copyWith(folderVideos: videos));
  }

  Future<void> switchToVideo(String videoCode) async {
    await _player.pause();
    await openVideoByCode(videoCode);
    unawaited(reloadSubtitles(videoCode));
  }

  Future<void> _seekToEffectiveStartIfNeeded() async {
    final folder = _folder;
    if (folder == null) return;
    final startMs = folder.skipOpening ? folder.skipOpeningDuration * 1000 : 0;
    if (startMs <= 0) return;
    await _player.seek(Duration(milliseconds: startMs));
  }

  /// Public getter for subtitles list
  List<Subtitles> get subtitles => _subtitles;

  /// Seek to subtitle index (no auto-play)
  Future<void> jumpToSubtitle(int index) => _jumpToSubtitle(index, restartSlowToFast: false);

  /// Set single sentence pause mode (not toggle)
  void setSingleSentencePause(bool value) {
    _setStateSafely(state.copyWith(singleSentencePause: value));
    _lastPausedSubtitleIndex = null;
    _currentSentenceIdx = null;
    SettingsService.setPlayerSingleSentencePause(value);
  }

  /// Reset the pause flag (used when user manually clicks play)
  void resetPauseFlag() {
    _lastPausedSubtitleIndex = null;
    _currentSentenceIdx = null;
  }
}
