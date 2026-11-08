import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/live_stream.dart';
import '../services/api_service.dart';
import '../services/proxy_route_service.dart';
import '../services/system_controls_service.dart';
import '../widgets/player_gesture_overlay.dart';
import '../widgets/route_selection_modal.dart';

class PlayerScreen extends StatefulWidget {
  final String title;
  final String videoUrl;
  final int? viewers;
  final List<LiveStreamItem>? streamList;
  final int initialIndex;

  const PlayerScreen({
    super.key,
    required this.title,
    required this.videoUrl,
    this.viewers,
    this.streamList,
    this.initialIndex = 0,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _actualPlayUrl = '';
  int _proxyIndex = 0;
  bool _wasPlayingBeforePause = true;
  bool _isDisposed = false;
  int _initSessionId = 0;
  int _manualRetryCount = 0;
  bool _isCoverFit = false; // 是否全屏铺满画面
  bool _showControls = true; // 是否显示顶栏/主播信息/操作按钮（全屏沉浸纯净播放开关）
  Timer? _hideControlsTimer;
  late int _currentChannelIndex;
  late String _currentTitle;
  late String _currentRawUrl;
  int? _currentViewers;
  bool _showChannelToast = false;
  String _channelToastMsg = '';
  Timer? _channelToastTimer;

  Timer? _orientationResetTimer;

  bool _isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  void _allowSensorOrientation() {
    _orientationResetTimer?.cancel();
    _orientationResetTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && !_isDisposed) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
  }

  void _enterFullScreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _showChannelBanner('🖥️ 已进入全屏模式');
    _allowSensorOrientation();
  }

