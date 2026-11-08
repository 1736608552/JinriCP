import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/short_drama.dart';
import '../models/drama_comment.dart';
import '../services/system_controls_service.dart';
import '../services/drama_service.dart';
import '../services/settings_service.dart';
import '../services/drama_history_service.dart';
import '../widgets/player_gesture_overlay.dart';

class DramaPlayerScreen extends StatefulWidget {
  final ShortDrama drama;
  final int initialEpisodeIndex;

  const DramaPlayerScreen({
    super.key,
    required this.drama,
    this.initialEpisodeIndex = 0,
  });

  @override
  State<DramaPlayerScreen> createState() => _DramaPlayerScreenState();
}

class _DramaPlayerScreenState extends State<DramaPlayerScreen> with WidgetsBindingObserver {
  late int _currentEpIndex;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  bool _isLiked = false;
  int _likeCount = 0;
  String _likeCountText = '';
  int _commentCount = 0;
  List<DramaComment> _comments = [];
  bool _isLoadingComments = false;
  bool _isLikingVideo = false;
  bool _isSwitchingEpisode = false;
  Timer? _progressSaveTimer;
  VoidCallback? _videoListener;
  bool _isDisposed = false;
  int _playSessionId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemControlsService.setKeepScreenOn(true);
    _currentEpIndex = widget.initialEpisodeIndex;
    _loadFullDetailAndPlay();
  }

  bool _wasPlayingBeforePause = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 🌟 手机退到后台、锁屏熄屏时立即持久化存储当前播放进度并暂停
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _wasPlayingBeforePause = _videoPlayerController?.value.isPlaying ?? true;
      _saveCurrentProgress();
      _videoPlayerController?.pause();
    } else if (state == AppLifecycleState.resumed) {
      // 🌟 亮屏解锁切回前台时，重新激活常亮并无缝继续播放
      SystemControlsService.setKeepScreenOn(true);
      if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
        if (_videoPlayerController!.value.hasError || _hasError) {
          final pos = _videoPlayerController!.value.position.inMilliseconds;
          _playCurrentEpisode(seekToMs: pos > 0 ? pos : null);
        } else if (_wasPlayingBeforePause) {
          _videoPlayerController!.play();
        }
      }
    }
  }

  void _saveCurrentProgress() {
    if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      final pos = _videoPlayerController!.value.position.inMilliseconds;
      final dur = _videoPlayerController!.value.duration.inMilliseconds;
      if (pos > 0 || dur > 0) {
        DramaHistoryService.saveHistory(
          drama: widget.drama,
          episodeIndex: _currentEpIndex,
          positionMs: pos,
          durationMs: dur,
        );
      }
    }
  }

  /// 🌟 彻底静音并销毁当前播放器实例（杜绝返回或切集后背景漏音）
  void _releaseCurrentPlayer() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = null;

    if (_videoPlayerController != null && _videoListener != null) {
      try {
        _videoPlayerController!.removeListener(_videoListener!);
      } catch (_) {}
      _videoListener = null;
    }

    final oldVideo = _videoPlayerController;
    final oldChewie = _chewieController;

    _videoPlayerController = null;
    _chewieController = null;

    if (oldVideo != null) {
      try {
        oldVideo.pause();
        oldVideo.setVolume(0.0);
      } catch (_) {}
      try {
        oldChewie?.pause();
        oldChewie?.dispose();
      } catch (_) {}
      try {
        oldVideo.dispose();
      } catch (_) {}
    }
  }

  Future<void> _loadFullDetailAndPlay() async {
    int resumePositionMs = 0;

    // 1. 尝试从历史中恢复上次播放的集数与秒级进度
    final savedHistory = await DramaHistoryService.getDramaHistory(widget.drama.id);
    if (savedHistory != null && mounted) {
      if (widget.initialEpisodeIndex == 0 || widget.initialEpisodeIndex == savedHistory.lastEpisodeIndex) {
        setState(() {
          _currentEpIndex = savedHistory.lastEpisodeIndex;
        });
        resumePositionMs = savedHistory.positionMs;
      }
    }

    // 2. 优先拉取真实详情与全剧集直链列表
    try {
      final detail = await DramaService.fetchDramaDetail(widget.drama);
      if (mounted) {
        setState(() {
          widget.drama.episodes = detail.episodes;
          widget.drama.totalEpisodes = detail.totalEpisodes;
        });
      }
    } catch (_) {}

    // 3. 校验集数并开始播放（携带恢复进度）
    if (mounted) {
      if (widget.drama.episodes.isNotEmpty) {
        _currentEpIndex = _currentEpIndex.clamp(0, widget.drama.episodes.length - 1);
      }
      _playCurrentEpisode(seekToMs: resumePositionMs);
    }
  }

  void _startProgressTracking(VideoPlayerController controller) {
    _progressSaveTimer?.cancel();
    // 🌟 每 2 秒高频实时持久化一次当前播放进度，保证任何时刻闪退/杀后台都不丢进度
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (controller.value.isInitialized && mounted) {
        final pos = controller.value.position.inMilliseconds;
        final dur = controller.value.duration.inMilliseconds;
        if (pos > 0) {
          DramaHistoryService.saveHistory(
            drama: widget.drama,
            episodeIndex: _currentEpIndex,
            positionMs: pos,
            durationMs: dur,
          );
        }
      }
    });
  }

  void _setupVideoListener(VideoPlayerController controller, int epIndexForThisController) {
    if (_videoListener != null && _videoPlayerController != null) {
      try {
        _videoPlayerController!.removeListener(_videoListener!);
      } catch (_) {}
    }

    _videoListener = () {
      if (!mounted || _isDisposed) return;
      if (controller != _videoPlayerController || epIndexForThisController != _currentEpIndex) {
        return;
      }

      if (controller.value.isInitialized &&
          !_isSwitchingEpisode &&
          controller.value.duration > const Duration(seconds: 1)) {
        final pos = controller.value.position;
        final dur = controller.value.duration;
        final isCompleted = controller.value.isCompleted ||
            (pos >= dur - const Duration(milliseconds: 600) &&
                pos > const Duration(seconds: 2) &&
                !controller.value.isPlaying);

        if (isCompleted) {
          // 立即锁定状态并注销监听，杜绝任何二次触发
          _isSwitchingEpisode = true;
          if (_videoListener != null) {
            try {
              controller.removeListener(_videoListener!);
            } catch (_) {}
            _videoListener = null;
          }
          _playNextEpisode();
        }
      }
    };

    controller.addListener(_videoListener!);
  }

  Future<void> _playCurrentEpisode({int? seekToMs, bool autoFullScreen = false}) async {
    final int sessionId = ++_playSessionId;
    final int epIndexToPlay = _currentEpIndex;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    _isSwitchingEpisode = true;
    _releaseCurrentPlayer();

    try {
      // 确保剧集列表不会越界
      while (widget.drama.episodes.length <= epIndexToPlay) {
        final epNum = widget.drama.episodes.length + 1;
        widget.drama.episodes.add(DramaEpisode(
          episodeNum: epNum,
          title: '第 $epNum 集',
        ));
      }

      final currentEp = widget.drama.episodes[epIndexToPlay];

      // 实时请求该集播放页获取带签名的 m3u8 URL 以及真实点赞与评论数据
      final cachedStream = currentEp.videoUrl;
      final playData = await DramaService.resolveEpisodePlayData(
        widget.drama.id,
        currentEp.episodeNum,
        customPlayUrl: (cachedStream.isNotEmpty && (cachedStream.contains('.m3u8') || cachedStream.contains('.mp4')))
            ? cachedStream
            : currentEp.embedUrl,
      );
      String realStreamUrl = playData.streamUrl;
      if (realStreamUrl.isNotEmpty) {
        currentEp.videoUrl = realStreamUrl;
      }

      if (!mounted || _isDisposed || sessionId != _playSessionId || epIndexToPlay != _currentEpIndex) {
        return;
      }

      // 同步更新真实点赞量与评论列表
      setState(() {
        if (playData.interaction.likeCount > 0 || playData.interaction.likeCountText != '0') {
          _likeCount = playData.interaction.likeCount;
          _likeCountText = playData.interaction.likeCountText;
          _isLiked = playData.interaction.isLiked;
        }
        if (playData.interaction.commentCount > 0) {
          _commentCount = playData.interaction.commentCount;
        }
        if (playData.interaction.comments.isNotEmpty) {
          _comments = List.from(playData.interaction.comments);
        }
        if (playData.interaction.playCount.isNotEmpty) {
          widget.drama.playCount = playData.interaction.playCount;
        }
      });

      // 异步尝试从 API 加载更完整的评论列表
      _loadEpisodeComments(epIndexToPlay);

      if (realStreamUrl.isEmpty || !realStreamUrl.startsWith('http')) {
        throw Exception('未能获取到第 ${currentEp.episodeNum} 集的播放流地址，请检查网络或点击重试');
      }

      final uri = Uri.parse(realStreamUrl);

      final rawBaseUrl = await SettingsService.getDramaBaseUrl();
      final workingDomain = await DramaService.resolveWorkingDomain(rawBaseUrl);
      final referer = workingDomain.isNotEmpty ? workingDomain : rawBaseUrl;

      if (!mounted || _isDisposed || sessionId != _playSessionId || epIndexToPlay != _currentEpIndex) {
        return;
      }

      final controller = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: {
          if (referer.isNotEmpty) 'Referer': referer.endsWith('/') ? referer : '$referer/',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
        },
      );
      
      await controller.initialize();

      if (!mounted || _isDisposed || sessionId != _playSessionId || epIndexToPlay != _currentEpIndex) {
        try {
          controller.pause();
          controller.setVolume(0.0);
          controller.dispose();
        } catch (_) {}
        return;
      }

      _videoPlayerController = controller;

      // 🌟 核心修复：如果存在上次播放进度且大于 1 秒，自动跳转续播
      if (seekToMs != null && seekToMs > 1000) {
        final totalDuration = controller.value.duration.inMilliseconds;
        if (totalDuration == 0 || seekToMs < totalDuration - 3000) {
          await controller.seekTo(Duration(milliseconds: seekToMs));
          final min = (seekToMs / 60000).floor();
          final sec = ((seekToMs % 60000) / 1000).floor();
          final timeStr = '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.history_toggle_off_rounded, color: Colors.amberAccent, size: 18),
                    const SizedBox(width: 8),
                    Text('⏱️ 已为您自动恢复播放进度至 $timeStr'),
                  ],
                ),
                duration: const Duration(seconds: 3),
                backgroundColor: const Color(0xFF1E2235),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }

      // 自动开始历史记录上报
      _startProgressTracking(controller);

      // 记录当前观看历史（严格记录实际正在播放的集数）
      final currentPos = controller.value.position.inMilliseconds;
      DramaHistoryService.saveHistory(
        drama: widget.drama,
        episodeIndex: epIndexToPlay,
        positionMs: currentPos > 0 ? currentPos : (seekToMs ?? 0),
        durationMs: controller.value.duration.inMilliseconds,
      );

      // 绑定完播监听器，绑定专属集数索引
      _setupVideoListener(controller, epIndexToPlay);

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 9 / 16,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        playbackSpeeds: const [0.75, 1.0, 1.25, 1.5, 2.0],
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFFF2E63),
          handleColor: const Color(0xFFFF0844),
          backgroundColor: Colors.grey.shade800,
          bufferedColor: Colors.white24,
        ),
        routePageBuilder: (context, animation, secondaryAnimation, controllerProvider) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                controllerProvider,
                const Positioned(
                  top: 50,
                  bottom: 70,
                  left: 0,
                  right: 0,
                  child: PlayerGestureOverlay(),
                ),
              ],
            ),
          );
        },
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: SpinKitFadingCircle(color: Color(0xFFFF2E63), size: 42),
          ),
        ),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (autoFullScreen) {
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted && _chewieController != null) {
              _chewieController?.enterFullScreen();
            }
          });
        }
      }

      // 新一集初始化完成，解除切换锁
      _isSwitchingEpisode = false;
    } catch (e) {
      if (sessionId != _playSessionId || _isDisposed || !mounted) return;
      _isSwitchingEpisode = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _playNextEpisode() {
    final total = widget.drama.totalEpisodes > 0
        ? widget.drama.totalEpisodes
        : (widget.drama.episodes.isNotEmpty ? widget.drama.episodes.length : 1);

    if (_currentEpIndex < total - 1) {
      _isSwitchingEpisode = true;
      final wasFullScreen = _chewieController?.isFullScreen ?? false;
      if (wasFullScreen) {
        _chewieController?.exitFullScreen();
      }

      final int nextIndex = _currentEpIndex + 1;
      final int nextEpNum = nextIndex + 1;

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.play_circle_fill_rounded, color: Colors.amberAccent, size: 18),
                const SizedBox(width: 8),
                Text('🎬 正在自动播放第 $nextEpNum 集...'),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF1E2235),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() {
        _currentEpIndex = nextIndex;
      });
      _playCurrentEpisode(autoFullScreen: wasFullScreen);
    } else {
      _isSwitchingEpisode = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 恭喜！本剧全部剧集已播放完毕！'),
            duration: Duration(seconds: 3),
            backgroundColor: Color(0xFFFF2E63),
          ),
        );
      }
    }
  }

  void _playPrevEpisode() {
    if (_isSwitchingEpisode) return;
    if (_currentEpIndex > 0) {
      _isSwitchingEpisode = true;
      final wasFullScreen = _chewieController?.isFullScreen ?? false;
      if (wasFullScreen) {
        _chewieController?.exitFullScreen();
      }
      final int prevIndex = _currentEpIndex - 1;
      setState(() {
        _currentEpIndex = prevIndex;
      });
      _playCurrentEpisode(autoFullScreen: wasFullScreen);
    }
  }

  void _showEpisodeSelector() {
    final total = widget.drama.totalEpisodes > 0
        ? widget.drama.totalEpisodes
        : (widget.drama.episodes.isNotEmpty ? widget.drama.episodes.length : 1);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141724),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '选集 (${_currentEpIndex + 1}/$total)',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: GridView.builder(
                      itemCount: total,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.2,
                      ),
                      itemBuilder: (context, index) {
                        final isCurrent = index == _currentEpIndex;
                        return InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            if (index != _currentEpIndex) {
                              final wasFullScreen = _chewieController?.isFullScreen ?? false;
                              if (wasFullScreen) {
                                _chewieController?.exitFullScreen();
                              }
                              setState(() {
                                _currentEpIndex = index;
                              });
                              _playCurrentEpisode(autoFullScreen: wasFullScreen);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isCurrent ? const Color(0xFFFF2E63) : const Color(0xFF1E2235),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isCurrent ? const Color(0xFFFF0844) : Colors.white12,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isCurrent ? Colors.white : Colors.white70,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 异步加载或刷新该集评论列表
  Future<void> _loadEpisodeComments(int epIndex) async {
    try {
      final epNum = widget.drama.episodes.length > epIndex ? widget.drama.episodes[epIndex].episodeNum : epIndex + 1;
      final comments = await DramaService.fetchComments(widget.drama.id, ep: epNum, page: 1, size: 20);
      if (mounted && epIndex == _currentEpIndex && comments.isNotEmpty) {
        setState(() {
          _comments = comments;
          if (comments.length > _commentCount) {
            _commentCount = comments.length;
          }
        });
      }
    } catch (_) {}
  }

  /// 切换短剧点赞状态并上报
  Future<void> _toggleVideoLike() async {
    if (_isLikingVideo) return;
    final epNum = widget.drama.episodes.length > _currentEpIndex
        ? widget.drama.episodes[_currentEpIndex].episodeNum
        : _currentEpIndex + 1;

    setState(() {
      _isLikingVideo = true;
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
      _likeCountText = '$_likeCount';
    });

    final res = await DramaService.toggleVideoLike(widget.drama.id, ep: epNum);
    if (!mounted) return;

    setState(() {
      _isLikingVideo = false;
      if (res != null) {
        if (res['liked'] is bool) {
          _isLiked = res['liked'] as bool;
        }
        if (res['likes'] is num) {
          _likeCount = (res['likes'] as num).toInt();
          _likeCountText = '$_likeCount';
        } else if (res['ep_likes'] is num) {
          _likeCount = (res['ep_likes'] as num).toInt();
          _likeCountText = '$_likeCount';
        }
      }
    });
  }

  /// 切换单条评论点赞状态
  Future<void> _toggleCommentLike(DramaComment comment) async {
    final prevLiked = comment.isLiked;

    setState(() {
      comment.isLiked = !prevLiked;
      comment.likes += comment.isLiked ? 1 : -1;
      if (comment.likes < 0) comment.likes = 0;
    });

    final res = await DramaService.toggleCommentLike(widget.drama.id, comment.id);
    if (mounted && res != null) {
      setState(() {
        if (res['liked'] is bool) {
          comment.isLiked = res['liked'] as bool;
        }
        if (res['likes'] is num) {
          comment.likes = (res['likes'] as num).toInt();
        }
      });
    }
  }

  /// 辅助解析十六进制颜色
  Color _parseHexColor(String hexStr) {
    try {
      String clean = hexStr.replaceAll('#', '').trim();
      if (clean.length == 6) {
        clean = 'FF$clean';
      }
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return const Color(0xFF5C7FD1);
    }
  }

  /// 弹出精美半屏评论抽屉
  void _showCommentsModal(BuildContext context) {
    final TextEditingController commentTextController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              decoration: const BoxDecoration(
                color: Color(0xFF161922),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 15,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 顶部拖拽指示条
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // 标题栏
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          '全部评论 (${_commentCount > 0 ? _commentCount : _comments.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // 刷新按钮
                        IconButton(
                          icon: _isLoadingComments
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.amberAccent,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                          tooltip: '刷新评论',
                          onPressed: _isLoadingComments
                              ? null
                              : () async {
                                  setModalState(() => _isLoadingComments = true);
                                  await _loadEpisodeComments(_currentEpIndex);
                                  if (mounted) {
                                    setModalState(() => _isLoadingComments = false);
                                  }
                                },
                        ),
                        // 关闭按钮
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),

                  // 评论列表主体
                  Expanded(
                    child: _isLoadingComments && _comments.isEmpty
                        ? const Center(
                            child: SpinKitFadingCircle(
                              color: Color(0xFFFF2E63),
                              size: 36,
                            ),
                          )
                        : _comments.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 54,
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '还没有评论，快来抢沙发～',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.45),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                itemCount: _comments.length,
                                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 20),
                                itemBuilder: (context, index) {
                                  final c = _comments[index];
                                  final avatarColor = _parseHexColor(c.avatarColor);
                                  final avatarChar = c.avatar.isNotEmpty
                                      ? c.avatar.substring(0, 1)
                                      : (c.author.isNotEmpty ? c.author.substring(0, 1) : '?');

                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 头像
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: avatarColor,
                                        child: Text(
                                          avatarChar,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // 评论主体
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    c.author,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                if (c.isPinned) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFF2E63).withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: const Color(0xFFFF2E63), width: 0.8),
                                                    ),
                                                    child: const Text(
                                                      '置顶',
                                                      style: TextStyle(
                                                        color: Color(0xFFFF2E63),
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(width: 8),
                                                Text(
                                                  c.time,
                                                  style: const TextStyle(color: Colors.white30, fontSize: 11),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              c.content,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // 点赞按钮
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () async {
                                          await _toggleCommentLike(c);
                                          setModalState(() {});
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                c.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                                color: c.isLiked ? Colors.redAccent : Colors.white38,
                                                size: 18,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${c.likes}',
                                                style: TextStyle(
                                                  color: c.isLiked ? Colors.redAccent : Colors.white38,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                  ),

                  // 底部发表评论输入栏
                  Container(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 10,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E222D),
                      border: Border(top: BorderSide(color: Colors.white10)),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(0xFFFF2E63),
                          child: Icon(Icons.person_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF12141A),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.white12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: TextField(
                              controller: commentTextController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: '写下你的精彩评论...',
                                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                              maxLines: 1,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) {
                                _handleSendComment(commentTextController, setModalState);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: Color(0xFFFF2E63), size: 22),
                          onPressed: () {
                            _handleSendComment(commentTextController, setModalState);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 发送评论处理逻辑
  void _handleSendComment(TextEditingController controller, StateSetter setModalState) {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    final newComment = DramaComment(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      author: '我',
      avatar: '我',
      avatarColor: '#FF2E63',
      time: '刚刚',
      content: text,
      likes: 0,
      isLiked: false,
    );

    controller.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _comments.insert(0, newComment);
      _commentCount += 1;
    });
    setModalState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 评论已发表！'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF1E2235),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _playSessionId++;
    WidgetsBinding.instance.removeObserver(this);
    _saveCurrentProgress();
    _releaseCurrentPlayer();
    SystemControlsService.setKeepScreenOn(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // 🌟 手机点击物理返回键或手势返回时，立刻触发保存进度并静音销毁播放器，彻底杜绝后台漏音
        _isDisposed = true;
        _playSessionId++;
        _saveCurrentProgress();
        _releaseCurrentPlayer();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. 核心播放器主体 + 左右滑动控光控音手势
            _isLoading
                ? const Center(child: SpinKitFadingCircle(color: Color(0xFFFF2E63), size: 48))
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 54),
                            const SizedBox(height: 12),
                            Text('播放异常: $_errorMessage', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _playCurrentEpisode(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('重试播放'),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Chewie(
                            key: ValueKey('chewie_${widget.drama.id}_$_currentEpIndex'),
                            controller: _chewieController!,
                          ),
                          // 🌟 竖屏手势控光控音层
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 60,
                            bottom: 80,
                            left: 0,
                            right: 0,
                            child: const PlayerGestureOverlay(),
                          ),
                        ],
                      ),

            // 2. 顶部导航栏（返回 + 剧集名称 + 选集信息）
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.8),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      onPressed: () {
                        _isDisposed = true;
                        _playSessionId++;
                        _saveCurrentProgress();
                        _releaseCurrentPlayer();
                        Navigator.pop(context);
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.drama.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '第 ${_currentEpIndex + 1} 集 / 共 ${widget.drama.totalEpisodes} 集${widget.drama.playCount.isNotEmpty ? ' · 🔥 ${widget.drama.playCount}' : ''}',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. 右侧快捷操作栏（点赞、选集、上下集快速切换）
            Positioned(
              right: 12,
              bottom: 100,
              child: Column(
                children: [
                  // 点赞
                  IconButton(
                    icon: Icon(
                      _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isLiked ? Colors.redAccent : Colors.white,
                      size: 30,
                    ),
                    onPressed: _toggleVideoLike,
                  ),
                  Text(
                    _likeCountText.isNotEmpty ? _likeCountText : '$_likeCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  const SizedBox(height: 16),

                  // 评论
                  IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: () => _showCommentsModal(context),
                  ),
                  Text(
                    _commentCount > 0 ? '$_commentCount' : (_comments.isNotEmpty ? '${_comments.length}' : '评论'),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  const SizedBox(height: 16),

                  // 选集
                  GestureDetector(
                    onTap: _showEpisodeSelector,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.playlist_play_rounded, color: Colors.amberAccent, size: 24),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('选集', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  const SizedBox(height: 16),

                  // 上一集
                  if (_currentEpIndex > 0) ...[
                    GestureDetector(
                      onTap: _playPrevEpisode,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('上一集', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    const SizedBox(height: 16),
                  ],

                  // 下一集
                  GestureDetector(
                    onTap: _playNextEpisode,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2E63).withOpacity(0.8),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF2E63).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('下一集', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
