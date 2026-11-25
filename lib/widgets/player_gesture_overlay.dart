import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/system_controls_service.dart';
import '../services/theme_service.dart';

class PlayerGestureOverlay extends StatefulWidget {
  final VoidCallback? onNextChannel;
  final VoidCallback? onPrevChannel;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onTap;

  /// 是否处于锁屏防误触状态
  final bool isLocked;

  /// 横向滑动 Seek 支持（点播/短剧）
  final Duration? currentPosition;
  final Duration? totalDuration;
  final ValueChanged<Duration>? onSeekTo;

  /// 长按 2.0x 倍速支持
  final VoidCallback? onLongPressSpeedStart;
  final VoidCallback? onLongPressSpeedEnd;

  const PlayerGestureOverlay({
    super.key,
    this.onNextChannel,
    this.onPrevChannel,
    this.onDoubleTap,
    this.onTap,
    this.isLocked = false,
    this.currentPosition,
    this.totalDuration,
    this.onSeekTo,
    this.onLongPressSpeedStart,
    this.onLongPressSpeedEnd,
  });

  @override
  State<PlayerGestureOverlay> createState() => _PlayerGestureOverlayState();
}

class _PlayerGestureOverlayState extends State<PlayerGestureOverlay> {
  double _brightness = 0.6;
  bool _showBrightnessHUD = false;
  Timer? _brightnessHUDTimer;

  double _volume = 0.8;
  bool _showVolumeHUD = false;
  Timer? _volumeHUDTimer;

  double _dragStartY = 0.0;
  bool _channelDragTriggered = false;

  // 横向 Seek 状态
  bool _isSeeking = false;
  Duration _seekStartPos = Duration.zero;
  Duration _seekTargetPos = Duration.zero;

  // 长按倍速状态
  bool _isLongPressSpeed = false;

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  Future<void> _initValues() async {
    final b = await SystemControlsService.getBrightness();
    final v = await SystemControlsService.getVolume();
    if (mounted) {
      setState(() {
        _brightness = b;
        _volume = v;
      });
    }
  }

  @override
  void dispose() {
    _brightnessHUDTimer?.cancel();
    _volumeHUDTimer?.cancel();
    SystemControlsService.resetBrightness();
    super.dispose();
  }

