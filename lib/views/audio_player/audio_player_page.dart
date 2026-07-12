import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omni_player/omni_player.dart';
import 'package:record/record.dart';
import 'package:vidlang/services/app_keys_service.dart';
import 'package:vidlang/models/recording_record.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/providers/player_engine_provider.dart';
import 'package:vidlang/services/audio_recognition_service.dart';
import 'package:vidlang/services/conversation_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/file_picker_service.dart';
import 'package:vidlang/services/initial_letter_cover.dart';
import 'package:vidlang/services/lrc_parser.dart';
import 'package:vidlang/services/shengtong_http_evaluator.dart';
import 'package:vidlang/services/thumbnail_service.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/services/translation_init_service.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/widgets/app_dialogs.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/dialog_utils.dart';
import 'package:vidlang/views/audio_player/recognition_prompt_dialog.dart';
import 'package:vidlang/views/audio_player/subtitle_list_widget.dart';
import 'package:vidlang/widgets/shadow_reader/shadow_reader_component.dart';
import 'package:vidlang/widgets/word_card.dart';
import 'package:vidlang/utils/adaptive.dart';

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

class _AudioPlayerPageState extends ConsumerState<AudioPlayerPage>
    with WidgetsBindingObserver {
  bool _initialized = false;
  bool _showSettings = false;
  bool _showAudioList = false;
  bool _showFollow = false;
  bool _isTtsSpeaking = false;
  bool? _hasHeadphone;
  List<VideoInfo>? _folderVideosOverride;
  String? _resolvedCoverPath;

  // Subtitle list ref for scrolling
  final GlobalKey<SubtitleListViewState> _subtitleListKey = GlobalKey();

  // Follow recording
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;
  bool _isEvaluating = false;
  Timer? _autoStopTimer;
  DateTime? _recordingStartTime;

  final ap.AudioPlayer _aliAudioPlayer = ap.AudioPlayer();

  static const _supportedEvalLanguages = {'en', 'fr', 'ja', 'ko'};

  // Drawer mutual exclusion
  bool get _drawerOpen => _showSettings || _showAudioList;

  // Player overlay is always dark regardless of theme mode
  Color _drawerText() => AppColors.onSurface;
  Color _drawerTextVariant() => AppColors.onSurfaceVariant;

  List<double> get _speedOptions {
    final isMusic = widget.audioType == 'music';
    return isMusic
        ? [0.5, 0.75, 1.0, 1.25, 1.5]
        : [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
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
    _recorder.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
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

    // 检查并初始化翻译（借鉴视频播放器方案）
    if (mounted) {
      await _checkAndInitializeTranslation(notifier);
    }

    final state = ref.read(playerEngineProvider);
    if (!state.hasSubtitles && mounted) {
      _showNoSubtitlePrompt();
    }
  }

  Future<void> _loadFolderVideos() async {
    final videos = await DatabaseService.findByCondition(
      () => VideoInfo(),
      where: 'code = ? AND is_deleted = 0',
      whereArgs: [widget.videoCode],
    );
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

  /// v2.0: 从当前 VideoInfo 获取 folderCode（用于云端字幕上传）
  String? _resolveFolderCode() {
    final notifier = ref.read(playerEngineProvider.notifier);
    return notifier.currentVideo?.folderCode;
  }

  /// 检查并初始化翻译（借鉴视频播放器方案）
  Future<void> _checkAndInitializeTranslation(
    PlayerEngineNotifier notifier,
  ) async {
    final subtitles = notifier.subtitles;
    if (subtitles.isEmpty) return;

    final subState = ref.read(subscriptionProvider);
    final needCount = TranslationInitService.countNeedTranslate(
      subtitles,
      subState.mode,
    );
    if (needCount == 0) return;

    if (!mounted) return;
    AppToast.show(context, '正在进行翻译初始化...', type: ToastType.info);

    final currentTitle = notifier.currentVideo?.name ?? widget.videoCode;

    try {
      await TranslationInitService.translateSubtitles(
        subtitles: subtitles,
        videoCode: widget.videoCode,
        title: currentTitle,
        mode: subState.mode,
        onProgress: (current, total) {},
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Translation init failed: $e');
      if (mounted) {
        AppToast.show(context, '翻译初始化失败: $e', type: ToastType.error);
      }
    } finally {}
  }

  /// 处理清晰朗读
  void _handleClaritySpeak(
    PlayerEngineNotifier n,
    PlayerEngineState s,
    Subtitles cs,
  ) async {
    final wasPlaying = s.playerState == PlayerState.playing;
    if (wasPlaying) n.player.pause();

    setState(() => _isTtsSpeaking = true);

    final subState = ref.read(subscriptionProvider);
    await TtsService().speakClarity(
      text: cs.content,
      mode: subState.mode,
      onComplete: () {
        if (!mounted) return;
        setState(() => _isTtsSpeaking = false);
        // 单句暂停开启则保持暂停，否则恢复播放
        if (wasPlaying && !ref.read(playerEngineProvider).singleSentencePause) {
          n.player.play();
        }
      },
    );
  }

  /// 停止清晰朗读
  void _stopClaritySpeak() {
    TtsService().stop();
    setState(() => _isTtsSpeaking = false);
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
      final id3Tags = await AudioRecognitionService.extractId3Tags(
        video.filePath,
      );
      if (id3Tags != null) {
        if (id3Tags.artist != null) video.artist = id3Tags.artist;
        if (id3Tags.album != null) video.album = id3Tags.album;
        if (id3Tags.title != null && video.name.isEmpty) {
          video.name = id3Tags.title!;
        }
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
        ref
            .read(playerEngineProvider.notifier)
            .openAudioByCode(widget.videoCode, widget.audioType);
      }
    }

    // Generate initial letter cover
    if (coverFile == null || coverFile.isEmpty) {
      final generated = await InitialLetterCover.generate(
        video.name,
        video.folderCode,
      );
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
    DialogUtils.show(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => RecognitionPromptDialog(
        audioType: widget.audioType,
        onSmartMatch: () {
          Navigator.pop(ctx);
          _startSmartMatch();
        },
        onManualImport: () {
          Navigator.pop(ctx);
          _importSubtitle();
        },
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
        if (info['title'] != null && info['title']!.isNotEmpty) {
          video.name = info['title']!;
        }
        if (info['artist'] != null && info['artist']!.isNotEmpty) {
          video.artist = info['artist'];
        }
        await DatabaseService.update(video);
      }
    }

    if (!mounted) return;
    DialogUtils.show(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildProgressDialog(),
    );

    try {
      if (widget.audioType == 'music') {
        final result = await AudioRecognitionService.searchLyrics(
          videoCode: widget.videoCode,
          title: video.name,
          artist: video.artist,
        );
        if (!mounted) return;
        Navigator.pop(context);
        if (result.ok) {
          await AudioRecognitionService.saveLyricsResultToDb(
            videoCode: widget.videoCode,
            result: result,
          );
          await ref
              .read(playerEngineProvider.notifier)
              .reloadSubtitles(widget.videoCode);
          if (mounted) setState(() {});
          unawaited(
            ConversationService.uploadSubtitlesToCloud(widget.videoCode, folderCode: _resolveFolderCode()),
          );
        } else {
          _showRecognitionFailed();
        }
      } else {
        final result = await AudioRecognitionService.recognizeSpeech(
          videoCode: widget.videoCode,
          filePath: video.filePath,
        );
        if (!mounted) return;
        Navigator.pop(context);
        if (result.ok) {
          await AudioRecognitionService.saveRecognitionResultToDb(
            videoCode: widget.videoCode,
            items: result.items,
            language: result.language,
            source: result.source,
          );
          await ref
              .read(playerEngineProvider.notifier)
              .reloadSubtitles(widget.videoCode);
          if (mounted) setState(() {});
          unawaited(
            ConversationService.uploadSubtitlesToCloud(widget.videoCode, folderCode: _resolveFolderCode()),
          );
        } else {
          _showRecognitionFailed();
        }
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      _showRecognitionFailed();
    }
  }

  void _showRecognitionFailed() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('未能识别此音频内容，已转入欣赏模式')));
  }

  Future<Map<String, String>?> _showSongInfoInputDialog(
    String currentName,
  ) async {
    final titleCtrl = TextEditingController(text: currentName);
    final artistCtrl = TextEditingController();
    final cs = Theme.of(context).colorScheme;
    return DialogUtils.show<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.lyrics, color: cs.primary, size: 28),
              const SizedBox(height: 12),
              Text(
                '请输入歌曲信息',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: Adaptive.sp(context, 15),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '以便搜索歌词',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: Adaptive.sp(context, 12)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                style: TextStyle(color: cs.onSurface, fontSize: Adaptive.sp(context, 14)),
                decoration: InputDecoration(
                  labelText: '歌曲名',
                  labelStyle: TextStyle(color: cs.onSurfaceVariant),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: cs.outline),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: cs.primary),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: artistCtrl,
                style: TextStyle(color: cs.onSurface, fontSize: Adaptive.sp(context, 14)),
                decoration: InputDecoration(
                  labelText: '演唱者',
                  labelStyle: TextStyle(color: cs.onSurfaceVariant),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: cs.outline),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: cs.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      '跳过,先欣赏',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, {
                      'title': titleCtrl.text.trim(),
                      'artist': artistCtrl.text.trim(),
                    }),
                    child: Text(
                      '搜索歌词',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDialog() {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: cs.primary),
                const SizedBox(height: 16),
                Text(
                  widget.audioType == 'music' ? '正在搜索歌词...' : '正在识别音频...',
                  style: TextStyle(color: cs.onSurface, fontSize: Adaptive.sp(context, 14)),
                ),
                const SizedBox(height: 8),
                Text(
                  '识别期间您可以继续收听',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: Adaptive.sp(context, 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _importSubtitle() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['lrc', 'srt', 'ass', 'ssa', 'vtt', 'txt'],
      dialogTitle: '选择字幕文件',
    );
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.first.path;
    if (filePath == null || filePath.isEmpty) return;
    final file = File(filePath);
    if (!await file.exists()) return;

    try {
      final ext = filePath.toLowerCase();
      List<Subtitles> parsed;
      if (ext.endsWith('.lrc')) {
        parsed = LrcParser.parseContent(
          await file.readAsString(),
          widget.videoCode,
        );
      } else {
        final stats = await FilePickerService.importSubtitleToDb(
          filePath,
          ref.read(playerEngineProvider.notifier).currentVideo?.folderCode ??
              '',
          widget.videoCode,
        );
        if (mounted) {
          await ref
              .read(playerEngineProvider.notifier)
              .reloadSubtitles(widget.videoCode);
          setState(() {});
          // ✅ TDesign 规范：使用 TDToast 替代 SnackBar
          TDToast.showSuccess('导入成功，共${stats.subtitlesInserted}条字幕', context: context);
        }
        return;
      }
      if (parsed.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('未能解析出有效字幕')));
        }
        return;
      }
      for (final sub in parsed) {
        await DatabaseService.insert(sub);
      }
      final videos = await DatabaseService.findByCondition(
        () => VideoInfo(),
        where: 'code = ? AND is_deleted = 0',
        whereArgs: [widget.videoCode],
        limit: 1,
      );
      if (videos.isNotEmpty) {
        videos.first.hasSubtitles = true;
        await DatabaseService.update(videos.first);
      }
      if (mounted) {
        await ref
            .read(playerEngineProvider.notifier)
            .reloadSubtitles(widget.videoCode);
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入成功，共${parsed.length}条歌词')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('字幕导入失败')));
      }
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
    final currentSub =
        (hasSubtitles && idx != null && idx >= 0 && idx < subtitlesList.length)
        ? subtitlesList[idx]
        : null;
    final isMusic = state.audioType == 'music';
    final followLabel = isMusic ? '跟唱' : '跟读';

    // Auto-scroll subtitle list
    if (idx != null && idx >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _subtitleListKey.currentState?.scrollToIndex(idx);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Background with blur
          _buildBackground(),
          // 1.5 Dark overlay for subtitle readability
          Positioned.fill(
            child: Container(color: AppColors.background.withValues(alpha: 0.55)),
          ),
          // 2. Full-screen subtitle list
          if (hasSubtitles)
            Positioned.fill(
              child: SubtitleListView(
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
                    final subState = ref.read(subscriptionProvider);
                    final isPremium = subState.mode == SubscriptionMode.premium;
                    WordCard.show(
                      context,
                      word: selectedText,
                      contextSentence: sub.content,
                      isPaidMode: isPremium,
                      onSpeak: () => TtsService().speakWord(selectedText),
                      onSaveWord: canSave ? _handleSaveWord : null,
                      sourceType: 'music',
                      sourceCode: widget.videoCode,
                      sourceTitle: state.title,
                      segmentCode: sub.code,
                    ).then((_) {
                      if (wasPlaying && mounted) notifier.player.play();
                    });
                  }
                },
              ),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.musicNote, size: Adaptive.icon(context, 48), color: AppColors.onSurface.withValues(alpha: 0.24)),
                  SizedBox(height: Adaptive.h(context, 8)),
                  Text(
                    '暂无字幕，可在菜单中添加',
                    style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.38), fontSize: Adaptive.sp(context, 14)),
                  ),
                ],
              ),
            ),
          // 3. Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(state, notifier),
          ),
          // 4. Bottom area
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomArea(
              state,
              notifier,
              hasSubtitles,
              followLabel,
              currentSub,
            ),
          ),
          // 4.5 Follow panel (inline overlay)
          if (_showFollow && currentSub != null && !_drawerOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildFollowPanel(state, notifier, currentSub),
            ),
          // 5. Drawer overlay
          if (_drawerOpen)
            GestureDetector(
              onTap: () => setState(() {
                _showSettings = false;
                _showAudioList = false;
              }),
              behavior: HitTestBehavior.translucent,
              child: Container(color: AppColors.background.withValues(alpha: 0.4)),
            ),
          // 6. Drawer panel
          if (_drawerOpen)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: MediaQuery.of(context).size.width > 600 ? 440 : 320,
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.85),
                      border: Border(
                        left: BorderSide(
                          color: AppColors.onSurface.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      left: false,
                      child: _showSettings
                          ? _buildSettingsContent(state, notifier)
                          : _buildAudioListContent(state, notifier),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Background ──────────────────────────────────

  Widget _buildBackground() {
    final coverPath = _resolvedCoverPath;
    if (coverPath != null && File(coverPath).existsSync()) {
      return Positioned.fill(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0),
            child: Image.file(
              File(coverPath),
              fit: BoxFit.cover,
              errorBuilder: (_, e, s) => _buildGradientBackground(),
            ),
          ),
        ),
      );
    }
    return _buildGradientBackground();
  }

  Widget _buildGradientBackground() {
    // Deterministic gradient based on video code hash
    final hash = widget.videoCode.hashCode;
    final hue1 = (hash % 360).toDouble();
    final hue2 = ((hash * 7) % 360).toDouble();
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              HSLColor.fromAHSL(1.0, hue1, 0.5, 0.25).toColor(),
              HSLColor.fromAHSL(1.0, hue2, 0.4, 0.15).toColor(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Top Bar ─────────────────────────────────────

  Widget _buildTopBar(PlayerEngineState s, PlayerEngineNotifier n) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding:
          EdgeInsets.only(
            top: topPadding > 0 ? topPadding : Adaptive.h(context, 32),
            bottom: Adaptive.h(context, 8),
          ) +
          const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.background.withValues(alpha: 0.87), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(Adaptive.r(context, 22)),
              child: Padding(
                padding: EdgeInsets.only(right: Adaptive.w(context, 8)),
                child: SizedBox(
                  width: Adaptive.r(context, 44),
                  height: Adaptive.r(context, 44),
                  child: Center(
                    child: Icon(
                      AppIcons.arrowBackIosNew,
                      color: AppColors.onSurface,
                      size: Adaptive.sp(context, 20),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.title,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: Adaptive.sp(context, 20),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (n.currentVideo?.artist != null)
                  Text(
                    n.currentVideo!.artist!,
                    style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.54), fontSize: Adaptive.sp(context, 12)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (s.lastFollowScore != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: _scoreColor(s.lastFollowScore!).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '🎤${s.lastFollowScore!.round()}',
                style: TextStyle(
                  color: _scoreColor(s.lastFollowScore!),
                  fontSize: Adaptive.sp(context, 14),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          _topBtn(
            AppIcons.formatListBulleted,
            () => setState(() {
              _showAudioList = !_showAudioList;
              _showSettings = false;
            }),
            active: _showAudioList,
          ),
          const SizedBox(width: 4),
          _topBtn(
            AppIcons.settings,
            () => setState(() {
              _showSettings = !_showSettings;
              _showAudioList = false;
            }),
            active: _showSettings,
          ),
        ],
      ),
    );
  }

  Widget _topBtn(IconData icon, VoidCallback onTap, {bool active = false}) {
    final btnSize = isIPad(context) ? 52.0 : 44.0;
    final iconSize = isIPad(context) ? 28.0 : 24.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(btnSize / 2),
        child: SizedBox(
          width: btnSize,
          height: btnSize,
          child: Center(
            child: Icon(
              icon,
              color: active ? AppColors.primary : AppColors.onSurface,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Bottom Area ─────────────────────────────────

  Widget _buildBottomArea(
    PlayerEngineState s,
    PlayerEngineNotifier n,
    bool hasSubtitles,
    String followLabel,
    Subtitles? currentSub,
  ) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, AppColors.background.withValues(alpha: 0.87)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Follow control bar (inline, above progress)
          if (!_showFollow && s.followModeActive && !_drawerOpen)
            _buildFollowBar(s, n, currentSub, followLabel),
          // Progress bar
          _buildProgressBar(s, n),
          // Control row
          _buildControlRow(s, n, hasSubtitles, followLabel, currentSub),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildProgressBar(PlayerEngineState s, PlayerEngineNotifier n) {
    final p = s.duration.inMilliseconds > 0
        ? s.position.inMilliseconds / s.duration.inMilliseconds
        : 0.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 20)),
      child: Row(
        children: [
          Text(
            _fmtDuration(s.position),
            style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.54), fontSize: Adaptive.sp(context, 13)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: isIPad(context) ? 5 : 3,
                activeTrackColor: AppColors.secondary,
                inactiveTrackColor: AppColors.onSurface.withValues(alpha: 0.12),
                thumbColor: AppColors.primary,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: isIPad(context) ? 8 : 6),
                overlayShape: RoundSliderOverlayShape(overlayRadius: isIPad(context) ? 16 : 12),
              ),
              child: Slider(
                value: p.clamp(0.0, 1.0),
                onChanged: (v) =>
                    n.seekToMs((v * s.duration.inMilliseconds).round()),
              ),
            ),
          ),
          Text(
            _fmtDuration(s.duration),
            style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.54), fontSize: Adaptive.sp(context, 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildControlRow(
    PlayerEngineState s,
    PlayerEngineNotifier n,
    bool hasSubtitles,
    String followLabel,
    Subtitles? currentSub,
  ) {
    final video = n.currentVideo;
    final language = video?.language ?? 'en';
    final evalSupported = _supportedEvalLanguages.contains(language);
    // iPad 上使用更大的按钮尺寸（参考首页图标容器36-56px标准）
    final ctrlSize = isIPad(context) ? 58.0 : 46.0;
    final playIconSize = isIPad(context) ? 42.0 : 34.0;
    final skipIconSize = isIPad(context) ? 38.0 : 30.0;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Adaptive.h(context, 4)),
      child: Row(
        children: [
          // Left: main playback controls
          if (hasSubtitles)
            _ctrlBtn(
              AppIcons.skipPrevious,
              () => n.previousSentence(),
              size: skipIconSize,
              btnSize: ctrlSize,
            ),
          _ctrlBtn(
            s.playerState == PlayerState.playing
                ? AppIcons.pause
                : AppIcons.play,
            () => n.togglePlayPause(),
            size: playIconSize,
            btnSize: isIPad(context) ? 68.0 : 56.0,
          ),
          if (hasSubtitles)
            _ctrlBtn(AppIcons.skipNext, () => n.nextSentence(), size: skipIconSize, btnSize: ctrlSize),
          const Spacer(),
          // Right: feature buttons
          if (hasSubtitles)
            _miniBtn(
              '单句',
              s.singleSentencePause,
              () => n.toggleSingleSentencePause(),
            ),
          if (hasSubtitles) SizedBox(width: Adaptive.w(context, 6)),
          PopupMenuButton<double>(
            initialValue: s.speed,
            onSelected: (sp) {
              n.setSpeed(sp);
            },
            offset: const Offset(0, -220),
            color: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: _miniBtn(
              '${s.speed.toStringAsFixed(1)}X',
              s.speed != 1.0,
              null, // PopupMenuButton intercepts the tap
            ),
            itemBuilder: (context) {
              return _speedOptions.map((sp) {
                final active = s.speed == sp;
                return PopupMenuItem<double>(
                  value: sp,
                  height: isIPad(context) ? 44 : 36,
                  child: Center(
                    child: Text(
                      '${sp}X',
                      style: TextStyle(
                        color: active ? AppColors.primary : AppColors.onSurface,
                        fontSize: Adaptive.sp(context, 14),
                        fontWeight: active
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList();
            },
          ),
          if (hasSubtitles && evalSupported) ...[
            SizedBox(width: Adaptive.w(context, 6)),
            _miniBtn(followLabel, _showFollow, () {
              if (_showFollow) {
                setState(() => _showFollow = false);
                n.exitFollowMode();
              } else {
                setState(() => _showFollow = true);
                n.enterFollowMode();
                n.setSingleSentencePause(true);
                if (currentSub != null) {
                  n.seekToMs(
                    Duration(
                      milliseconds: currentSub.startPosition.toInt(),
                    ).inMilliseconds,
                  );
                  Future.microtask(() => n.player.play());
                }
              }
            }),
          ],
          // 清晰朗读按钮
          if (hasSubtitles) ...[
            SizedBox(width: Adaptive.w(context, 6)),
            _miniBtn(
              '朗读',
              _isTtsSpeaking,
              _isTtsSpeaking
                  ? () => _stopClaritySpeak()
                  : (currentSub != null
                        ? () => _handleClaritySpeak(n, s, currentSub)
                        : null),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ctrlBtn(IconData icon, VoidCallback onTap, {double size = 24, double btnSize = 44}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(btnSize / 2),
        child: SizedBox(
          width: btnSize,
          height: btnSize,
          child: Center(
            child: Icon(icon, color: AppColors.onSurface, size: size),
          ),
        ),
      ),
    );
  }

  Widget _miniBtn(String label, bool active, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 12), vertical: Adaptive.h(context, 6)),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppColors.onSurface : AppColors.onSurface.withValues(alpha: 0.7),
              fontSize: Adaptive.sp(context, 14),
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Follow Control Bar ──────────────────────────

  Widget _buildFollowBar(
    PlayerEngineState s,
    PlayerEngineNotifier n,
    Subtitles? currentSub,
    String followLabel,
  ) {
    final pad = isIPad(context) ? 20.0 : 16.0;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: pad, vertical: Adaptive.h(context, 4)),
      padding: EdgeInsets.all(isIPad(context) ? 16.0 : 12.0),
      decoration: BoxDecoration(
        color: AppColors.onSurface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                s.isRecording ? AppIcons.micRounded : AppIcons.micNone,
                color: s.isRecording ? Colors.redAccent : AppColors.primary,
                size: Adaptive.sp(context, 18),
              ),
              SizedBox(width: Adaptive.w(context, 8)),
              Text(
                s.isRecording ? '录音中' : '准备$followLabel',
                style: TextStyle(color: AppColors.onSurface, fontSize: Adaptive.sp(context, 14)),
              ),
              const Spacer(),
              Text(
                '原音:',
                style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.54), fontSize: Adaptive.sp(context, 13)),
              ),
              SizedBox(
                width: Adaptive.w(context, 100),
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: isIPad(context) ? 3 : 2,
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.onSurface.withValues(alpha: 0.12),
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: isIPad(context) ? 5 : 4,
                    ),
                    thumbColor: AppColors.primary,
                  ),
                  child: Slider(
                    value: s.originalVolume,
                    onChanged: (v) => n.setOriginalVolume(v),
                  ),
                ),
              ),
              Text(
                '${(s.originalVolume * 100).round()}%',
                style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.54), fontSize: Adaptive.sp(context, 13)),
              ),
            ],
          ),
          SizedBox(height: Adaptive.h(context, 8)),
          if (_hasHeadphone == false)
            Padding(
              padding: EdgeInsets.only(bottom: Adaptive.h(context, 6)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    AppIcons.headphones,
                    size: Adaptive.sp(context, 16),
                    color: AppColors.warning,
                  ),
                  SizedBox(width: Adaptive.w(context, 4)),
                  Text(
                    '建议佩戴耳机',
                    style: TextStyle(color: AppColors.warning, fontSize: Adaptive.sp(context, 13)),
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: s.isRecording
                      ? null
                      : () => _startFollowRecording(s, n, currentSub),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Adaptive.w(context, 24),
                      vertical: Adaptive.h(context, 10),
                    ),
                    decoration: BoxDecoration(
                      color: s.isRecording ? AppColors.onSurface.withValues(alpha: 0.24) : AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s.isRecording ? '录音中...' : '开始$followLabel',
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: Adaptive.sp(context, 14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              if (s.isRecording) ...[
                SizedBox(width: Adaptive.w(context, 12)),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _stopFollowRecording(s, n, currentSub),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Adaptive.w(context, 24),
                        vertical: Adaptive.h(context, 10),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '停止',
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: Adaptive.sp(context, 14),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ─── Settings Drawer ─────────────────────────────

  /// 跟唱/跟读组件（内联渲染，替代旧的 _buildFollowBar）
  Widget _buildFollowPanel(
    PlayerEngineState s,
    PlayerEngineNotifier n,
    Subtitles currentSub,
  ) {
    final video = n.currentVideo;
    final lang = video?.language ?? 'en';
    final isMusic = widget.audioType == 'music';

    Future<void> playAtSubtitleIndex(int index) async {
      if (index < 0 || index >= n.subtitles.length) return;
      final sub = n.subtitles[index];
      await n.seekToMs(
        Duration(milliseconds: sub.startPosition.toInt()).inMilliseconds,
      );
      await n.player.play();
    }

    return ShadowReaderComponent.inline(
      config: ShadowReaderConfig(
        subtitle: currentSub,
        resourceType: widget.audioType,
        resourceCode: widget.videoCode,
        resourceTitle: s.title,
        language: lang,
        isMusic: isMusic,
        scope: 'sentence',
        getPosition: () => s.position,
        seekTo: (d) async => n.seekToMs(d.inMilliseconds),
        togglePlayPause: () async => n.togglePlayPause(),
        pause: () async => n.player.pause(),
        play: () async => n.player.play(),
        setOriginalVolume: (v) async => n.setOriginalVolume(v),
        setSpeed: (v) async => n.setSpeed(v),
        currentSpeed: s.speed,
        getSingleSentencePause: s.singleSentencePause,
        setSingleSentencePause: (v) async => n.setSingleSentencePause(v),
        setRecording: (v) async => n.setRecording(v),
        setLastFollowScore: (v) async => n.setLastFollowScore(v),
        getCurrentVideo: () => video,
        isTtsSpeaking: null,
        currentSubtitleIndex: s.currentSubtitleIndex,
        nextSentence: () async => n.nextSentence(),
        previousSentence: () async => n.previousSentence(),
        playAtSubtitleIndex: playAtSubtitleIndex,
      ),
      heightFactor: 0.45,
      onClose: () {
        setState(() => _showFollow = false);
        n.exitFollowMode();
      },
    );
  }

  Widget _buildSettingsContent(PlayerEngineState s, PlayerEngineNotifier n) {
    final loopModes = [
      ('single_loop', '单集循环', AppIcons.repeatOne),
      ('list_loop', '列表循环', AppIcons.repeat),
      ('single_play', '单集播放', AppIcons.playCircleOutline),
      ('sequence_play', '顺序播放', AppIcons.playlistPlay),
    ];
    // 侧边栏通用间距
    final hp = Adaptive.w(context, 16);
    final vp = Adaptive.h(context, 12);
    final ip = Adaptive.w(context, 12); // 内部间距
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: hp, vertical: vp),
          child: Row(
            children: [
              Text(
                '设置',
                style: TextStyle(
                  color: _drawerText(),
                  fontSize: Adaptive.sp(context, 17),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showSettings = false),
                child: Icon(
                  AppIcons.close,
                  color: _drawerTextVariant(),
                  size: Adaptive.icon(context, 24),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: ip, vertical: Adaptive.h(context, 4)),
            children: [
              _settingSwitch('字幕显示', s.subtitleVisible, () => n.toggleSubtitleVisible()),
              SizedBox(height: Adaptive.h(context, 4)),
              _settingSwitch('中文注音', s.pronunciationVisible, () => n.togglePronunciationVisible()),
              SizedBox(height: Adaptive.h(context, 4)),
              _settingSwitch('中文翻译', s.translateVisible, () => n.toggleTranslateVisible()),
              SizedBox(height: Adaptive.h(context, 14)),
              _settingLabel('字幕字号'),
              SizedBox(height: Adaptive.h(context, 4)),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: isIPad(context) ? 4 : 3,
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.onSurface.withValues(alpha: 0.12),
                  thumbColor: AppColors.primary,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: isIPad(context) ? 7 : 6),
                ),
                child: Slider(
                  value: s.subtitleFontSize,
                  min: 14,
                  max: 36,
                  divisions: 11,
                  label: '${s.subtitleFontSize.round()}',
                  onChanged: (v) => n.setSubtitleFontSize(v.roundToDouble()),
                ),
              ),
              SizedBox(height: Adaptive.h(context, 8)),
              _settingLabel('循环模式'),
              SizedBox(height: Adaptive.h(context, 6)),
              Wrap(
                spacing: Adaptive.w(context, 8),
                runSpacing: Adaptive.h(context, 8),
                children: loopModes.map((entry) {
                  final mode = entry.$1;
                  final label = entry.$2;
                  final icon = entry.$3;
                  final active = s.loopingMode == mode;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => n.setLoopingMode(mode),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Adaptive.w(context, 12),
                          vertical: Adaptive.h(context, 6),
                        ),
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : AppColors.onSurface.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: Adaptive.sp(context, 16), color: active ? AppColors.onSurface : AppColors.onSurface.withValues(alpha: 0.54)),
                            SizedBox(width: Adaptive.w(context, 5)),
                            Text(label, style: TextStyle(color: active ? AppColors.onSurface : AppColors.onSurface.withValues(alpha: 0.7), fontSize: Adaptive.sp(context, isIPad(context) ? 15 : 13))),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: Adaptive.h(context, 14)),
              _settingLabel('智能匹配字幕'),
              SizedBox(height: Adaptive.h(context, 4)),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () { setState(() => _showSettings = false); _startSmartMatch(); },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 12), vertical: Adaptive.h(context, 8)),
                    decoration: BoxDecoration(color: AppColors.onSurface.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(AppIcons.autoAwesome, size: Adaptive.sp(context, 16), color: AppColors.primary),
                      SizedBox(width: Adaptive.w(context, 8)),
                      Text('开始智能匹配', style: TextStyle(color: _drawerTextVariant(), fontSize: Adaptive.sp(context, isIPad(context) ? 16 : 14))),
                    ]),
                  ),
                ),
              ),
              SizedBox(height: Adaptive.h(context, 8)),
              _settingLabel('手动导入字幕'),
              SizedBox(height: Adaptive.h(context, 4)),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () { setState(() => _showSettings = false); _importSubtitle(); },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 12), vertical: Adaptive.h(context, 8)),
                    decoration: BoxDecoration(color: AppColors.onSurface.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(AppIcons.upload, size: Adaptive.sp(context, 16), color: AppColors.primary),
                      SizedBox(width: Adaptive.w(context, 8)),
                      Text('选择字幕文件', style: TextStyle(color: _drawerTextVariant(), fontSize: Adaptive.sp(context, isIPad(context) ? 16 : 14))),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingSwitch(String label, bool value, VoidCallback onChanged) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onChanged,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: Adaptive.h(context, 5), horizontal: Adaptive.w(context, 4)),
          child: Row(
            children: [
              Text(label, style: TextStyle(color: _drawerText(), fontSize: Adaptive.sp(context, 15))),
              const Spacer(),
              SizedBox(
                height: isIPad(context) ? 32.0 : 28.0,
                child: FittedBox(
                  child: Switch(
                    value: value,
                    onChanged: (_) => onChanged(),
                    activeThumbColor: AppColors.primary,
                    inactiveThumbColor: AppColors.onSurface.withValues(alpha: 0.38),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: Adaptive.h(context, 2)),
      child: Text(
        label,
        style: TextStyle(
          color: _drawerTextVariant(),
          fontSize: Adaptive.sp(context, 14),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ─── Audio List Drawer ───────────────────────────

  Widget _buildAudioListContent(PlayerEngineState s, PlayerEngineNotifier n) {
    final list = s.folderVideos.isNotEmpty
        ? s.folderVideos
        : (_folderVideosOverride ?? const <VideoInfo>[]);
    final thumbSize = isIPad(context) ? 52.0 : 44.0;
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 16), vertical: Adaptive.h(context, 16)),
          decoration: BoxDecoration(color: Colors.transparent),
          child: Row(
            children: [
              Text('音频列表', style: TextStyle(color: _drawerText(), fontSize: Adaptive.sp(context, 17), fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('共 ${list.length} 首', style: TextStyle(color: _drawerTextVariant(), fontSize: Adaptive.sp(context, 14))),
              SizedBox(width: Adaptive.w(context, 12)),
              GestureDetector(
                onTap: () => setState(() => _showAudioList = false),
                child: Padding(padding: EdgeInsets.all(Adaptive.w(context, 4)), child: Icon(AppIcons.close, color: _drawerTextVariant(), size: Adaptive.icon(context, 24))),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(AppIcons.musicOff, size: Adaptive.icon(context, 52), color: AppColors.onSurface.withValues(alpha: 0.24)),
                  SizedBox(height: Adaptive.h(context, 10)),
                  Text('暂无可播音频', style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.54), fontSize: Adaptive.sp(context, 15))),
                ]))
              : ListView.builder(
                  padding: EdgeInsets.all(Adaptive.w(context, 12)),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final v = list[i];
                    final isCurrent = v.code == s.videoCode;
                    final durationStr = v.duration > 0 ? _fmtDuration(Duration(milliseconds: v.duration)) : '--:--';
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () { if (v.code != null && v.code != s.videoCode) { setState(() => _showAudioList = false); _switchToAudio(v.code!); } },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: Adaptive.h(context, 4)),
                          padding: EdgeInsets.all(Adaptive.w(context, 12)),
                          decoration: BoxDecoration(
                            color: isCurrent ? AppColors.primary.withValues(alpha: 0.15) : AppColors.onSurface.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: isCurrent ? Border.all(color: AppColors.primary.withValues(alpha: 0.4)) : null,
                          ),
                          child: Row(children: [
                              // 封面/序号
                              Container(width: thumbSize, height: thumbSize, decoration: BoxDecoration(color: isCurrent ? AppColors.primary.withValues(alpha: 0.3) : AppColors.onSurface.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Center(child: isCurrent ? Icon(AppIcons.equalizer, color: AppColors.primary, size: Adaptive.icon(context, 24)) : Text('${i + 1}', style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.54), fontSize: Adaptive.sp(context, 15), fontWeight: FontWeight.w500)))),
                              SizedBox(width: Adaptive.w(context, 12)),
                              // 标题+信息
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(v.name, style: TextStyle(color: isCurrent ? AppColors.primary : AppColors.onSurface, fontSize: Adaptive.sp(context, 15), fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                SizedBox(height: Adaptive.h(context, 5)),
                                Row(children: [
                                  Icon(v.hasSubtitles ? AppIcons.subtitles : AppIcons.subtitlesOff, size: Adaptive.sp(context, 15), color: v.hasSubtitles ? AppColors.success.withValues(alpha: 0.7) : AppColors.onSurface.withValues(alpha: 0.24)),
                                  SizedBox(width: Adaptive.w(context, 4)),
                                  Text(v.hasSubtitles ? '有字幕' : '无字幕', style: TextStyle(color: v.hasSubtitles ? AppColors.success.withValues(alpha: 0.7) : AppColors.onSurface.withValues(alpha: 0.3), fontSize: Adaptive.sp(context, isIPad(context) ? 15 : 13))),
                                  SizedBox(width: Adaptive.w(context, 10)),
                                  Icon(AppIcons.accessTime, size: Adaptive.icon(context, isIPad(context) ? 16 : 13), color: AppColors.onSurface.withValues(alpha: 0.3)),
                                  SizedBox(width: Adaptive.w(context, 4)),
                                  Text(durationStr, style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.38), fontSize: Adaptive.sp(context, isIPad(context) ? 15 : 13))),
                                  if (v.artist != null && v.artist!.isNotEmpty) ...[
                                    SizedBox(width: Adaptive.w(context, 10)),
                                    Expanded(child: Text(v.artist!, style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.3), fontSize: Adaptive.sp(context, isIPad(context) ? 15 : 13)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  ],
                                ]),
                              ])),
                              // 分数角标
                              if (v.lastFollowScore != null)
                                Container(padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 6), vertical: Adaptive.h(context, 2)), decoration: BoxDecoration(color: _scoreColor(v.lastFollowScore!).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    '${v.lastFollowScore!.round()}',
                                    style: TextStyle(
                                      color: _scoreColor(v.lastFollowScore!),
                                      fontSize: Adaptive.sp(context, isIPad(context) ? 14 : 12),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _switchToAudio(String code) async {
    final notifier = ref.read(playerEngineProvider.notifier);
    await notifier.switchToAudio(code, widget.audioType);
    _resolveCover();
    if (mounted) setState(() {});
  }

  // ─── Follow Recording Logic ──────────────────────

  Future<void> _startFollowRecording(
    PlayerEngineState s,
    PlayerEngineNotifier n,
    Subtitles? currentSub,
  ) async {
    if (currentSub == null) return;
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('需要麦克风权限才能跟读')));
      }
      return;
    }

    n.setRecording(true);
    _recordingStartTime = DateTime.now();

    try {
      final tmpDir = Directory.systemTemp;
      final path =
          '${tmpDir.path}/follow_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
        _autoStopTimer = Timer(
          Duration(milliseconds: remainingMs + bufferMs),
          () {
            if (mounted && ref.read(playerEngineProvider).isRecording) {
              _stopFollowRecording(
                ref.read(playerEngineProvider),
                n,
                currentSub,
              );
            }
          },
        );
      }
    } catch (_) {
      n.setRecording(false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('录音启动失败')));
      }
    }
  }

  Future<void> _stopFollowRecording(
    PlayerEngineState s,
    PlayerEngineNotifier n,
    Subtitles? currentSub,
  ) async {
    _autoStopTimer?.cancel();
    if (_recordingPath == null) return;

    try {
      await _recorder.stop();
    } catch (_) {}
    n.setRecording(false);

    // Restore volume to 100%
    await n.setOriginalVolume(1.0);

    final path = _recordingPath;
    _recordingPath = null;
    if (path == null || !File(path).existsSync()) return;
    if (currentSub == null) return;

    _evaluateRecording(path, s, n, currentSub);
  }

  Future<void> _evaluateRecording(
    String audioPath,
    PlayerEngineState s,
    PlayerEngineNotifier n,
    Subtitles sub,
  ) async {
    if (_isEvaluating) return;
    _isEvaluating = true;

    try {
      final video = n.currentVideo;
      final language = video?.language ?? 'en';
      final coreType = 'sent.eval';
      final userCode = video?.userCode ?? 'anonymous';

      // 声通 key 从 AppKeysService 获取
      final stAppKey = AppKeysService.instance.shengtongAppKey;
      final stSecretKey = AppKeysService.instance.shengtongSecretKey;
      if (stAppKey == null ||
          stAppKey.isEmpty ||
          stSecretKey == null ||
          stSecretKey.isEmpty) {
        debugPrint('⚠️ [AudioPlayer] 声通密钥未就绪，跳过评测');
        return;
      }
      // 使用 ShengtongHttpEvaluator HTTP 方式评测
      final evaluator = ShengtongHttpEvaluator(
        appKey: stAppKey,
        secretKey: stSecretKey,
        baseUrl: AppKeysService.shengtongBaseUrl,
      );

      final result = await evaluator.evaluate(
        coreType: coreType,
        refText: sub.content,
        audioPath: audioPath,
        userId: userCode,
      );

      if (result.isEmpty) {
        debugPrint('AudioPlayer 声通评分返回空结果，可能超时或服务不可用，coreType=$coreType');
      }

      if (result.isNotEmpty && mounted) {
        final overall = (result['overall'] as num?)?.toDouble();
        final fluency = (result['fluency'] as num?)?.toDouble();
        final accuracy = (result['accuracy'] as num?)?.toDouble();
        final completeness = (result['completeness'] as num?)?.toDouble();

        // Calculate actual recording duration
        final recordingDurationMs = _recordingStartTime != null
            ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
            : 0;

        final record = RecordingRecord(
          resourceCode: widget.videoCode,
          resourceType: widget.audioType,
          scope: 'sentence',
          sentenceCode: sub.code,
          audioPath: audioPath,
          durationMs: recordingDurationMs,
          overallScore: overall,
          fluencyScore: fluency,
          accuracyScore: accuracy,
          completenessScore: completeness,
          rawResultJson: result.toString(),
          language: language,
          refText: sub.content,
          subtitleIndex: s.currentSubtitleIndex,
          originalVolume: s.originalVolume,
          speed: s.speed,
          headphoneMode: await _detectHeadphoneMode(),
        );
        await DatabaseService.insert(record);

        if (overall != null) {
          n.setLastFollowScore(overall);
          if (video != null) {
            video.lastFollowScore = overall;
            await DatabaseService.update(video);
          }
        }

        _showScoreResult(overall, fluency, accuracy, completeness);
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('评分服务暂时不可用')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('评分失败，请检查声通配置')));
      }
    } finally {
      _isEvaluating = false;
    }
  }

  void _showScoreResult(
    double? overall,
    double? fluency,
    double? accuracy,
    double? completeness,
  ) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '跟读评分',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: Adaptive.sp(context, 16),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (overall != null)
              Text(
                '${overall.round()}',
                style: TextStyle(
                  color: _scoreColor(overall),
                  fontSize: Adaptive.sp(context, 48),
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (accuracy != null) _scoreDim('准确', accuracy),
                if (fluency != null) _scoreDim('流利', fluency),
                if (completeness != null) _scoreDim('完整', completeness),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('重录', style: TextStyle(color: AppColors.primary)),
                ),
                const SizedBox(width: 20),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(playerEngineProvider.notifier).nextSentence();
                  },
                  child: Text(
                    '下一句',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreDim(String label, double score) {
    return Column(
      children: [
        Text(
          '${score.round()}',
          style: TextStyle(
            color: _scoreColor(score),
            fontSize: Adaptive.sp(context, 20),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.54), fontSize: Adaptive.sp(context, 12)),
        ),
      ],
    );
  }

  Color _scoreColor(double score) {
    if (score >= 90) return AppColors.success;
    if (score >= 75) return AppColors.warning;
    if (score >= 60) return AppColors.error;
    return AppColors.error;
  }

  // ─── Helpers ─────────────────────────────────────

  Future<bool> _handleSaveWord({
    required String word,
    String? contextSentence,
    required String sourceType,
    required String sourceCode,
    String? sourceTitle,
  }) async {
    final notifier = ref.read(playerEngineProvider.notifier);
    final state = ref.read(playerEngineProvider);
    final video = notifier.currentVideo;
    final idx = state.currentSubtitleIndex;
    final subs = notifier.subtitles;
    final currentSub = (idx != null && idx >= 0 && idx < subs.length)
        ? subs[idx]
        : null;

    final result = await WordBookService.saveWord(
      word: word,
      sourceType: sourceType,
      sourceCode: sourceCode,
      sourceTitle: sourceTitle,
      contextSentence: contextSentence,
      segmentCode: currentSub?.code,
      videoPath: video?.filePath,
      positionMs: state.position.inMilliseconds,
    );
    return result != null;
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours,
        m = d.inMinutes.remainder(60),
        s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<bool?> _detectHeadphoneMode() async {
    try {
      final devices = await _recorder.listInputDevices();
      return devices.any(
        (d) =>
            d.id.toLowerCase().contains('headset') ||
            d.id.toLowerCase().contains('headphone') ||
            d.id.toLowerCase().contains('bluetooth') ||
            d.label.toLowerCase().contains('headset') ||
            d.label.toLowerCase().contains('headphone') ||
            d.label.toLowerCase().contains('bluetooth') ||
            d.label.toLowerCase().contains('airpods'),
      );
    } catch (_) {
      return null;
    }
  }
}
