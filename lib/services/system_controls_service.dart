import 'package:flutter/services.dart';

class SystemControlsService {
  static const MethodChannel _channel = MethodChannel('com.jinri.pureapp/system_controls');

  /// 保持屏幕常亮（防止视频/短剧/直播播放中自动息屏黑屏）
  static Future<void> setKeepScreenOn(bool keepOn) async {
    try {
      await _channel.invokeMethod('setKeepScreenOn', {'keepOn': keepOn});
    } catch (_) {}
  }

  /// 设置系统级全局屏幕背光亮度 (0.01 ~ 1.0)
  static Future<void> setBrightness(double brightness) async {
    try {
      await _channel.invokeMethod('setBrightness', {'brightness': brightness.clamp(0.01, 1.0)});
    } catch (_) {}
  }

  /// 还原屏幕背光亮度至系统默认（清除 App 窗口亮度强制覆盖，恢复手机原亮度及自动感光）
  static Future<void> resetBrightness() async {
    try {
      await _channel.invokeMethod('resetBrightness');
    } catch (_) {}
  }

  /// 获取当前屏幕亮度
  static Future<double> getBrightness() async {
    try {
      final res = await _channel.invokeMethod<double>('getBrightness');
      return res ?? 0.5;
    } catch (_) {
      return 0.5;
    }
  }

  /// 设置系统级媒体音量 (0.0 ~ 1.0)
  static Future<void> setVolume(double volume) async {
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume.clamp(0.0, 1.0)});
    } catch (_) {}
  }

  /// 获取当前系统媒体音量
  static Future<double> getVolume() async {
    try {
      final res = await _channel.invokeMethod<double>('getVolume');
      return res ?? 0.8;
    } catch (_) {
      return 0.8;
    }
  }
}
