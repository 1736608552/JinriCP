import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/short_drama.dart';
import '../services/drama_service.dart';
import '../services/image_loader_service.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';
import 'drama_player_screen.dart';

class GossipDetailScreen extends StatefulWidget {
  final ShortDrama drama;

  const GossipDetailScreen({
    super.key,
    required this.drama,
  });

  @override
  State<GossipDetailScreen> createState() => _GossipDetailScreenState();
}

class _GossipDetailScreenState extends State<GossipDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  GossipArticle? _article;
  bool _isLoading = true;

  // 视频播放器状态
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _activeVideoUrl;
  String _activeVideoTitle = '';
  bool _isPlayingInline = false;
  bool _isLoadingVideo = false;
  String _videoError = '';

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

  @override
  void dispose() {
    _releaseVideoPlayer();
    _scrollController.dispose();
    super.dispose();
  }

  void _releaseVideoPlayer() {
    final oldChewie = _chewieController;
    final oldVideo = _videoController;
    _chewieController = null;
    _videoController = null;

    if (oldVideo != null) {
      try {
        oldVideo.pause();
        oldVideo.setVolume(0.0);
        oldVideo.dispose();
      } catch (_) {}
    }
    if (oldChewie != null) {
      try {
        oldChewie.dispose();
      } catch (_) {}
    }
  }

  Future<void> _loadArticle() async {
    setState(() => _isLoading = true);
    final article = await DramaService.fetchGossipDetail(widget.drama.id);
    if (mounted) {
      setState(() {
        _article = article;
        _isLoading = false;
      });
    }
  }

  /// 播放指定直链的内嵌视频
  Future<void> _playVideo(String videoUrl, {String? title}) async {
    if (videoUrl.isEmpty) return;

    if (_activeVideoUrl == videoUrl && _videoController != null && _chewieController != null) {
      return;
    }

    setState(() {
      _activeVideoUrl = videoUrl;
      _activeVideoTitle = title ?? '现场猛料视频';
      _isPlayingInline = true;
      _isLoadingVideo = true;
      _videoError = '';
    });

    _releaseVideoPlayer();

    try {
      final rawBaseUrl = await SettingsService.getDramaBaseUrl();
      final workingDomain = await DramaService.resolveWorkingDomain(rawBaseUrl);
      final referer = workingDomain.isNotEmpty ? workingDomain : rawBaseUrl;

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: {
          if (referer.isNotEmpty) 'Referer': referer.endsWith('/') ? referer : '$referer/',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
        },
      );

      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }

      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 16 / 9,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              '视频加载失败: $errorMessage',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _videoController = controller;
          _chewieController = chewie;
          _isLoadingVideo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
          _videoError = '视频解析失败，请检查网络或重试';
        });
      }
    }
  }

  /// 启动关联正片或首个内嵌视频播放
  Future<void> _startInlinePlay() async {
    final dramaId = _article?.relatedDramaId ?? '';
    if (dramaId.isEmpty) {
      if (_article?.videoUrls.isNotEmpty ?? false) {
        await _playVideo(_article!.videoUrls.first, title: '爆料现场猛料视频 1');
      }
      return;
    }

    final dramaTitle = _article!.relatedDramaTitle.isNotEmpty
        ? _article!.relatedDramaTitle
        : widget.drama.title;

    setState(() {
      _isPlayingInline = true;
      _isLoadingVideo = true;
      _videoError = '';
      _activeVideoTitle = '《$dramaTitle》正片视频';
    });

    _releaseVideoPlayer();

    // 滚动到页面顶部，方便观看播放器
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }

    try {
      final playData = await DramaService.resolveEpisodePlayData(dramaId, 1);
      final streamUrl = playData.streamUrl;
      if (streamUrl.isEmpty || !streamUrl.startsWith('http')) {
        throw Exception('未能获取到播放流地址');
      }

      await _playVideo(streamUrl, title: '《$dramaTitle》正片');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingVideo = false;
          _videoError = '视频解析失败，请检查网络或点击重试';
        });
      }
    }
  }

  /// 跳转独立完整播放器
  void _openFullScreenPlayer(BuildContext context, String dramaId, String dramaTitle) {
    if (dramaId.isEmpty) return;
    _releaseVideoPlayer();
    setState(() => _isPlayingInline = false);

    final targetDrama = ShortDrama(
      id: dramaId,
      title: dramaTitle.isNotEmpty ? dramaTitle : '正片短剧',
      coverUrl: widget.drama.coverUrl,
      description: '从吃瓜爆料直达正片全集',
      category: 'AI成人短剧',
      totalEpisodes: 1,
      rating: 9.8,
      playCount: '热播',
      tags: ['正片', '爆料推荐'],
      episodes: [],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DramaPlayerScreen(drama: targetDrama),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(
          widget.drama.title.isNotEmpty ? widget.drama.title : '吃瓜详情',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: AppTheme.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if ((_article?.videoUrls.isNotEmpty ?? false) || (_article?.relatedDramaId.isNotEmpty ?? false))
            TextButton.icon(
              onPressed: () {
                if (_article?.relatedDramaId.isNotEmpty ?? false) {
                  _openFullScreenPlayer(
                    context,
                    _article!.relatedDramaId,
                    _article!.relatedDramaTitle,
                  );
                } else if (_article?.videoUrls.isNotEmpty ?? false) {
                  _playVideo(_article!.videoUrls.first, title: '爆料现场视频 1');
                }
              },
              icon: const Icon(Icons.play_circle_outline_rounded, size: 18, color: AppTheme.primaryPink),
              label: Text(
                _article?.relatedDramaId.isNotEmpty == true ? '正片播放' : '看视频',
                style: const TextStyle(color: AppTheme.primaryPink, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: SpinKitFadingCircle(color: AppTheme.primaryPink, size: 40),
            )
          : _article == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.article_outlined, size: 56, color: AppTheme.textMuted(context)),
                      const SizedBox(height: 12),
                      Text(
                        '暂未获取到文章内容',
                        style: TextStyle(color: AppTheme.textMuted(context), fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadArticle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('重新加载'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🌟 文章内嵌视频播放窗口（支持在文章内直接起播，也可切换全屏）
                      if (_article!.relatedDramaId.isNotEmpty) ...[
                        _buildInlineVideoPlayer(context),
                        const SizedBox(height: 16),
                      ],

                      // 文章大标题
                      Text(
                        _article!.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary(context),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 作者与发布时间栏
                      Row(
                        children: [
                          ClipOval(
                            child: SizedBox(
                              width: 34,
                              height: 34,
                              child: _article!.authorAvatar.isNotEmpty
                                  ? GossipImageWidget(
                                      imageUrl: _article!.authorAvatar,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: AppTheme.primaryPink.withOpacity(0.2),
                                      child: const Icon(Icons.person, size: 20, color: AppTheme.primaryPink),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _article!.author,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                              if (_article!.publishDate.isNotEmpty)
                                Text(
                                  _article!.publishDate,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted(context),
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          if (_article!.categoryName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPink.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.primaryPink.withOpacity(0.3), width: 0.8),
                              ),
                              child: Text(
                                _article!.categoryName,
                                style: const TextStyle(
                                  color: AppTheme.primaryPink,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: AppTheme.borderColor(context), height: 1),
                      const SizedBox(height: 16),

                      // 正文段落与高清插图交错呈现
                      ..._buildContentElements(context),

                      // 底部瓜友热搜标签云
                      _buildTagsCloud(context),

                      // 底部关联正片短剧直达播放大卡片
                      if (_article!.relatedDramaId.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildWatchDramaCard(context),
                      ],
                    ],
                  ),
                ),
    );
  }

  /// 🌟 顶部内嵌视频播放窗口组件
  Widget _buildInlineVideoPlayer(BuildContext context) {
    final dramaTitle = _article!.relatedDramaTitle.isNotEmpty
        ? _article!.relatedDramaTitle
        : widget.drama.title;

    if (_isPlayingInline) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _isLoadingVideo
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SpinKitFadingCircle(color: AppTheme.primaryPink, size: 36),
                      const SizedBox(height: 10),
                      Text(
                        '正在解析《$dramaTitle》视频流...',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : _videoError.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 36),
                          const SizedBox(height: 8),
                          Text(_videoError, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _startInlinePlay,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPink,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            ),
                            child: const Text('重试播放'),
                          ),
                        ],
                      ),
                    )
                  : _chewieController != null
                      ? Chewie(controller: _chewieController!)
                      : const SizedBox.shrink(),
        ),
      );
    }

    // 尚未起播时展示视频大画幅封面与起播诱导
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context), width: 0.8),
        boxShadow: AppTheme.cardShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.drama.coverUrl.isNotEmpty)
              GossipImageWidget(imageUrl: widget.drama.coverUrl, fit: BoxFit.cover)
            else
              Container(color: const Color(0xFF1E1E24)),

            // 黑色半透明渐变
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.35),
                    Colors.transparent,
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
            ),

            // 左上角正片标识
            Positioned(
              top: 10,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.ondemand_video_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('正片视频', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

            // 右上角独立播放按钮
            Positioned(
              top: 8,
              right: 8,
              child: InkWell(
                onTap: () => _openFullScreenPlayer(context, _article!.relatedDramaId, dramaTitle),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fullscreen_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 2),
                      Text('大屏播放', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),

            // 中央大播放按钮
            Center(
              child: InkWell(
                onTap: _startInlinePlay,
                borderRadius: BorderRadius.circular(35),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryPink.withOpacity(0.55),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
                ),
              ),
            ),

            // 底部剧名与引导
            Positioned(
              bottom: 12,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '《$dramaTitle》正片视频',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _startInlinePlay,
                    child: const Text(
                      '在文章内播放 ▶',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建正文结构化元素与多媒体流式节点
  List<Widget> _buildContentElements(BuildContext context) {
    if (_article != null && _article!.contentNodes.isNotEmpty) {
      return _article!.contentNodes.map((node) {
        switch (node.type) {
          case ArticleNodeType.heading:
            return _buildHeadingNode(context, node);
          case ArticleNodeType.paragraph:
            return _buildParagraphNode(context, node);
          case ArticleNodeType.image:
            return _buildImageNode(context, node);
          case ArticleNodeType.video:
            return _buildVideoNode(context, node);
          case ArticleNodeType.dramaLink:
            return _buildDramaLinkNode(context, node);
        }
      }).toList();
    }

    // 兼容旧数据的回退渲染
    final List<Widget> widgets = [];
    final paragraphs = _article?.paragraphs ?? [];
    final images = _article?.imageUrls ?? [];

    int imgIndex = 0;
    for (int i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            p,
            style: TextStyle(
              fontSize: 15.5,
              height: 1.75,
              color: AppTheme.textPrimary(context).withOpacity(0.92),
              letterSpacing: 0.3,
            ),
          ),
        ),
      );

      if (imgIndex < images.length && (i % 2 == 0 || i == paragraphs.length - 1)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GossipImageWidget(
              imageUrl: images[imgIndex],
              fit: BoxFit.cover,
            ),
          ),
        );
        imgIndex++;
      }
    }

    while (imgIndex < images.length) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GossipImageWidget(
            imageUrl: images[imgIndex],
            fit: BoxFit.cover,
          ),
        ),
      );
      imgIndex++;
    }

    return widgets;
  }

  /// 小节标题节点
  Widget _buildHeadingNode(BuildContext context, ArticleContentNode node) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              node.content,
              style: TextStyle(
                fontSize: 17.5,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary(context),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 段落节点
  Widget _buildParagraphNode(BuildContext context, ArticleContentNode node) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        node.content,
        style: TextStyle(
          fontSize: 15.5,
          height: 1.75,
          color: AppTheme.textPrimary(context).withOpacity(0.92),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// 图片节点
  Widget _buildImageNode(BuildContext context, ArticleContentNode node) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GossipImageWidget(
          imageUrl: node.content,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// 内嵌原生多视频节点（支持边看边播与独立全屏）
  Widget _buildVideoNode(BuildContext context, ArticleContentNode node) {
    final isCurrent = _activeVideoUrl == node.content;
    final vTitle = node.title ?? '爆料现场实锤视频';

    if (isCurrent) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _isLoadingVideo
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SpinKitFadingCircle(color: AppTheme.primaryPink, size: 36),
                        const SizedBox(height: 10),
                        Text(
                          '正在加载 $vTitle...',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : _videoError.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 36),
                            const SizedBox(height: 8),
                            Text(_videoError, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: () => _playVideo(node.content, title: vTitle),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPink),
                              child: const Text('重试播放', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : _chewieController != null
                        ? Chewie(controller: _chewieController!)
                        : const SizedBox.shrink(),
          ),
        ),
      );
    }

    // 未起播时展现沉浸式播放卡片
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryPink.withOpacity(0.4), width: 1.2),
          boxShadow: AppTheme.cardShadow(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.drama.coverUrl.isNotEmpty)
                GossipImageWidget(imageUrl: widget.drama.coverUrl, fit: BoxFit.cover)
              else
                Container(color: const Color(0xFF141724)),

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
              ),

              Positioned(
                top: 10,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_rounded, color: Colors.white, size: 13),
                      SizedBox(width: 4),
                      Text('现场实锤视频', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              Center(
                child: InkWell(
                  onTap: () => _playVideo(node.content, title: vTitle),
                  borderRadius: BorderRadius.circular(35),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPink.withOpacity(0.6),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
                  ),
                ),
              ),

              Positioned(
                bottom: 12,
                left: 14,
                right: 14,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        vTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _playVideo(node.content, title: vTitle),
                      child: const Text(
                        '点击在文内播放 ▶',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 关联正片短剧跳转节点
  Widget _buildDramaLinkNode(BuildContext context, ArticleContentNode node) {
    final dramaTitle = node.title?.isNotEmpty == true ? node.title! : '精选正片';
    final dramaId = node.extra ?? _article?.relatedDramaId ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryPink.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryPink.withOpacity(0.4), width: 0.9),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_circle_fill_rounded, color: AppTheme.primaryPink, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '点击观看：',
                      style: TextStyle(
                        color: AppTheme.textPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: '《$dramaTitle》',
                      style: const TextStyle(
                        color: AppTheme.primaryPink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: _startInlinePlay,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPink,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '文内播放',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (dramaId.isNotEmpty) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _openFullScreenPlayer(context, dramaId, dramaTitle),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg(context),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderColor(context), width: 0.8),
                  ),
                  child: Text(
                    '独立播放',
                    style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 瓜友热搜标签云
  Widget _buildTagsCloud(BuildContext context) {
    if (_article?.tags.isEmpty ?? true) return const SizedBox.shrink();
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tag_rounded, size: 16, color: AppTheme.primaryPink),
              const SizedBox(width: 4),
              Text(
                '瓜友热议标签',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _article!.tags.map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2235) : const Color(0xFFF2F4F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor(context), width: 0.6),
                ),
                child: Text(
                  '#$t',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 关联正片短剧直达播放大卡片
  Widget _buildWatchDramaCard(BuildContext context) {
    final title = _article!.relatedDramaTitle.isNotEmpty
        ? _article!.relatedDramaTitle
        : widget.drama.title;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF2A6D).withOpacity(0.18),
            const Color(0xFF9100FF).withOpacity(0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryPink.withOpacity(0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPink.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.movie_filter_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 3),
                    Text('官方正片直达', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Spacer(),
              const Text('超清正片', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '《$title》',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '支持直接在文章内边看边播，也可以一键切换至沉浸式大屏播放器！',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted(context), height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _startInlinePlay,
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('在文章内播放', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPink,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => _openFullScreenPlayer(context, _article!.relatedDramaId, title),
                    icon: const Icon(Icons.fullscreen_rounded, size: 20),
                    label: const Text('独立大屏播放', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary(context),
                      side: BorderSide(color: AppTheme.borderColor(context), width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 🌟 高性能吃瓜图片渲染引擎 (支持自动 AES-128-CBC 解密、防盗链穿透与内存缓存)
class GossipImageWidget extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  const GossipImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  State<GossipImageWidget> createState() => _GossipImageWidgetState();
}

class _GossipImageWidgetState extends State<GossipImageWidget> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant GossipImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final url = widget.imageUrl.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final cached = ImageLoaderService.getCachedImage(url);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _imageBytes = cached;
          _isLoading = false;
        });
      }
      return;
    }

    final domain = await SettingsService.getDramaBaseUrl();
    final bytes = await ImageLoaderService.loadImage(url, domain: domain);
    if (mounted) {
      setState(() {
        _imageBytes = bytes;
        _isLoading = false;
        _hasError = bytes == null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? 220,
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SpinKitFadingCircle(color: AppTheme.primaryPink, size: 28),
        ),
      );
    }

    if (_hasError || _imageBytes == null) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        _imageBytes!,
        fit: widget.fit,
        width: widget.width ?? double.infinity,
        height: widget.height,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
