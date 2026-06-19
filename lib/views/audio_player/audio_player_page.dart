import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:omni_player/omni_player.dart';
import 'package:record/record.dart';
import 'package:vidlang/models/recording_record.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/providers/player_engine_provider.dart';
import 'package:vidlang/services/audio_recognition_service.dart';
import 'package:vidlang/config.dart';
import 'package:vidlang/services/conversation_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/file_picker_service.dart';
import 'package:vidlang/services/initial_letter_cover.dart';
import 'package:vidlang/services/lrc_parser.dart';
import 'package:vidlang/services/shengtong_evaluator.dart';
import 'package:vidlang/services/thumbnail_service.dart';
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/views/audio_player/subtitle_list_widget.dart';
import 'package:vidlang/views/audio_player/recognition_prompt_dialog.dart';
import 'package:vidlang/widgets/word_card.dart';
import 'package:vidlang/services/word_book_service.dart';

class AudioPlayerPage extends ConsumerStatefulWidget {
  final String videoCode;
  final List<VideoInfo>? folderVideos;
  final String audioType;

  const AudioPlayerPage({
    super.key,
    required this.videoCode,
    this.folderVideos,
    this.audioType = 'music',
  });

  @override
  ConsumerState<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends ConsumerState<AudioPlayerPage> with WidgetsBindingObserver {
  bool _initialized = false;
  bool _showSettings = false;
  bool _showAudioList = false;
  bool? _hasHeadphone;
  List<VideoInfo>? _folderVideosOverride;
  String? _resolvedCoverPath;

  // Subtitle list ref for scrolling
  final GlobalKey<SubtitleListViewState> _subtitleListKey = GlobalKey();

  // Follow recording
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;
  bool _isEvaluating = false;
  ShengtongEvaluator? _evaluator;
  Timer? _autoStopTimer;
  DateTime? _recordingStartTime;

  final ap.AudioPlayer _aliAudioPlayer = ap.AudioPlayer();

  static const _supportedEvalLanguages = {'en', 'fr', 'ja', 'ko'};

  double _playbackSpeed = 1.0;

  // Drawer mutual exclusion
  bool get _drawerOpen => _showSettings || _showAudioList;

  List<double> get _speedOptions {
    final isMusic = widget.audioType == 'music';
    return isMusic ? [0.5, 0.75, 1.0, 1.25, 1.5] : [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    Future.microtask(() => _initializePlayer());
    _checkHeadphone();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final notifier = ref.read(playerEngineProvider.notifier);
      if (ref.read(playerEngineProvider).playerState == PlayerState.playing) {
        notifier.togglePlayPause();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoStopTimer?.cancel();
    _aliAudioPlayer.dispose();
    _evaluator?.dispose();
    _recorder.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _checkHeadphone() async {
    final has = await _detectHeadphoneMode();
    if (mounted) setState(() => _hasHeadphone = has);
  }

  // ─── Initialization ──────────────────────────────

  Future<void> _initializePlayer() async {
    if (_initialized) return;
    _initialized = true;
    final notifier = ref.read(playerEngineProvider.notifier);
    await notifier.openAudioByCode(widget.videoCode, widget.audioType);
    await notifier.reloadSubtitles(widget.videoCode);

    if (widget.folderVideos != null) {
      if (mounted) setState(() => _folderVideosOverride = widget.folderVideos);
    } else {
      await _loadFolderVideos();
    }

    _resolveCover();

    final state = ref.read(playerEngineProvider);
    if (!state.hasSubtitles && mounted) {
      _showNoSubtitlePrompt();
    }
  }

  Future<void> _loadFolderVideos() async {
    final videos = await DatabaseService.findByCondition(
      () => VideoInfo(), where: 'code = ? AND is_deleted = 0', whereArgs: [widget.videoCode]);
    if (videos.isEmpty) return;
    final fc = videos.first.folderCode;
    if (fc.isEmpty) return;
    final fv = await DatabaseService.findByCondition(
      () => VideoInfo(), where: 'folder_code = ? AND is_deleted = 0',
      whereArgs: [fc], orderBy: 'created_at ASC');
    if (mounted) setState(() => _folderVideosOverride = fv);
  }

  Future<void> _resolveCover() async {
    final video = ref.read(playerEngineProvider.notifier).currentVideo;
    if (video == null) return;

    String? coverFile;
    if (video.currentCover != null && video.currentCover!.isNotEmpty) {
      coverFile = video.currentCover;
    } else if (video.cover != null && video.cover!.isNotEmpty) {
      coverFile = video.cover;
    }

    if (coverFile != null && coverFile.isNotEmpty) {
      final fullPath = await ThumbnailService.getFullPath(coverFile);
      if (File(fullPath).existsSync()) {
        if (mounted) setState(() => _resolvedCoverPath = fullPath);
        return;
      }
    }

    // Try ID3 tags
    if (video.artist == null && video.album == null) {
      final id3Tags = await AudioRecognitionService.extractId3Tags(video.filePath);
      if (id3Tags != null) {
        if (id3Tags.artist != null) video.artist = id3Tags.artist;
        if (id3Tags.album != null) video.album = id3Tags.album;
        if (id3Tags.title != null && video.name.isEmpty) video.name = id3Tags.title!;
        if (id3Tags.coverData != null) {
          final coverCode = '${DateTime.now().millisecondsSinceEpoch}';
          final coverPath = 'covers/${video.folderCode}/$coverCode.jpg';
          final fullPath = await ThumbnailService.getFullPath(coverPath);
          final dir = Directory(fullPath).parent;
          if (!await dir.exists()) await dir.create(recursive: true);
          await File(fullPath).writeAsBytes(id3Tags.coverData!);
          video.cover = coverPath;
          video.coverSource = 'id3';
          coverFile = coverPath;
        }
        await DatabaseService.update(video);
        ref.read(playerEngineProvider.notifier).openAudioByCode(widget.videoCode, widget.audioType);
      }
    }

    // Generate initial letter cover
    if (coverFile == null || coverFile.isEmpty) {
      final generated = await InitialLetterCover.generate(video.name, video.folderCode);
      if (generated != null) {
        video.cover = generated;
        video.coverSource = 'initial_letter';
        await DatabaseService.update(video);
        coverFile = generated;
      }
    }

    if (coverFile != null && coverFile.isNotEmpty) {
      final fullPath = await ThumbnailService.getFullPath(coverFile);
      if (File(fullPath).existsSync() && mounted) {
        setState(() => _resolvedCoverPath = fullPath);
      }
    }
  }

  // ─── Smart Match / Import ────────────────────────

  void _showNoSubtitlePrompt() {
    final video = ref.read(playerEngineProvider.notifier).currentVideo;
    showDialog(
      context: context, barrierDismissible: true,
      builder: (ctx) => RecognitionPromptDialog(
        audioType: widget.audioType,
        onSmartMatch: () { Navigator.pop(ctx); _startSmartMatch(); },
        onManualImport: () { Navigator.pop(ctx); _importSubtitle(); },
        onAppreciate: () => Navigator.pop(ctx),
        videoName: video?.name ?? '',
      ),
    );
  }

  Future<void> _startSmartMatch() async {
    final video = ref.read(playerEngineProvider.notifier).currentVideo;
    if (video == null) return;

    if (widget.audioType == 'music') {
      final hasArtistInfo = (video.artist != null && video.artist!.isNotEmpty);
      if (!hasArtistInfo) {
        final info = await _showSongInfoInputDialog(video.name);
        if (info == null) return;
        if (info['title'] != null && info['title']!.isNotEmpty) video.name = info['title']!;
        if (info['artist'] != null && info['artist']!.isNotEmpty) video.artist = info['artist'];
        await DatabaseService.update(video);
      }
    }

    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => _buildProgressDialog());

    try {
      if (widget.audioType == 'music') {
        final result = await AudioRecognitionService.searchLyrics(
          videoCode: widget.videoCode, title: video.name, artist: video.artist);
        if (!mounted) return;
        Navigator.pop(context);
        if (result.ok) {
          await AudioRecognitionService.saveLyricsResultToDb(videoCode: widget.videoCode, result: result);
          await ref.read(playerEngineProvider.notifier).reloadSubtitles(widget.videoCode);
          if (mounted) setState(() {});
          unawaited(ConversationService.uploadSubtitlesToCloud(widget.videoCode));
        } else { _showRecognitionFailed(); }
      } else {
        final result = await AudioRecognitionService.recognizeSpeech(
          videoCode: widget.videoCode, filePath: video.filePath);
        if (!mounted) return;
        Navigator.pop(context);
        if (result.ok) {
          await AudioRecognitionService.saveRecognitionResultToDb(
            videoCode: widget.videoCode, items: result.items,
            language: result.language, source: result.source);
          await ref.read(playerEngineProvider.notifier).reloadSubtitles(widget.videoCode);
          if (mounted) setState(() {});
          unawaited(ConversationService.uploadSubtitlesToCloud(widget.videoCode));
        } else { _showRecognitionFailed(); }
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      _showRecognitionFailed();
    }
  }

  void _showRecognitionFailed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('未能识别此音频内容，已转入欣赏模式')));
  }

  Future<Map<String, String>?> _showSongInfoInputDialog(String currentName) async {
    final titleCtrl = TextEditingController(text: currentName);
    final artistCtrl = TextEditingController();
    final cs = Theme.of(context).colorScheme;
    return showDialog<Map<String, String>>(
      context: context, barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lyrics_outlined, color: cs.primary, size: 28),
          const SizedBox(height: 12),
          Text('请输入歌曲信息', style: TextStyle(color: cs.onSurface, fontSize: 15.sp, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('以便搜索歌词', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.sp)),
          const SizedBox(height: 16),
          TextField(controller: titleCtrl, style: TextStyle(color: cs.onSurface, fontSize: 14.sp),
            decoration: InputDecoration(labelText: '歌曲名', labelStyle: TextStyle(color: cs.onSurfaceVariant),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.outline)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.primary)))),
          const SizedBox(height: 8),
          TextField(controller: artistCtrl, style: TextStyle(color: cs.onSurface, fontSize: 14.sp),
            decoration: InputDecoration(labelText: '演唱者', labelStyle: TextStyle(color: cs.onSurfaceVariant),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.outline)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: cs.primary)))),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('跳过,先欣赏', style: TextStyle(color: cs.onSurfaceVariant))),
            const SizedBox(width: 12),
            TextButton(onPressed: () => Navigator.pop(ctx, {'title': titleCtrl.text.trim(), 'artist': artistCtrl.text.trim()}),
              child: Text('搜索歌词', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600))),
          ]),
        ])),
      ),
    );
  }

  Widget _buildProgressDialog() {
    final cs = Theme.of(context).colorScheme;
    return PopScope(canPop: false, child: Center(child: Material(color: Colors.transparent, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: cs.primary),
        const SizedBox(height: 16),
        Text(widget.audioType == 'music' ? '正在搜索歌词...' : '正在识别音频...',
          style: TextStyle(color: cs.onSurface, fontSize: 14.sp)),
        const SizedBox(height: 8),
        Text('识别期间您可以继续收听', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.sp)),
      ]),
    ))));
  }

  Future<void> _importSubtitle() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom, allowedExtensions: ['lrc', 'srt', 'ass', 'ssa', 'vtt', 'txt'], dialogTitle: '选择字幕文件');
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.first.path;
    if (filePath == null || filePath.isEmpty) return;
    final file = File(filePath);
    if (!await file.exists()) return;

    try {
      final ext = filePath.toLowerCase();
      List<Subtitles> parsed;
      if (ext.endsWith('.lrc')) {
        parsed = LrcParser.parseContent(await file.readAsString(), widget.videoCode);
      } else {
        final stats = await FilePickerService.importSubtitleToDb(
          filePath, ref.read(playerEngineProvider.notifier).currentVideo?.folderCode ?? '', widget.videoCode);
        if (mounted) {
          await ref.read(playerEngineProvider.notifier).reloadSubtitles(widget.videoCode);
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入成功，共${stats.subtitlesInserted}条字幕')));
        }
        return;
      }
      if (parsed.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('未能解析出有效字幕')));
        return;
      }
      for (final sub in parsed) await DatabaseService.insert(sub);
      final videos = await DatabaseService.findByCondition(
        () => VideoInfo(), where: 'code = ? AND is_deleted = 0', whereArgs: [widget.videoCode], limit: 1);
      if (videos.isNotEmpty) { videos.first.hasSubtitles = true; await DatabaseService.update(videos.first); }
      if (mounted) {
        await ref.read(playerEngineProvider.notifier).reloadSubtitles(widget.videoCode);
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入成功，共${parsed.length}条歌词')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('字幕导入失败')));
    }
  }

  // ─── Build ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerEngineProvider);
    final notifier = ref.read(playerEngineProvider.notifier);
    final subtitlesList = notifier.subtitles;
    final hasSubtitles = subtitlesList.isNotEmpty;
    final idx = state.currentSubtitleIndex;
    final currentSub = (hasSubtitles && idx != null && idx >= 0 && idx < subtitlesList.length) ? subtitlesList[idx] : null;
    final isMusic = state.audioType == 'music';
    final followLabel = isMusic ? '跟唱' : '跟读';

    // Auto-scroll subtitle list
    if (idx != null && idx >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _subtitleListKey.currentState?.scrollToIndex(idx);
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // 1. Background
        _buildBackground(),
        // 1.5 Dark overlay for subtitle readability
        Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.45))),
        // 2. Full-screen subtitle list
        if (hasSubtitles)
          Positioned.fill(child: SubtitleListView(
            key: _subtitleListKey,
            subtitles: subtitlesList,
            currentIndex: idx,
            subtitleVisible: state.subtitleVisible,
            translateVisible: state.translateVisible,
            pronunciationVisible: state.pronunciationVisible,
            fontSize: state.subtitleFontSize,
            onTapSubtitle: (i) => notifier.jumpToSubtitle(i),
            onWordSelected: (words, sub) {
              if (words.isNotEmpty) {
                final wasPlaying = state.playerState == PlayerState.playing;
                notifier.player.pause();
                final selectedText = words.join(' ');
                final canSave = WordBookService.isSingleWord(selectedText);
                WordCard.show(
                  context, word: selectedText, contextSentence: sub.content,
                  isPaidMode: false,
                  onSpeak: () => TtsService().speakWord(selectedText),
                  onSaveWord: canSave ? _handleSaveWord : null,
                  sourceType: 'music', sourceCode: widget.videoCode,
                  sourceTitle: state.title, segmentCode: sub.code,
                ).then((_) {
                  if (wasPlaying && mounted) notifier.player.play();
                });
              }
            },
          ))
        else
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.music_note, size: 48, color: Colors.white24),
            const SizedBox(height: 8),
            Text('暂无字幕，可在菜单中添加', style: TextStyle(color: Colors.white38, fontSize: 12.sp)),
          ])),
        // 3. Top bar
        Positioned(top: 0, left: 0, right: 0, child: _buildTopBar(state, notifier)),
        // 4. Bottom area
        Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomArea(state, notifier, hasSubtitles, followLabel, currentSub)),
        // 5. Drawer overlay
        if (_drawerOpen)
          GestureDetector(
            onTap: () => setState(() { _showSettings = false; _showAudioList = false; }),
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.black38),
          ),
        // 6. Drawer panel
        if (_drawerOpen)
          Positioned(top: 0, right: 0, bottom: 0, child: Container(
            width: 320,
            decoration: BoxDecoration(color: AppColors.surface),
            child: _showSettings ? _buildSettingsContent(state, notifier) : _buildAudioListContent(state, notifier),
          )),
      ]),
    );
  }

  // ─── Background ──────────────────────────────────

  Widget _buildBackground() {
    final coverPath = _resolvedCoverPath;
    if (coverPath != null && File(coverPath).existsSync()) {
      return Positioned.fill(child: Image.file(
        File(coverPath), fit: BoxFit.cover,
        errorBuilder: (_, e, s) => _buildGradientBackground(),
      ));
    }
    return _buildGradientBackground();
  }

  Widget _buildGradientBackground() {
    // Deterministic gradient based on video code hash
    final hash = widget.videoCode.hashCode;
    final hue1 = (hash % 360).toDouble();
    final hue2 = ((hash * 7) % 360).toDouble();
    return Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [
        HSLColor.fromAHSL(1.0, hue1, 0.5, 0.25).toColor(),
        HSLColor.fromAHSL(1.0, hue2, 0.4, 0.15).toColor(),
      ],
    ))));
  }

  // ─── Top Bar ─────────────────────────────────────

  Widget _buildTopBar(PlayerEngineState s, PlayerEngineNotifier n) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topPadding > 0 ? topPadding : 32.h, bottom: 8.h) +
          const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.black87, Colors.transparent],
      )),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context), behavior: HitTestBehavior.opaque,
          child: Padding(padding: EdgeInsets.only(right: 8.w), child: SizedBox(
            width: 44.r, height: 44.r,
            child: Center(child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20.sp)),
          )),
        ),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          Text(s.title, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          if (n.currentVideo?.artist != null)
            Text(n.currentVideo!.artist!, style: TextStyle(color: Colors.white54, fontSize: 12.sp),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        if (s.lastFollowScore != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: _scoreColor(s.lastFollowScore!).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('🎤${s.lastFollowScore!.round()}',
              style: TextStyle(color: _scoreColor(s.lastFollowScore!), fontSize: 10.sp, fontWeight: FontWeight.bold)),
          ),
        _topBtn(Icons.format_list_bulleted_rounded, () => setState(() {
          _showAudioList = !_showAudioList; _showSettings = false;
        }), active: _showAudioList),
        const SizedBox(width: 4),
        _topBtn(Icons.settings_rounded, () => setState(() {
          _showSettings = !_showSettings; _showAudioList = false;
        }), active: _showSettings),
      ]),
    );
  }

  Widget _topBtn(IconData icon, VoidCallback onTap, {bool active = false}) {
    return GestureDetector(
      onTap: onTap, behavior: HitTestBehavior.opaque,
      child: SizedBox(width: 44.r, height: 44.r,
        child: Center(child: Icon(icon, color: active ? AppColors.primary : Colors.white, size: 20.sp)),
      ),
    );
  }

  // ─── Bottom Area ─────────────────────────────────

  Widget _buildBottomArea(PlayerEngineState s, PlayerEngineNotifier n, bool hasSubtitles, String followLabel, Subtitles? currentSub) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 12),
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black87],
      )),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Follow control bar (inline, above progress)
        if (s.followModeActive && !_drawerOpen)
          _buildFollowBar(s, n, currentSub, followLabel),
        // Progress bar
        _buildProgressBar(s, n),
        // Control row
        _buildControlRow(s, n, hasSubtitles, followLabel),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _buildProgressBar(PlayerEngineState s, PlayerEngineNotifier n) {
    final p = s.duration.inMilliseconds > 0 ? s.position.inMilliseconds / s.duration.inMilliseconds : 0.0;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Text(_fmtDuration(s.position), style: TextStyle(color: Colors.white54, fontSize: 10.sp)),
        Expanded(child: SliderTheme(data: SliderThemeData(
          trackHeight: 3, activeTrackColor: AppColors.secondary,
          inactiveTrackColor: Colors.white12, thumbColor: AppColors.primary,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        ), child: Slider(
          value: p.clamp(0.0, 1.0),
          onChanged: (v) => n.seekToMs((v * s.duration.inMilliseconds).round()),
        ))),
        Text(_fmtDuration(s.duration), style: TextStyle(color: Colors.white54, fontSize: 10.sp)),
      ]),
    );
  }

  Widget _buildControlRow(PlayerEngineState s, PlayerEngineNotifier n, bool hasSubtitles, String followLabel) {
    final video = n.currentVideo;
    final language = video?.language ?? 'en';
    final evalSupported = _supportedEvalLanguages.contains(language);
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        // Left: main playback controls
        if (hasSubtitles) _ctrlBtn(Icons.skip_previous_rounded, () => n.previousSentence(), size: 28),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => n.togglePlayPause(),
          child: Container(width: 48, height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.sunsetGradient),
            child: Icon(s.playerState == PlayerState.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(width: 8),
        if (hasSubtitles) _ctrlBtn(Icons.skip_next_rounded, () => n.nextSentence(), size: 28),
        const Spacer(),
        // Right: feature buttons
        if (hasSubtitles) _miniBtn('单句', s.singleSentencePause, () => n.toggleSingleSentencePause()),
        if (hasSubtitles) const SizedBox(width: 6),
        _miniBtn('${s.speed.toStringAsFixed(1)}x', s.speed != 1.0, () => _showSpeedMenu(n)),
        if (hasSubtitles && evalSupported) ...[
          const SizedBox(width: 6),
          _miniBtn(followLabel, s.followModeActive, () {
            if (s.followModeActive) n.exitFollowMode(); else n.enterFollowMode();
          }),
        ],
      ]),
    );
  }

  Widget _ctrlBtn(IconData icon, VoidCallback onTap, {double size = 24}) {
    return GestureDetector(
      onTap: onTap, behavior: HitTestBehavior.opaque,
      child: SizedBox(width: 44, height: 44,
        child: Center(child: Icon(icon, color: Colors.white, size: size))),
    );
  }

  Widget _miniBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.3) : Colors.white12,
          borderRadius: BorderRadius.circular(14),
          border: active ? Border.all(color: AppColors.primary.withValues(alpha: 0.5)) : null,
        ),
        child: Text(label, style: TextStyle(
          color: active ? AppColors.primary : Colors.white70,
          fontSize: 11.sp, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  void _showSpeedMenu(PlayerEngineNotifier n) {
    showModalBottomSheet(
      context: context, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Text('播放速度', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._speedOptions.map((sp) {
            final active = _playbackSpeed == sp;
            return GestureDetector(
              onTap: () { _playbackSpeed = sp; n.setSpeed(sp); Navigator.pop(ctx); },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: active ? Border.all(color: AppColors.primary.withValues(alpha: 0.4)) : null,
                ),
                child: Row(children: [
                  Text('${sp}X', style: TextStyle(
                    color: active ? AppColors.primary : Colors.white70, fontSize: 15.sp,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal)),
                  const Spacer(),
                  if (active) Icon(Icons.check_rounded, color: AppColors.primary, size: 18),
                ]),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ))),
    );
  }

  // ─── Follow Control Bar ──────────────────────────

  Widget _buildFollowBar(PlayerEngineState s, PlayerEngineNotifier n, Subtitles? currentSub, String followLabel) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(s.isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
            color: s.isRecording ? Colors.redAccent : AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Text(s.isRecording ? '录音中' : '准备$followLabel', style: TextStyle(color: Colors.white, fontSize: 12.sp)),
          const Spacer(),
          Text('原音:', style: TextStyle(color: Colors.white54, fontSize: 10.sp)),
          SizedBox(width: 100, child: SliderTheme(data: SliderThemeData(
            trackHeight: 2, activeTrackColor: AppColors.primary, inactiveTrackColor: Colors.white12,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4), thumbColor: AppColors.primary,
          ), child: Slider(value: s.originalVolume, onChanged: (v) => n.setOriginalVolume(v)))),
          Text('${(s.originalVolume * 100).round()}%', style: TextStyle(color: Colors.white54, fontSize: 10.sp)),
        ]),
        const SizedBox(height: 8),
        if (_hasHeadphone == false)
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.headphones_outlined, size: 14, color: AppColors.warning),
            const SizedBox(width: 4),
            Text('建议佩戴耳机', style: TextStyle(color: AppColors.warning, fontSize: 10.sp)),
          ])),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(
            onTap: s.isRecording ? null : () => _startFollowRecording(s, n, currentSub),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: s.isRecording ? Colors.white24 : AppColors.primary, borderRadius: BorderRadius.circular(20)),
              child: Text(s.isRecording ? '录音中...' : '开始$followLabel',
                style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600)),
            ),
          ),
          if (s.isRecording) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _stopFollowRecording(s, n, currentSub),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20)),
                child: Text('停止', style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  // ─── Settings Drawer ─────────────────────────────

  Widget _buildSettingsContent(PlayerEngineState s, PlayerEngineNotifier n) {
    return Column(children: [
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surfaceElevated, border: Border(bottom: BorderSide(color: Colors.white12))),
        child: Row(children: [
          Text('设置', style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold)),
          const Spacer(),
          GestureDetector(onTap: () => setState(() => _showSettings = false),
            child: Icon(Icons.close_rounded, color: Colors.white54, size: 20)),
        ]),
      ),
      Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [
        _settingSwitch('字幕显示', s.subtitleVisible, () => n.toggleSubtitleVisible()),
        _settingSwitch('中文注音', s.pronunciationVisible, () => n.togglePronunciationVisible()),
        _settingSwitch('中文翻译', s.translateVisible, () => n.toggleTranslateVisible()),
        const SizedBox(height: 12),
        _settingLabel('字幕字号'),
        SliderTheme(data: SliderThemeData(
          trackHeight: 3, activeTrackColor: AppColors.primary, inactiveTrackColor: Colors.white12,
          thumbColor: AppColors.primary, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        ), child: Slider(
          value: s.subtitleFontSize, min: 14, max: 36, divisions: 11,
          label: '${s.subtitleFontSize.round()}',
          onChanged: (v) => n.setSubtitleFontSize(v.roundToDouble()),
        )),
        const SizedBox(height: 8),
        _settingLabel('循环模式'),
        Wrap(spacing: 8, children: ['single_loop', 'list_loop', 'random'].map((mode) {
          final labels = {'single_loop': '单曲循环', 'list_loop': '列表循环', 'random': '随机播放'};
          final active = s.loopingMode == mode;
          return GestureDetector(
            onTap: () => n.setLoopingMode(mode),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.white12, borderRadius: BorderRadius.circular(10)),
              child: Text(labels[mode] ?? mode, style: TextStyle(
                color: active ? Colors.white : Colors.white70, fontSize: 12.sp))),
          );
        }).toList()),
        const SizedBox(height: 16),
        _settingLabel('智能匹配字幕'),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () { setState(() => _showSettings = false); _startSmartMatch(); },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('开始智能匹配', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
            ])),
        ),
        const SizedBox(height: 8),
        _settingLabel('手动导入字幕'),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () { setState(() => _showSettings = false); _importSubtitle(); },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.upload_file_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('选择字幕文件', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
            ])),
        ),
      ])),
    ]);
  }

  Widget _settingSwitch(String label, bool value, VoidCallback onChanged) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
      Text(label, style: TextStyle(color: Colors.white, fontSize: 13.sp)),
      const Spacer(),
      Switch(value: value, onChanged: (_) => onChanged(),
        activeThumbColor: AppColors.primary, inactiveThumbColor: Colors.white38),
    ]));
  }

  Widget _settingLabel(String label) {
    return Text(label, style: TextStyle(color: Colors.white54, fontSize: 11.sp, fontWeight: FontWeight.w500));
  }

  // ─── Audio List Drawer ───────────────────────────

  Widget _buildAudioListContent(PlayerEngineState s, PlayerEngineNotifier n) {
    final list = s.folderVideos.isNotEmpty ? s.folderVideos : (_folderVideosOverride ?? const <VideoInfo>[]);
    return Column(children: [
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surfaceElevated, border: Border(bottom: BorderSide(color: Colors.white12))),
        child: Row(children: [
          Text('音频列表', style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('共 ${list.length} 首', style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
          const SizedBox(width: 12),
          GestureDetector(onTap: () => setState(() => _showAudioList = false),
            child: Icon(Icons.close_rounded, color: Colors.white54, size: 22)),
        ]),
      ),
      Expanded(child: list.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.music_off_outlined, size: 48, color: Colors.white24),
            const SizedBox(height: 8),
            Text('暂无可播音频', style: TextStyle(color: Colors.white54, fontSize: 13.sp)),
          ]))
        : ListView.builder(padding: const EdgeInsets.all(10), itemCount: list.length, itemBuilder: (_, i) {
            final v = list[i];
            final isCurrent = v.code == s.videoCode;
            final durationStr = v.duration > 0
                ? _fmtDuration(Duration(milliseconds: v.duration)) : '--:--';
            return GestureDetector(
              onTap: () {
                if (v.code != null && v.code != s.videoCode) {
                  setState(() => _showAudioList = false);
                  _switchToAudio(v.code!);
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrent ? AppColors.primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: isCurrent ? Border.all(color: AppColors.primary.withValues(alpha: 0.4)) : null,
                ),
                child: Row(children: [
                  // Cover thumbnail or index
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: isCurrent ? AppColors.primary.withValues(alpha: 0.3) : Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: isCurrent
                      ? Icon(Icons.equalizer_rounded, color: AppColors.primary, size: 22)
                      : Text('${i + 1}', style: TextStyle(color: Colors.white54, fontSize: 14.sp, fontWeight: FontWeight.w500))),
                  ),
                  const SizedBox(width: 10),
                  // Title + info
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v.name, style: TextStyle(
                      color: isCurrent ? AppColors.primary : Colors.white, fontSize: 14.sp,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      // Subtitle status
                      Icon(
                        v.hasSubtitles ? Icons.subtitles_rounded : Icons.subtitles_off_rounded,
                        size: 14, color: v.hasSubtitles ? Colors.greenAccent.withValues(alpha: 0.7) : Colors.white24),
                      const SizedBox(width: 3),
                      Text(v.hasSubtitles ? '有字幕' : '无字幕',
                        style: TextStyle(color: v.hasSubtitles ? Colors.greenAccent.withValues(alpha: 0.7) : Colors.white30, fontSize: 10.sp)),
                      const SizedBox(width: 10),
                      // Duration
                      Icon(Icons.access_time_rounded, size: 12, color: Colors.white30),
                      const SizedBox(width: 3),
                      Text(durationStr, style: TextStyle(color: Colors.white38, fontSize: 10.sp)),
                      if (v.artist != null && v.artist!.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Expanded(child: Text(v.artist!, style: TextStyle(color: Colors.white30, fontSize: 10.sp),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ]),
                  ])),
                  // Score badge
                  if (v.lastFollowScore != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _scoreColor(v.lastFollowScore!).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${v.lastFollowScore!.round()}', style: TextStyle(
                        color: _scoreColor(v.lastFollowScore!), fontSize: 12.sp, fontWeight: FontWeight.bold)),
                    ),
                ]),
              ),
            );
          })),
    ]);
  }

  Future<void> _switchToAudio(String code) async {
    final notifier = ref.read(playerEngineProvider.notifier);
    await notifier.player.pause();
    await notifier.openAudioByCode(code, widget.audioType);
    unawaited(notifier.reloadSubtitles(code));
    await _loadFolderVideos();
    _resolveCover();
    if (mounted) setState(() {});
  }

  // ─── Follow Recording Logic ──────────────────────

  Future<void> _startFollowRecording(PlayerEngineState s, PlayerEngineNotifier n, Subtitles? currentSub) async {
    if (currentSub == null) return;
    if (!await _recorder.hasPermission()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('需要麦克风权限才能跟读')));
      return;
    }

    n.setRecording(true);
    _recordingStartTime = DateTime.now();

    try {
      final tmpDir = Directory.systemTemp;
      final path = '${tmpDir.path}/follow_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      _recordingPath = path;

      // Save original volume, lower to follow volume
      final defaultVol = widget.audioType == 'music' ? 0.8 : 0.6;
      await n.setOriginalVolume(defaultVol);

      if (!s.singleSentencePause) n.setSingleSentencePause(true);
      if (s.playerState != PlayerState.playing) {
        n.seekToMs(currentSub.startPosition.toInt());
        n.togglePlayPause();
      }

      _autoStopTimer?.cancel();
      final endMs = currentSub.endPosition.toInt();
      final bufferMs = widget.audioType == 'music' ? 1000 : 500;
      final remainingMs = endMs - s.position.inMilliseconds;
      if (remainingMs > 0) {
        _autoStopTimer = Timer(Duration(milliseconds: remainingMs + bufferMs), () {
          if (mounted && ref.read(playerEngineProvider).isRecording) {
            _stopFollowRecording(ref.read(playerEngineProvider), n, currentSub);
          }
        });
      }
    } catch (_) {
      n.setRecording(false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('录音启动失败')));
    }
  }

  Future<void> _stopFollowRecording(PlayerEngineState s, PlayerEngineNotifier n, Subtitles? currentSub) async {
    _autoStopTimer?.cancel();
    if (_recordingPath == null) return;

    try { await _recorder.stop(); } catch (_) {}
    n.setRecording(false);

    // Restore volume to 100%
    await n.setOriginalVolume(1.0);

    final path = _recordingPath;
    _recordingPath = null;
    if (path == null || !File(path).existsSync()) return;
    if (currentSub == null) return;

    _evaluateRecording(path, s, n, currentSub);
  }

  Future<void> _evaluateRecording(String audioPath, PlayerEngineState s, PlayerEngineNotifier n, Subtitles sub) async {
    if (_isEvaluating) return;
    _isEvaluating = true;

    try {
      final video = n.currentVideo;
      final language = video?.language ?? 'en';
      final coreType = '$language.sent.eval';
      final userCode = video?.userCode ?? 'anonymous';

      _evaluator?.dispose();
      _evaluator = ShengtongEvaluator(appKey: AppConfig.shengtongAppKey, secretKey: AppConfig.shengtongSecretKey);

      final completer = Completer<Map<String, dynamic>?>();
      _evaluator!.onResult = (result) { if (!completer.isCompleted) completer.complete(result); };
      _evaluator!.onError = (error) { if (!completer.isCompleted) completer.complete(null); };

      await _evaluator!.connect(coreType);
      _evaluator!.start(coreType: coreType, refText: sub.content, userId: userCode);

      final audioFile = File(audioPath);
      final bytes = await audioFile.readAsBytes();
      _evaluator!.feed(bytes);
      _evaluator!.stop();

      final result = await completer.future.timeout(const Duration(seconds: 10));

      if (result != null && mounted) {
        final overall = (result['overall'] as num?)?.toDouble();
        final fluency = (result['fluency'] as num?)?.toDouble();
        final accuracy = (result['accuracy'] as num?)?.toDouble();
        final completeness = (result['completeness'] as num?)?.toDouble();

        // Calculate actual recording duration
        final recordingDurationMs = _recordingStartTime != null
            ? DateTime.now().difference(_recordingStartTime!).inMilliseconds : 0;

        final record = RecordingRecord(
          resourceCode: widget.videoCode,
          resourceType: widget.audioType,
          scope: 'sentence', sentenceCode: sub.code,
          audioPath: audioPath, durationMs: recordingDurationMs,
          overallScore: overall, fluencyScore: fluency,
          accuracyScore: accuracy, completenessScore: completeness,
          rawResultJson: result.toString(), language: language,
          refText: sub.content, subtitleIndex: s.currentSubtitleIndex,
          originalVolume: s.originalVolume, speed: s.speed,
          headphoneMode: await _detectHeadphoneMode(),
        );
        await DatabaseService.insert(record);

        if (overall != null) {
          n.setLastFollowScore(overall);
          if (video != null) { video.lastFollowScore = overall; await DatabaseService.update(video); }
        }

        _showScoreResult(overall, fluency, accuracy, completeness);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('评分服务暂时不可用')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('评分失败，请检查声通配置')));
    } finally { _isEvaluating = false; }
  }

  void _showScoreResult(double? overall, double? fluency, double? accuracy, double? completeness) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('跟读评分', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (overall != null) Text('${overall.round()}', style: TextStyle(
          color: _scoreColor(overall), fontSize: 48.sp, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          if (accuracy != null) _scoreDim('准确', accuracy),
          if (fluency != null) _scoreDim('流利', fluency),
          if (completeness != null) _scoreDim('完整', completeness),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('重录', style: TextStyle(color: AppColors.primary))),
          const SizedBox(width: 20),
          TextButton(onPressed: () {
            Navigator.pop(ctx);
            ref.read(playerEngineProvider.notifier).nextSentence();
          }, child: Text('下一句', style: TextStyle(color: AppColors.primary))),
        ]),
      ])),
    );
  }

  Widget _scoreDim(String label, double score) {
    return Column(children: [
      Text('${score.round()}', style: TextStyle(color: _scoreColor(score), fontSize: 20.sp, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: Colors.white54, fontSize: 10.sp)),
    ]);
  }

  Color _scoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.orange;
    if (score >= 60) return Colors.deepOrange;
    return Colors.red;
  }

  // ─── Helpers ─────────────────────────────────────

  Future<bool> _handleSaveWord({
    required String word, String? contextSentence,
    required String sourceType, required String sourceCode, String? sourceTitle,
  }) async {
    final notifier = ref.read(playerEngineProvider.notifier);
    final state = ref.read(playerEngineProvider);
    final video = notifier.currentVideo;
    final idx = state.currentSubtitleIndex;
    final subs = notifier.subtitles;
    final currentSub = (idx != null && idx >= 0 && idx < subs.length) ? subs[idx] : null;

    final result = await WordBookService.saveWord(
      word: word, sourceType: sourceType, sourceCode: sourceCode,
      sourceTitle: sourceTitle, contextSentence: contextSentence,
      segmentCode: currentSub?.code, videoPath: video?.filePath,
      positionMs: state.position.inMilliseconds,
    );
    return result != null;
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours, m = d.inMinutes.remainder(60), s = d.inSeconds.remainder(60);
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<bool?> _detectHeadphoneMode() async {
    try {
      final devices = await _recorder.listInputDevices();
      return devices.any((d) =>
        d.id.toLowerCase().contains('headset') || d.id.toLowerCase().contains('headphone') ||
        d.id.toLowerCase().contains('bluetooth') || d.label.toLowerCase().contains('headset') ||
        d.label.toLowerCase().contains('headphone') || d.label.toLowerCase().contains('bluetooth') ||
        d.label.toLowerCase().contains('airpods'));
    } catch (_) { return null; }
  }
}
