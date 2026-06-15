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
import 'package:vidlang/views/audio_player/lyric_display_widget.dart';
import 'package:vidlang/views/audio_player/recognition_prompt_dialog.dart';
import 'package:vidlang/widgets/selectable_english_line.dart';
import 'package:vidlang/widgets/word_card.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/views/audio_player/ai_evaluation_sheet.dart';
import 'package:vidlang/views/audio_player/learning_record_page.dart';

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
  bool _showSpeedPicker = false;
  bool? _hasHeadphone;
  List<VideoInfo>? _folderVideosOverride;
  String? _resolvedCoverPath;

  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;
  bool _isEvaluating = false;
  ShengtongEvaluator? _evaluator;
  Timer? _autoStopTimer;

  final ap.AudioPlayer _aliAudioPlayer = ap.AudioPlayer();
  bool _isTtsSpeaking = false;

  static const _supportedEvalLanguages = {'en', 'fr', 'ja', 'ko'};

  List<double> get _speedOptions {
    final isMusic = widget.audioType == 'music';
    return isMusic
        ? [0.5, 0.75, 1.0, 1.25, 1.5]
        : [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  }

  double _playbackSpeed = 1.0;

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

  Future<void> _checkHeadphone() async {
    final has = await _detectHeadphoneMode();
    if (mounted) setState(() => _hasHeadphone = has);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoStopTimer?.cancel();
    _aliAudioPlayer.dispose();
    _evaluator?.dispose();
    _recorder.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

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

  Future<void> _resolveCover() async {
    final state = ref.read(playerEngineProvider);
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

  void _showNoSubtitlePrompt() {
    final state = ref.read(playerEngineProvider);
    final video = ref.read(playerEngineProvider.notifier).currentVideo;
    showDialog(
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
        onAppreciate: () {
          Navigator.pop(ctx);
        },
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
        ref.read(playerEngineProvider.notifier).openAudioByCode(widget.videoCode, widget.audioType);
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _buildRecognitionProgressDialog(),
    );

    try {
      if (widget.audioType == 'music') {
        final title = video.name;
        final artist = video.artist;
        final result = await AudioRecognitionService.searchLyrics(
          videoCode: widget.videoCode,
          title: title,
          artist: artist,
        );
        if (!mounted) return;
        Navigator.pop(context);

        if (result.ok) {
          await AudioRecognitionService.saveLyricsResultToDb(
            videoCode: widget.videoCode,
            result: result,
          );
          await ref.read(playerEngineProvider.notifier).reloadSubtitles(widget.videoCode);
          if (mounted) setState(() {});
          unawaited(ConversationService.uploadSubtitlesToCloud(widget.videoCode));
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
          await ref.read(playerEngineProvider.notifier).reloadSubtitles(widget.videoCode);
          if (mounted) setState(() {});
          unawaited(ConversationService.uploadSubtitlesToCloud(widget.videoCode));
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('未能识别此音频内容，已转入欣赏模式')),
    );
  }

  Future<Map<String, String>?> _showSongInfoInputDialog(String currentName) async {
    final titleCtrl = TextEditingController(text: currentName);
    final artistCtrl = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lyrics_outlined, color: AppColors.primary, size: 28),
              const SizedBox(height: 12),
              Text('请输入歌曲信息', style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('以便搜索歌词', style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
                decoration: InputDecoration(
                  labelText: '歌曲名',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: artistCtrl,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
                decoration: InputDecoration(
                  labelText: '演唱者',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('跳过,先欣赏', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, {
                      'title': titleCtrl.text.trim(),
                      'artist': artistCtrl.text.trim(),
                    }),
                    child: Text('搜索歌词', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecognitionProgressDialog() {
    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  widget.audioType == 'music' ? '正在搜索歌词...' : '正在识别音频...',
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                ),
                const SizedBox(height: 8),
                Text(
                  '识别期间您可以继续收听',
                  style: TextStyle(color: Colors.white54, fontSize: 12.sp),
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
        parsed = LrcParser.parseContent(await file.readAsString(), widget.videoCode);
      } else {
        final stats = await FilePickerService.importSubtitleToDb(
          filePath,
          ref.read(playerEngineProvider.notifier).currentVideo?.folderCode ?? '',
          widget.videoCode,
        );
        if (mounted) {
          await ref.read(playerEngineProvider.notifier).reloadSubtitles(widget.videoCode);
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('导入成功，共${stats.subtitlesInserted}条字幕')),
          );
        }
        return;
      }

      if (parsed.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未能解析出有效字幕')),
          );
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
        await ref.read(playerEngineProvider.notifier).reloadSubtitles(widget.videoCode);
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入成功，共${parsed.length}条歌词')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('字幕导入失败')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerEngineProvider);
    final notifier = ref.read(playerEngineProvider.notifier);
    final subtitlesList = notifier.subtitles;
    final hasSubtitles = subtitlesList.isNotEmpty;
    final idx = state.currentSubtitleIndex;
    final currentSub = (hasSubtitles && idx != null && idx >= 0 && idx < subtitlesList.length)
        ? subtitlesList[idx]
        : null;
    final isMusic = state.audioType == 'music';
    final followLabel = isMusic ? '跟唱' : '跟读';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(state, notifier),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildVisualArea(state, isMusic),
                    const SizedBox(height: 16),
                    if (hasSubtitles && currentSub != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: LyricDisplayWidget(
                          subtitle: currentSub,
                          subtitleVisible: state.subtitleVisible,
                          translateVisible: state.translateVisible,
                          pronunciationVisible: state.pronunciationVisible,
                          fontSize: state.subtitleFontSize,
                          onSelectionChanged: (words) {
                            if (words.isNotEmpty) {
                              notifier.player.pause();
                              final selectedText = words.join(' ');
                              final canSave = WordBookService.isSingleWord(selectedText);
                              WordCard.show(
                                context,
                                word: selectedText,
                                contextSentence: currentSub.content,
                                isPaidMode: false,
                                onSpeak: () => _speakWord(selectedText),
                                onSaveWord: canSave ? _handleSaveWord : null,
                                sourceType: 'music',
                                sourceCode: widget.videoCode,
                                sourceTitle: state.title,
                                segmentCode: currentSub.code,
                              );
                            }
                          },
                        ),
                      )
                    else if (!hasSubtitles)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.music_note, size: 48, color: Colors.white24),
                            const SizedBox(height: 8),
                            Text(
                              '暂无字幕，可在菜单中添加',
                              style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _buildProgressBar(state, notifier),
            _buildMainControls(state, notifier, hasSubtitles, followLabel),
            _buildFeatureRow(state, notifier, hasSubtitles, followLabel),
            if (state.followModeActive)
              _buildFollowControlBar(state, notifier, currentSub, followLabel),
            if (_showSpeedPicker)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSpeedPicker(notifier),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(PlayerEngineState s, PlayerEngineNotifier n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (n.currentVideo?.artist != null)
                  Text(
                    n.currentVideo!.artist!,
                    style: TextStyle(color: Colors.white54, fontSize: 10.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (s.lastFollowScore != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _scoreColor(s.lastFollowScore!).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '🎤${s.lastFollowScore!.round()}',
                style: TextStyle(
                  color: _scoreColor(s.lastFollowScore!),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
            color: AppColors.surfaceElevated,
            onSelected: (value) {
               switch (value) {
                 case 'learning_record':
                   final video = ref.read(playerEngineProvider.notifier).currentVideo;
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (_) => LearningRecordPage(
                         videoCode: widget.videoCode,
                         videoTitle: video?.name ?? '',
                       ),
                     ),
                   );
                   break;
                 case 'ai_evaluation':
                   final video = ref.read(playerEngineProvider.notifier).currentVideo;
                   AiEvaluationSheet.show(
                     context,
                     videoCode: widget.videoCode,
                     videoTitle: video?.name ?? '',
                     language: video?.language ?? 'en',
                   );
                   break;
                 case 'smart_match':
                  _startSmartMatch();
                  break;
                case 'import_subtitle':
                  _importSubtitle();
                  break;
              }
            },
            itemBuilder: (ctx) => [
               const PopupMenuItem(value: 'learning_record', child: Text('学习记录')),
               const PopupMenuItem(value: 'ai_evaluation', child: Text('AI点评')),
               if (!s.hasSubtitles) ...[
                const PopupMenuItem(value: 'smart_match', child: Text('智能匹配字幕')),
                const PopupMenuItem(value: 'import_subtitle', child: Text('手动导入字幕')),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisualArea(PlayerEngineState s, bool isMusic) {
    final coverPath = _resolvedCoverPath;
    return Container(
      height: 220.h,
      width: 220.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surfaceElevated,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: (coverPath != null && File(coverPath).existsSync())
            ? Image.file(File(coverPath), fit: BoxFit.cover, errorBuilder: (_, _, _) => _buildCoverPlaceholder(isMusic))
            : _buildCoverPlaceholder(isMusic),
      ),
    );
  }

  Widget _buildCoverPlaceholder(bool isMusic) {
    final video = ref.read(playerEngineProvider.notifier).currentVideo;
    final letter = (video?.name.isNotEmpty ?? false) ? video!.name.substring(0, 1).toUpperCase() : '♪';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary.withValues(alpha: 0.6), AppColors.secondary.withValues(alpha: 0.3)],
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: Colors.white,
            fontSize: 64.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(PlayerEngineState s, PlayerEngineNotifier n) {
    final p = s.duration.inMilliseconds > 0 ? s.position.inMilliseconds / s.duration.inMilliseconds : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(_fmtDuration(s.position), style: TextStyle(color: Colors.white54, fontSize: 10.sp)),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: AppColors.secondary,
                inactiveTrackColor: Colors.white10,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                thumbColor: AppColors.primary,
              ),
              child: Slider(value: p.clamp(0.0, 1.0), onChanged: (v) => n.seekToMs((v * s.duration.inMilliseconds).round())),
            ),
          ),
          Text(_fmtDuration(s.duration), style: TextStyle(color: Colors.white54, fontSize: 10.sp)),
        ],
      ),
    );
  }

  Widget _buildMainControls(PlayerEngineState s, PlayerEngineNotifier n, bool hasSubtitles, String followLabel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hasSubtitles)
            IconButton(
              icon: Icon(Icons.skip_previous_rounded, color: Colors.white, size: 28),
              onPressed: () => n.previousSentence(),
            ),
          const SizedBox(width: 16),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.sunsetGradient),
            child: IconButton(
              icon: Icon(
                s.playerState == PlayerState.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
              onPressed: () => n.togglePlayPause(),
            ),
          ),
          const SizedBox(width: 16),
          if (hasSubtitles)
            IconButton(
              icon: Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
              onPressed: () => n.nextSentence(),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(PlayerEngineState s, PlayerEngineNotifier n, bool hasSubtitles, String followLabel) {
    final video = n.currentVideo;
    final language = video?.language ?? 'en';
    final evalSupported = _supportedEvalLanguages.contains(language);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          if (hasSubtitles && evalSupported)
            _featureBtn(followLabel, s.followModeActive, () {
              if (s.followModeActive) {
                n.exitFollowMode();
              } else {
                n.enterFollowMode();
              }
            }),
          if (hasSubtitles)
            _featureBtn('单句', s.singleSentencePause, () => n.toggleSingleSentencePause()),
          if (hasSubtitles)
            _featureBtn('注音', s.pronunciationVisible, () => n.togglePronunciationVisible()),
          if (hasSubtitles)
            _featureBtn('字幕', s.subtitleVisible, () => n.toggleSubtitleVisible()),
          if (hasSubtitles)
            _featureBtn('翻译', s.translateVisible, () => n.toggleTranslateVisible()),
          if (hasSubtitles)
            _featureBtn('由慢到快', s.slowToFastActive, () => n.toggleSlowToFastCurrentSentence()),
          _featureBtn(
            s.abLoopStart != null && s.abLoopEnd != null ? 'A-B' : s.abLoopStart != null ? 'A-' : 'A-B',
            s.abLoopStart != null,
            () {
              if (s.abLoopStart != null && s.abLoopEnd != null) {
                n.clearABLoop();
              } else if (s.abLoopStart == null) {
                n.setABLoopStart();
              } else {
                n.setABLoopEnd();
              }
              setState(() {});
            },
          ),
          _featureBtn(
            '${s.speed.toStringAsFixed(1)}X',
            s.speed != 1.0,
            () => setState(() => _showSpeedPicker = !_showSpeedPicker),
          ),
        ],
      ),
    );
  }

  Widget _featureBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: active ? Border.all(color: AppColors.primary.withValues(alpha: 0.5)) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.primary : Colors.white70,
            fontSize: 12.sp,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFollowControlBar(PlayerEngineState s, PlayerEngineNotifier n, Subtitles? currentSub, String followLabel) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(s.isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: s.isRecording ? Colors.red : AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.isRecording ? '录音中' : '准备${followLabel}',
                      style: TextStyle(color: Colors.white, fontSize: 12.sp),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('原音:', style: TextStyle(color: Colors.white54, fontSize: 10.sp)),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: Colors.white12,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                              thumbColor: AppColors.primary,
                            ),
                            child: Slider(
                              value: s.originalVolume,
                              onChanged: (v) => n.setOriginalVolume(v),
                            ),
                          ),
                        ),
                        Text('${(s.originalVolume * 100).round()}%',
                          style: TextStyle(color: Colors.white54, fontSize: 10.sp)),
                      ],
                    ),
                    Row(
                      children: [
                        _volumePresetBtn('100%', 1.0, n),
                        const SizedBox(width: 4),
                        _volumePresetBtn('50%', 0.5, n),
                        const SizedBox(width: 4),
                        _volumePresetBtn('0%', 0.0, n),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_hasHeadphone == false)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.headphones_outlined, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text('建议佩戴耳机跟读，录音效果更佳', style: TextStyle(color: Colors.orange, fontSize: 10.sp)),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: s.isRecording ? null : () => _startFollowRecording(s, n, currentSub),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: s.isRecording ? Colors.grey : AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    s.isRecording ? '录音中...' : '开始${followLabel}',
                    style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (s.isRecording) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _stopFollowRecording(s, n, currentSub),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('停止', style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _volumePresetBtn(String label, double volume, PlayerEngineNotifier n) {
    return GestureDetector(
      onTap: () => n.setOriginalVolume(volume),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: TextStyle(color: Colors.white70, fontSize: 9.sp)),
      ),
    );
  }

  Future<void> _startFollowRecording(PlayerEngineState s, PlayerEngineNotifier n, Subtitles? currentSub) async {
    if (currentSub == null) return;
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要麦克风权限才能跟读')),
        );
      }
      return;
    }

    n.setRecording(true);

    try {
      final tmpDir = Directory.systemTemp;
      final path = '${tmpDir.path}/follow_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      _recordingPath = path;

      if (!s.singleSentencePause) {
        n.setSingleSentencePause(true);
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('录音启动失败')),
        );
      }
    }
  }

  Future<void> _stopFollowRecording(PlayerEngineState s, PlayerEngineNotifier n, Subtitles? currentSub) async {
    _autoStopTimer?.cancel();
    if (_recordingPath == null) return;

    try {
      await _recorder.stop();
    } catch (_) {}

    n.setRecording(false);

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
      final coreType = '${language}.sent.eval';
      final userCode = video?.userCode ?? 'anonymous';

      _evaluator?.dispose();
      _evaluator = ShengtongEvaluator(
        appKey: AppConfig.shengtongAppKey,
        secretKey: AppConfig.shengtongSecretKey,
      );

      final completer = Completer<Map<String, dynamic>?>();

      _evaluator!.onResult = (result) {
        if (!completer.isCompleted) completer.complete(result);
      };
      _evaluator!.onError = (error) {
        if (!completer.isCompleted) completer.complete(null);
      };

      await _evaluator!.connect(coreType);
      _evaluator!.start(
        coreType: coreType,
        refText: sub.content,
        userId: userCode,
      );

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

        final record = RecordingRecord(
          resourceCode: widget.videoCode,
          resourceType: 'music',
          scope: 'sentence',
          sentenceCode: sub.code,
          audioPath: audioPath,
          durationMs: s.position.inMilliseconds,
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

        unawaited(ConversationService.uploadSubtitlesToCloud(widget.videoCode));

        _showScoreResult(overall, fluency, accuracy, completeness);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('评分服务暂时不可用')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('评分失败，请检查声通配置')),
        );
      }
    } finally {
      _isEvaluating = false;
    }
  }

  void _showScoreResult(double? overall, double? fluency, double? accuracy, double? completeness) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('跟读评分', style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (overall != null)
              Text(
                '${overall.round()}',
                style: TextStyle(
                  color: _scoreColor(overall),
                  fontSize: 48.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (accuracy != null) _scoreDimension('准确', accuracy),
                if (fluency != null) _scoreDimension('流利', fluency),
                if (completeness != null) _scoreDimension('完整', completeness),
              ],
            ),
            const SizedBox(height: 20),
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
                  child: Text('下一句', style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreDimension(String label, double score) {
    return Column(
      children: [
        Text('${score.round()}', style: TextStyle(color: _scoreColor(score), fontSize: 20.sp, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 10.sp)),
      ],
    );
  }

  Color _scoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.orange;
    if (score >= 60) return Colors.deepOrange;
    return Colors.red;
  }

  Future<void> _speakWord(String word) async {
    TtsService().speakWord(word);
  }

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
    final currentSub = _getCurrentSubtitle();

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

  Subtitles? _getCurrentSubtitle() {
    final notifier = ref.read(playerEngineProvider.notifier);
    final state = ref.read(playerEngineProvider);
    final subtitlesList = notifier.subtitles;
    final idx = state.currentSubtitleIndex;
    if (idx != null && idx >= 0 && idx < subtitlesList.length) {
      return subtitlesList[idx];
    }
    return null;
  }

  Widget _buildSpeedPicker(PlayerEngineNotifier n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: active ? AppColors.primary : AppColors.surfaceHighest, borderRadius: BorderRadius.circular(8)),
              child: Text(
                '${sp}X',
                style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: active ? FontWeight.bold : FontWeight.normal),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<bool?> _detectHeadphoneMode() async {
    try {
      final devices = await _recorder.listInputDevices();
      final hasHeadset = devices.any((d) =>
        d.id.toLowerCase().contains('headset') ||
        d.id.toLowerCase().contains('headphone') ||
        d.id.toLowerCase().contains('bluetooth') ||
        d.label.toLowerCase().contains('headset') ||
        d.label.toLowerCase().contains('headphone') ||
        d.label.toLowerCase().contains('bluetooth') ||
        d.label.toLowerCase().contains('airpods'));
      return hasHeadset;
    } catch (_) {
      return null;
    }
  }
}