  void _exitFullScreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _showChannelBanner('📱 已退出全屏模式');
    _allowSensorOrientation();
  }

  void _toggleFullScreen() {
    if (_isLandscape(context)) {
      _exitFullScreen();
    } else {
      _enterFullScreen();
    }
  }

  void _onPlayerExit() {
    _isDisposed = true;
    _initSessionId++;
    _channelToastTimer?.cancel();
    _hideControlsTimer?.cancel();
    _orientationResetTimer?.cancel();

    // 强制恢复竖屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    // 恢复系统 UI 状态栏与导航栏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // 还原屏幕背光亮度至系统默认（清除 App 窗口亮度覆盖，恢复手机原亮度及自动感光）
    SystemControlsService.resetBrightness();
    // 延时 300ms（路由返回过渡动画完成后）二次补调，防止部分 ROM 在页面切换动画期间吞掉属性变更
    Future.delayed(const Duration(milliseconds: 300), () {
      SystemControlsService.resetBrightness();
    });
    // 恢复屏幕常亮
    SystemControlsService.setKeepScreenOn(false);

    _releasePlayer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) {
        setState(() {
          _showControls = false;
        });
        // 彻底隐藏系统状态栏与底部导航条，进入真正的 Android 系统级纯净全屏
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _toggleScreenFit() {
    setState(() {
      _isCoverFit = !_isCoverFit;
    });
    _showChannelBanner(_isCoverFit ? '🎬 画面已铺满全屏' : '📺 画面已恢复原始比例');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemControlsService.setKeepScreenOn(true);
    _currentChannelIndex = widget.initialIndex;
    _currentTitle = widget.title;
    _currentRawUrl = widget.videoUrl;
    _currentViewers = widget.viewers;

    // 允许随手机重力感应自适应旋转（横屏完全跟随手机，无需强制旋转）
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 沉浸式全屏配置：消除底部与顶部黑色状态栏遮挡
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    if (widget.streamList != null &&
        widget.streamList!.isNotEmpty &&
        _currentChannelIndex >= 0 &&
        _currentChannelIndex < widget.streamList!.length) {
      final s = widget.streamList![_currentChannelIndex];
      _currentTitle = '🔴 [${s.platform == 'pandatv' ? 'PandaTV' : 'FlexTV'}] ${s.userNick} - ${s.title}';
      _currentRawUrl = _resolveStreamRawUrl(s);
      _currentViewers = s.viewers;
    }

    _initializePlayer();
    _startHideControlsTimer();
  }

  /// 彻底静音并销毁当前播放器实例（杜绝切台或返回后背景漏音）
  void _releasePlayer() {
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _wasPlayingBeforePause = _videoPlayerController?.value.isPlaying ?? true;
      _videoPlayerController?.pause();
      SystemControlsService.resetBrightness();
    } else if (state == AppLifecycleState.resumed) {
      SystemControlsService.setKeepScreenOn(true);
      if (_videoPlayerController == null ||
          !_videoPlayerController!.value.isInitialized ||
          _videoPlayerController!.value.hasError ||
          _hasError) {
        _initializePlayer();
      } else if (_wasPlayingBeforePause) {
        _videoPlayerController!.play().catchError((_) {
          _initializePlayer();
        });
      }
    }
  }

  @override
  void dispose() {
    _onPlayerExit();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _resolveStreamRawUrl(LiveStreamItem s) {
    String u = s.streamUrl;
    if (u.isEmpty && s.platform == 'pandatv') {
      final direct = ApiService.getM3uStreamUrl(s.userId);
      if (direct != null && direct.isNotEmpty) {
        u = direct;
      } else {
        u = 'https://duanju-api.515355.xyz/player/pandalive.html?url=${s.userId}';
      }
    }
    return u;
  }

  void _switchToNextChannel() {
    final list = widget.streamList;
    if (list == null || list.isEmpty) {
      _showChannelBanner('当前为单频道播放');
      return;
    }
    if (_currentChannelIndex + 1 >= list.length) {
      _showChannelBanner('已是最后一个直播间 🎬');
      return;
    }
    _changeChannel(_currentChannelIndex + 1);
  }

  void _switchToPrevChannel() {
    final list = widget.streamList;
    if (list == null || list.isEmpty) {
      _showChannelBanner('当前为单频道播放');
      return;
    }
    if (_currentChannelIndex <= 0) {
      _showChannelBanner('已是第一个直播间 🎬');
      return;
    }
    _changeChannel(_currentChannelIndex - 1);
  }

  void _changeChannel(int newIndex) {
    final list = widget.streamList!;
    final s = list[newIndex];
    setState(() {
      _currentChannelIndex = newIndex;
      _currentTitle = '🔴 [${s.platform == 'pandatv' ? 'PandaTV' : 'FlexTV'}] ${s.userNick} - ${s.title}';
      _currentRawUrl = _resolveStreamRawUrl(s);
      _currentViewers = s.viewers;
      _proxyIndex = 0;
      _manualRetryCount = 0;
    });

    _showChannelBanner('👉 正在切换至：${_getCurrentUserNick()}');
    setState(() {
      _showControls = true;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _startHideControlsTimer();
    _initializePlayer();
  }

  void _showChannelBanner(String msg) {
    _channelToastTimer?.cancel();
    if (mounted) {
      setState(() {
        _channelToastMsg = msg;
        _showChannelToast = true;
      });
      _channelToastTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) {
          setState(() {
            _showChannelToast = false;
          });
        }
      });
    }
  }

  Future<void> _initializePlayer() async {
    final sessionId = ++_initSessionId;
    if (!mounted || _isDisposed) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    _releasePlayer();

    try {
      final apiService = ApiService();
      _actualPlayUrl = await apiService.resolveRealMediaUrl(
        _currentRawUrl,
        proxyIndex: _proxyIndex,
      );

      if (!mounted || _isDisposed || sessionId != _initSessionId) return;

      final encodedUrl = Uri.encodeFull(_actualPlayUrl);
      final uri = Uri.parse(encodedUrl);

      final isPandaLive = _actualPlayUrl.contains('live-video.net') ||
          _actualPlayUrl.contains('pandalive') ||
          _currentRawUrl.contains('live-video.net') ||
          _currentRawUrl.contains('pandalive') ||
          _currentTitle.contains('PandaTV');
      final isFlexTv = _actualPlayUrl.contains('naverncp.com') ||
          _actualPlayUrl.contains('flextv') ||
          _currentRawUrl.contains('naverncp.com') ||
          _currentRawUrl.contains('flextv') ||
          _currentTitle.contains('FlexTV');

      String? token = uri.queryParameters['token'];
      if (token == null && _actualPlayUrl.contains('token=')) {
        final start = _actualPlayUrl.indexOf('token=') + 6;
        final end = _actualPlayUrl.indexOf('&', start);
        token = end == -1 ? _actualPlayUrl.substring(start) : _actualPlayUrl.substring(start, end);
      }

      final activeRoute = ProxyRouteService.getActiveRoute(fallbackOffset: _proxyIndex);
      final isProxied = !activeRoute.isDirect && activeRoute.prefix.isNotEmpty;

      final isHls = _actualPlayUrl.contains('.m3u8') || isPandaLive || isFlexTv;
      final headers = <String, String>{
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        if (!isProxied) ...{
          'Origin': isPandaLive
              ? 'https://www.pandalive.co.kr'
              : (isFlexTv ? 'https://www.flextv.co.kr' : 'https://www.pandalive.co.kr'),
          'Referer': isPandaLive
              ? 'https://www.pandalive.co.kr/'
              : (isFlexTv ? 'https://www.flextv.co.kr/' : 'https://www.pandalive.co.kr/'),
          if (token != null) 'X-Playback-Token': token,
        },
        if (isFlexTv && token != null && token.isNotEmpty)
          'Cookie': 'token=$token',
        'Accept': '*/*',
      };

      final videoController = VideoPlayerController.networkUrl(
        uri,
        formatHint: isHls ? VideoFormat.hls : null,
        httpHeaders: headers,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      _videoPlayerController = videoController;

      await videoController.initialize().timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw TimeoutException('连接直播流节点超时，正在尝试降级备用节点');
        },
      );

      if (!mounted || _isDisposed || sessionId != _initSessionId) {
        videoController.dispose();
        return;
      }

      videoController.addListener(() {
        if (!mounted || _isDisposed || sessionId != _initSessionId) return;
        if (videoController.value.hasError && !_hasError) {
          final errText = videoController.value.errorDescription ?? 'ExoPlaybackException: Source error';
          if (ProxyRouteService.selectedRouteId == 'auto' && _proxyIndex < 2) {
            _proxyIndex++;
            final nextRoute = ProxyRouteService.getActiveRoute(fallbackOffset: _proxyIndex);
            _showSwitchedSnackBar('信号波动，自动尝试【${nextRoute.name}】');
            _initializePlayer();
            return;
          }
          setState(() {
            _hasError = true;
            _errorMessage = errText;
          });
        }
      });

      _chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: true,
        looping: true,
        isLive: true,
        showControls: false, // 彻底交由短剧式手势层与悬浮控制系统接管，实现 100% 满屏无黑边
        allowFullScreen: false,
        allowMuting: true,
        showControlsOnInitialize: false,
        placeholder: Container(color: Colors.black),
        errorBuilder: (context, errorMessage) {
          return _buildErrorCard(errorMessage);
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted || _isDisposed || sessionId != _initSessionId) return;

      if (ProxyRouteService.selectedRouteId == 'auto' && _proxyIndex < 2) {
        _proxyIndex++;
        final nextRoute = ProxyRouteService.getActiveRoute(fallbackOffset: _proxyIndex);
        _showSwitchedSnackBar('信号波动，自动尝试【${nextRoute.name}】');
        _initializePlayer();
        return;
      }

      if (ProxyRouteService.selectedRouteId != 'auto' && _manualRetryCount < 1) {
        _manualRetryCount++;
        _initializePlayer();
        return;
      }

      String friendlyMsg = '该直播间信号暂时离线（主播可能已下播）';
      final errStr = e.toString();
      if (errStr.contains('Source error') || errStr.contains('403') || errStr.contains('404')) {
        friendlyMsg = '主播当前信号暂时离线（可能已下播或房间关闭）';
      } else if (errStr.contains('timeout') || errStr.contains('TimeoutException')) {
        friendlyMsg = '连接直播流超时，可切换测速线路或上下滑动换房';
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = friendlyMsg;
        });
      }
    }
  }

  /// 彻底清洗字符串中可能的孤立代理对与非法 Unicode 字符，杜绝黑底白问号菱形 
  String _cleanString(String input) {
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune == 0xFFFD) continue; // 剔除 Unicode 替换符
      if (rune < 32 && rune != 9 && rune != 10 && rune != 13) continue; // 剔除控制字符
      buffer.writeCharCode(rune);
    }
    final res = buffer.toString().trim();
    return res.isEmpty ? input.trim() : res;
  }

  /// 安全提取当前主播昵称（绝对不会斩断 UTF-16 代理对）
  String _getCurrentUserNick() {
    if (widget.streamList != null &&
        widget.streamList!.isNotEmpty &&
        _currentChannelIndex >= 0 &&
        _currentChannelIndex < widget.streamList!.length) {
      final s = widget.streamList![_currentChannelIndex];
      if (s.userNick.trim().isNotEmpty) {
        return _cleanString(s.userNick.trim());
      }
      if (s.userId.trim().isNotEmpty) {
        return _cleanString(s.userId.trim());
      }
    }

    var t = _currentTitle.trim();
    // 使用正规字符串替换，严禁使用 substring(1) 砍断红圆 emoji
    t = t.replaceAll(RegExp(r'^[🔴\s]+'), '');
    t = t.replaceAll(RegExp(r'^\[(PandaTV|FlexTV)\]\s*'), '');
    if (t.contains(' - ')) {
      final parts = t.split(' - ');
      if (parts.first.trim().isNotEmpty) {
        return _cleanString(parts.first.trim());
      }
    }
    return t.isEmpty ? '韩国主播' : _cleanString(t);
  }

  /// 安全提取当前直播房间标题
  String _getCurrentRoomTitle() {
    if (widget.streamList != null &&
        widget.streamList!.isNotEmpty &&
        _currentChannelIndex >= 0 &&
        _currentChannelIndex < widget.streamList!.length) {
      final s = widget.streamList![_currentChannelIndex];
      if (s.title.trim().isNotEmpty) {
        return _cleanString(s.title.trim());
      }
    }

    var t = _currentTitle.trim();
    t = t.replaceAll(RegExp(r'^[🔴\s]+'), '');
    t = t.replaceAll(RegExp(r'^\[(PandaTV|FlexTV)\]\s*'), '');
    if (t.contains(' - ')) {
      final parts = t.split(' - ');
      if (parts.length > 1 && parts.sublist(1).join(' - ').trim().isNotEmpty) {
        return _cleanString(parts.sublist(1).join(' - ').trim());
      }
    }
    return '1080P 60FPS 超清原画现场';
  }

  String _getCompactRouteSpeed() {
    final active = ProxyRouteService.getActiveRoute(fallbackOffset: _proxyIndex);
    if (active.downloadSpeedKBps > 0) {
      return active.speedText;
    }
    if (ProxyRouteService.selectedRouteId == 'auto') {
      return '优选';
    }
    return active.name.split(' ').first;
  }

  String _getPlatformTag() {
    final url = _currentRawUrl.toLowerCase();
    final t = _currentTitle.toLowerCase();
    if (url.contains('panda') || t.contains('panda')) return 'PandaTV';
    if (url.contains('flex') || t.contains('flex')) return 'FlexTV';
    if (url.contains('.m3u8')) return 'HLS 极速流';
    return '直播现场';
  }

  void _showSwitchedSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.alt_route_rounded, color: Colors.amberAccent, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1E2235),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showRouteSelectionModal() {
    RouteSelectionModal.show(
      context,
      testStreamUrl: _actualPlayUrl.isNotEmpty ? _actualPlayUrl : null,
      onRouteChanged: () {
        setState(() {
          _proxyIndex = 0;
          _manualRetryCount = 0;
        });
        _initializePlayer();
      },
      onShowMessage: (msg) => _showSwitchedSnackBar(msg),
    );
  }

  /// 弹出类似短剧选集的精美半屏直播频道抽屉
  void _showChannelDrawer() {
    final list = widget.streamList;
    if (list == null || list.isEmpty) {
      _showSwitchedSnackBar('当前为单频道模式，无频道列表');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.68,
          decoration: const BoxDecoration(
            color: Color(0xFF141724),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.live_tv_rounded, color: Color(0xFFFF2E63), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '直播频道 (${_currentChannelIndex + 1}/${list.length})',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final s = list[index];
                    final isCurrent = index == _currentChannelIndex;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (index != _currentChannelIndex) {
                          _changeChannel(index);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isCurrent ? const Color(0xFFFF2E63).withOpacity(0.18) : const Color(0xFF1B1E2D),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent ? const Color(0xFFFF2E63) : Colors.white.withOpacity(0.06),
                            width: isCurrent ? 1.2 : 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 26,
                              child: isCurrent
                                  ? const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFFF2E63), size: 18)
                                  : Text(
                                      '${index + 1}',
                                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                            ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: isCurrent ? const Color(0xFFFF2E63) : const Color(0xFF262B3F),
                              child: Text(
                                s.userNick.isNotEmpty ? s.userNick[0].toUpperCase() : 'P',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _cleanString(s.userNick),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isCurrent ? const Color(0xFFFF2E63) : Colors.white,
                                            fontSize: 13,
                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          s.platform == 'pandatv' ? 'Panda' : 'Flex',
                                          style: const TextStyle(color: Colors.white60, fontSize: 9),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _cleanString(s.title),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (s.viewers > 0) ...[
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF5252), size: 12),
                                  const SizedBox(width: 2),
                                  Text(
                                    s.viewers >= 10000
                                        ? '${(s.viewers / 10000).toStringAsFixed(1)}w'
                                        : '${s.viewers}',
                                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ],
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
  }

  Widget _buildErrorCard(String errorMsg) {
    String friendly = errorMsg;
    if (errorMsg.contains('Source error') || errorMsg.contains('403') || errorMsg.contains('404')) {
      friendly = '主播当前信号暂时离线（可能已下播或房间关闭）';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 52),
            const SizedBox(height: 14),
            Text(
              friendly,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _manualRetryCount = 0;
                  if (ProxyRouteService.selectedRouteId == 'auto') {
                    _proxyIndex++;
                  }
                });
                _initializePlayer();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2E63),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: Text(
                ProxyRouteService.selectedRouteId == 'auto'
                    ? '重试播放 (自动轮换下一线路)'
                    : '重试当前选定线路',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showRouteSelectionModal,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amberAccent,
                side: const BorderSide(color: Colors.amberAccent, width: 0.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              icon: const Icon(Icons.alt_route_rounded, size: 16),
              label: const Text('手动选择测速线路', style: TextStyle(fontSize: 12)),
            ),
            if (widget.streamList != null && widget.streamList!.length > 1) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: _switchToNextChannel,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.skip_next_rounded, color: Color(0xFFFF2E63), size: 18),
                      SizedBox(width: 6),
                      Text(
                        '上下滑动或点击切换下一个直播间',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 1. 顶部悬浮毛玻璃胶囊导航条
  Widget _buildTopCapsuleBar() {
    final viewersCount = _currentViewers ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.48),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (_isLandscape(context)) {
                // 爱奇艺标准交互：横屏全屏模式下点击左上角返回，退出全屏并恢复为竖屏
                _exitFullScreen();
              } else {
                // 竖屏常规模式下点击返回，彻底释放资源并退出播放器
                _onPlayerExit();
                Navigator.of(context).pop();
              }
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 14),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2E63).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFFFF2E63).withOpacity(0.6), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF2E63),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Color(0xFFFF2E63),
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Text(
                        _getCurrentUserNick(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _getCurrentRoomTitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 9.5),
                ),
              ],
            ),
          ),
          // 测速小胶囊
          InkWell(
            onTap: _showRouteSelectionModal,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flash_on_rounded, color: Colors.amberAccent, size: 12),
                  const SizedBox(width: 2),
                  Text(
                    _getCompactRouteSpeed(),
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 13),
                ],
              ),
            ),
          ),
          if (viewersCount > 0) ...[
            const SizedBox(width: 5),
            Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF5252), size: 12),
                  const SizedBox(width: 2),
                  Text(
                    viewersCount >= 10000
                        ? '${(viewersCount / 10000).toStringAsFixed(1)}w'
                        : '$viewersCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 2. 右下角极简纯白【全屏 / 退出全屏】控制按钮（轻触屏幕才显示，平时零遮挡）
  Widget _buildFullScreenBtn(bool isLandscape) {
    return GestureDetector(
      onTap: _toggleFullScreen,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.48),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(
          isLandscape ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  /// 3. 左下角主播微信息浮层（沉浸式无底栏）
  Widget _buildBottomLeftInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 平台渐变微胶囊
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFE94057).withOpacity(0.4), blurRadius: 6),
                ],
              ),
              child: Text(
                _getPlatformTag(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E676),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '超清原画',
                    style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 主播名字（大号粗体白字，带优雅暗影）
        Text(
          _getCurrentUserNick(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
        const SizedBox(height: 4),
        // 房间标题（优雅半透明浅白文字）
        Text(
          _getCurrentRoomTitle(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 12,
            height: 1.3,
            shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
          ),
        ),
        const SizedBox(height: 6),
        // 极简上下滑手势轻量微提示
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert_rounded, color: Colors.white.withOpacity(0.5), size: 12),
            const SizedBox(width: 3),
            Text(
              '上下滑换房 · 边缘调光调音',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = _isLandscape(context);
    return PopScope(
      canPop: !isLandscape,
      onPopInvoked: (didPop) {
        if (didPop) {
          _onPlayerExit();
          return;
        }
        if (isLandscape) {
          // 爱奇艺标准交互：横屏全屏时按手机系统物理返回键或返回手势，优先退出全屏回到竖屏
          _exitFullScreen();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. 核心播放器主体（Transform.scale 配合全屏居中沉浸）
            _isLoading
                ? const Center(
                    child: SpinKitFadingCircle(color: Color(0xFFFF2E63), size: 48),
                  )
                : _hasError
                    ? _buildErrorCard(_errorMessage)
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: AnimatedScale(
                              scale: _isCoverFit
                                  ? (isLandscape ? 1.25 : 1.38)
                                  : 1.0,
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              child: Chewie(
                                key: ValueKey('chewie_${_currentChannelIndex}_$_actualPlayUrl'),
                                controller: _chewieController!,
                              ),
                            ),
                          ),
                          // 竖屏/横屏高敏手势控光控音 + 上下滑切台手势 + 单击切换控制层显隐
                          Positioned.fill(
                            child: PlayerGestureOverlay(
                              onTap: _toggleControls,
                              onNextChannel: _switchToNextChannel,
                              onPrevChannel: _switchToPrevChannel,
                              onDoubleTap: _toggleScreenFit,
                            ),
                          ),
                        ],
                      ),

            // 2. 顶部悬浮胶囊导航栏（可平滑淡出，实现 100% 无遮挡纯净全屏）
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12 + MediaQuery.of(context).padding.left,
              right: 12 + MediaQuery.of(context).padding.right,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: _buildTopCapsuleBar(),
                ),
              ),
            ),

            // 3. 右下角极简【全屏 / 退出全屏】悬浮纽（爱奇艺式双向切换，轻触屏幕任意位置唤醒）
            Positioned(
              right: 16 + MediaQuery.of(context).padding.right,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: _buildFullScreenBtn(isLandscape),
                ),
              ),
            ),

            // 4. 左下角主播微信息浮层（可平滑淡出，彻底告别文字糊脸遮挡）
            Positioned(
              left: 14,
              right: 70,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: _buildBottomLeftInfo(),
                ),
              ),
            ),

            // 5. 抖音式秒切台微气泡
            if (_showChannelToast)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFFF2E63).withOpacity(0.6), width: 1.2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 16),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_vert_rounded, color: Color(0xFFFF2E63), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _channelToastMsg,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
