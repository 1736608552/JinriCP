import 'dart:async';
import 'package:flutter/material.dart';
import '../services/system_controls_service.dart';

class PlayerGestureOverlay extends StatefulWidget {
  final VoidCallback? onNextChannel;
  final VoidCallback? onPrevChannel;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onTap;

  const PlayerGestureOverlay({
    super.key,
    this.onNextChannel,
    this.onPrevChannel,
    this.onDoubleTap,
    this.onTap,
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
    // 爱奇艺同款柔顺阻尼：整屏高度滑动对应 0%~100%，手感平滑细腻
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
    // 爱奇艺同款柔顺阻尼：整屏高度滑动对应 0%~100%，手感平滑细腻
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
            // 👈 左侧 22% 边缘手势监听（上下滑动 -> 调亮度，单击唤醒/隐藏控制层）
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: edgeWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.onTap,
                onVerticalDragStart: (details) async {
                  // 滑动开始瞬间实时采样手机当前系统背光作为基准，避免突变
                  final b = await SystemControlsService.getBrightness();
                  if (mounted) _brightness = b;
                },
                onVerticalDragUpdate: (details) => _onBrightnessDrag(details, screenHeight),
              ),
            ),

            // 👉 右侧 22% 边缘手势监听（上下滑动 -> 调系统媒体音量，单击唤醒/隐藏控制层）
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: edgeWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.onTap,
                onVerticalDragStart: (details) async {
                  // 滑动开始瞬间实时采样当前媒体音量作为基准，避免突变
                  final v = await SystemControlsService.getVolume();
                  if (mounted) _volume = v;
                },
                onVerticalDragUpdate: (details) => _onVolumeDrag(details, screenHeight),
              ),
            ),

            // 📱 中间 56% 核心区域手势监听（类似抖音上下滑动切台，双击切换画面铺满）
            Positioned(
              top: 0,
              bottom: 0,
              left: edgeWidth,
              width: centerWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.onTap,
                onDoubleTap: widget.onDoubleTap,
                onVerticalDragStart: (details) {
                  _dragStartY = details.localPosition.dy;
                  _channelDragTriggered = false;
                },
                onVerticalDragUpdate: (details) {
                  if (_channelDragTriggered) return;
                  final deltaY = details.localPosition.dy - _dragStartY;
                  if (deltaY < -50) {
                    _channelDragTriggered = true;
                    widget.onNextChannel?.call();
                  } else if (deltaY > 50) {
                    _channelDragTriggered = true;
                    widget.onPrevChannel?.call();
                  }
                },
                onVerticalDragEnd: (details) {
                  _channelDragTriggered = false;
                },
              ),
            ),

            // ☀️ 播放器亮度 HUD 浮层提示（爱奇艺极简纯白质感）
            if (_showBrightnessHUD)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _brightness > 0.6
                            ? Icons.brightness_7_rounded
                            : _brightness > 0.3
                                ? Icons.brightness_6_rounded
                                : Icons.brightness_4_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('亮度', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(
                            '${(_brightness * 100).toInt()}%',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 70,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _brightness,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                            minHeight: 5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 🔊 播放器音量 HUD 浮层提示（爱奇艺极简纯白质感）
            if (_showVolumeHUD)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _volume > 0.6
                            ? Icons.volume_up_rounded
                            : _volume > 0.01
                                ? Icons.volume_down_rounded
                                : Icons.volume_mute_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('音量', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(
                            '${(_volume * 100).toInt()}%',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 70,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _volume,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                            minHeight: 5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