  void _onBrightnessDrag(DragUpdateDetails details, double screenHeight) {
    if (widget.isLocked) return;
    final delta = -details.delta.dy / (screenHeight * 0.9);
    final newBrightness = (_brightness + delta).clamp(0.01, 1.0);

    setState(() {
      _brightness = newBrightness;
      _showBrightnessHUD = true;
      _showVolumeHUD = false;
    });

    SystemControlsService.setBrightness(newBrightness);

    _brightnessHUDTimer?.cancel();
    _brightnessHUDTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _showBrightnessHUD = false);
    });
  }

  void _onVolumeDrag(DragUpdateDetails details, double screenHeight) {
    if (widget.isLocked) return;
    final delta = -details.delta.dy / (screenHeight * 0.9);
    final newVolume = (_volume + delta).clamp(0.0, 1.0);

    setState(() {
      _volume = newVolume;
      _showVolumeHUD = true;
      _showBrightnessHUD = false;
    });

    SystemControlsService.setVolume(newVolume);

    _volumeHUDTimer?.cancel();
    _volumeHUDTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _showVolumeHUD = false);
    });
  }

  bool get _canSeek =>
      !widget.isLocked &&
      widget.onSeekTo != null &&
      widget.currentPosition != null &&
      widget.totalDuration != null &&
      widget.totalDuration!.inMilliseconds > 0;

  void _onHorizontalDragStart(DragStartDetails details) {
    if (!_canSeek) return;
    setState(() {
      _isSeeking = true;
      _seekStartPos = widget.currentPosition!;
      _seekTargetPos = widget.currentPosition!;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double screenWidth) {
    if (!_isSeeking || !_canSeek) return;
    final totalMs = widget.totalDuration!.inMilliseconds;
    // 整屏横向滑动对应 90 秒或总时长的 60%（取较小值，保证长短片手感都跟手）
    final maxSeekSpanMs = (totalMs * 0.6).clamp(15000.0, 90000.0);
    final deltaMs = (details.delta.dx / screenWidth) * maxSeekSpanMs;
    final nextMs = (_seekTargetPos.inMilliseconds + deltaMs).round().clamp(0, totalMs);
    setState(() {
      _seekTargetPos = Duration(milliseconds: nextMs);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isSeeking) return;
    final target = _seekTargetPos;
    setState(() {
      _isSeeking = false;
    });
    widget.onSeekTo?.call(target);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        final edgeWidth = screenWidth * 0.22;
        final centerWidth = screenWidth - (edgeWidth * 2);

        return Stack(
          fit: StackFit.expand,
          children: [
            // 👈 左侧 22% 边缘手势监听（上下滑动 -> 调亮度）
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: edgeWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.onTap,
                onVerticalDragStart: (details) async {
                  if (widget.isLocked) return;
                  final b = await SystemControlsService.getBrightness();
                  if (mounted) _brightness = b;
                },
                onVerticalDragUpdate: (details) => _onBrightnessDrag(details, screenHeight),
              ),
            ),

            // 👉 右侧 22% 边缘手势监听（上下滑动 -> 调音量）
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: edgeWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.onTap,
                onVerticalDragStart: (details) async {
                  if (widget.isLocked) return;
                  final v = await SystemControlsService.getVolume();
                  if (mounted) _volume = v;
                },
                onVerticalDragUpdate: (details) => _onVolumeDrag(details, screenHeight),
              ),
            ),

            // 📱 中间 56% 核心区域手势监听（单击、双击、上下滑切台、横向 Seek、长按 2x 倍速）
            Positioned(
              top: 0,
              bottom: 0,
              left: edgeWidth,
              width: centerWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.onTap,
                onDoubleTap: widget.isLocked ? null : widget.onDoubleTap,
                onLongPressStart: (!widget.isLocked && widget.onLongPressSpeedStart != null)
                    ? (_) {
                        HapticFeedback.mediumImpact();
                        setState(() => _isLongPressSpeed = true);
                        widget.onLongPressSpeedStart?.call();
                      }
                    : null,
                onLongPressEnd: (!widget.isLocked && widget.onLongPressSpeedEnd != null)
                    ? (_) {
                        if (_isLongPressSpeed) {
                          setState(() => _isLongPressSpeed = false);
                          widget.onLongPressSpeedEnd?.call();
                        }
                      }
                    : null,
                onVerticalDragStart: (details) {
                  if (widget.isLocked) return;
                  _dragStartY = details.localPosition.dy;
                  _channelDragTriggered = false;
                },
                onVerticalDragUpdate: (details) {
                  if (widget.isLocked || _channelDragTriggered) return;
                  final deltaY = details.localPosition.dy - _dragStartY;
                  if (deltaY < -50) {
                    _channelDragTriggered = true;
                    HapticFeedback.selectionClick();
                    widget.onNextChannel?.call();
                  } else if (deltaY > 50) {
                    _channelDragTriggered = true;
                    HapticFeedback.selectionClick();
                    widget.onPrevChannel?.call();
                  }
                },
                onVerticalDragEnd: (_) {
                  _channelDragTriggered = false;
                },
                onHorizontalDragStart: _onHorizontalDragStart,
                onHorizontalDragUpdate: (details) => _onHorizontalDragUpdate(details, screenWidth),
                onHorizontalDragEnd: _onHorizontalDragEnd,
              ),
            ),

            // ☀️ 亮度毛玻璃 HUD
            if (_showBrightnessHUD)
              Center(
                child: _buildGlassSliderHUD(
                  icon: _brightness > 0.6
                      ? Icons.brightness_7_rounded
                      : _brightness > 0.3
                          ? Icons.brightness_6_rounded
                          : Icons.brightness_4_rounded,
                  label: '亮度',
                  valueText: '${(_brightness * 100).toInt()}%',
                  progress: _brightness,
                  accentColor: AppTheme.amberGold,
                ),
              ),

            // 🔊 音量毛玻璃 HUD
            if (_showVolumeHUD)
              Center(
                child: _buildGlassSliderHUD(
                  icon: _volume > 0.6
                      ? Icons.volume_up_rounded
                      : _volume > 0.01
                          ? Icons.volume_down_rounded
                          : Icons.volume_off_rounded,
                  label: '音量',
                  valueText: '${(_volume * 100).toInt()}%',
                  progress: _volume,
                  accentColor: AppTheme.electricCyan,
                ),
              ),

            // ⏩ 横向滑动 Seek 预览 HUD
            if (_isSeeking && widget.totalDuration != null)
              Center(
                child: _buildGlassSeekHUD(),
              ),

            // ⚡ 长按 2.0x 倍速播放顶部胶囊提示
            if (_isLongPressSpeed)
              Positioned(
                top: MediaQuery.of(context).padding.top + 56,
                left: 0,
                right: 0,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: AppTheme.playerGlassDecoration(
                          radius: 20,
                          borderColor: AppTheme.primaryPink.withOpacity(0.5),
                          bgOpacity: 0.65,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fast_forward_rounded, color: AppTheme.primaryPink, size: 18),
                            SizedBox(width: 6),
                            Text(
                              '2.0x 倍速快进中',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildGlassSliderHUD({
    required IconData icon,
    required String label,
    required String valueText,
    required double progress,
    required Color accentColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: AppTheme.playerGlassDecoration(radius: 20, bgOpacity: 0.65),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accentColor, size: 24),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  Text(
                    valueText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 76,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withOpacity(0.18),
                    valueColor: AlwaysStoppedAnimation(accentColor),
                    minHeight: 5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassSeekHUD() {
    final diffSec = (_seekTargetPos - _seekStartPos).inSeconds;
    final diffText = diffSec >= 0 ? '+${diffSec}s' : '${diffSec}s';
    final progress = widget.totalDuration!.inMilliseconds > 0
        ? _seekTargetPos.inMilliseconds / widget.totalDuration!.inMilliseconds
        : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: AppTheme.playerGlassDecoration(radius: 20, bgOpacity: 0.72),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    diffSec >= 0 ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
                    color: AppTheme.primaryPink,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatDuration(_seekTargetPos)} / ${_formatDuration(widget.totalDuration!)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPink.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      diffText,
                      style: const TextStyle(
                        color: AppTheme.accentPink,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withOpacity(0.18),
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primaryPink),
                    minHeight: 4,
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
