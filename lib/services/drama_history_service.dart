import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/drama_history.dart';
import '../models/short_drama.dart';
import 'drama_service.dart';

class DramaHistoryService {
  static const String _keyDramaHistory = 'short_drama_history_v1';
  static List<DramaHistoryItem>? _cachedHistory;

  /// 🌟 历史短剧最新更新数量通知器（用于底部导航栏与顶栏 Badge 实时高亮）
  static final ValueNotifier<int> updateCountNotifier = ValueNotifier<int>(0);

  /// 加载所有短剧观看历史记录（按最新观看时间倒序）
  static Future<List<DramaHistoryItem>> getHistoryList() async {
    if (_cachedHistory != null) return _cachedHistory!;
    final prefs = await SharedPreferences.getInstance();
    final jsonListStr = prefs.getStringList(_keyDramaHistory) ?? [];

    _cachedHistory = jsonListStr
        .map((str) {
          try {
            return DramaHistoryItem.fromJson(jsonDecode(str) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<DramaHistoryItem>()
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    _refreshUpdateCount();
    return _cachedHistory!;
  }

  /// 刷新未读更新数（只有总集数确实增加的剧集才计入更新数）
  static void _refreshUpdateCount() {
    if (_cachedHistory == null) return;
    final count = _cachedHistory!.where((item) => item.hasNewEpisodes).length;
    updateCountNotifier.value = count;
  }

  /// 获取单个短剧的历史进度
  static Future<DramaHistoryItem?> getDramaHistory(String dramaId) async {
    final list = await getHistoryList();
    try {
      return list.firstWhere((item) => item.dramaId == dramaId);
    } catch (_) {
      return null;
    }
  }

  /// 保存/更新短剧观看历史与集数进度
  static Future<void> saveHistory({
    required ShortDrama drama,
    required int episodeIndex,
    int positionMs = 0,
    int durationMs = 0,
  }) async {
    if (drama.id.isEmpty) return;

    final list = await getHistoryList();
    DramaHistoryItem? existing;
    try {
      existing = list.firstWhere((item) => item.dramaId == drama.id);
    } catch (_) {}

    list.removeWhere((item) => item.dramaId == drama.id);

    int totalEps = drama.totalEpisodes > 0
        ? drama.totalEpisodes
        : (drama.episodes.isNotEmpty ? drama.episodes.length : (episodeIndex + 1));

    // 如果之前已知总集数更大，以最大已知集数为基准
    if (existing != null && existing.totalEpisodes > totalEps) {
      totalEps = existing.totalEpisodes;
    }

    final newItem = DramaHistoryItem(
      dramaId: drama.id,
      title: drama.title,
      coverUrl: drama.coverUrl,
      category: drama.category,
      totalEpisodes: totalEps,
      lastEpisodeIndex: episodeIndex,
      lastEpisodeNum: episodeIndex + 1,
      positionMs: positionMs,
      durationMs: durationMs,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      latestTotalEpisodes: totalEps, // 用户已看/同步，重置更新基准
      lastNotifiedEpisode: existing?.lastNotifiedEpisode,
    );

    list.insert(0, newItem);

    if (list.length > 100) {
      list.removeRange(100, list.length);
    }

    _cachedHistory = list;
    _refreshUpdateCount();

    final prefs = await SharedPreferences.getInstance();
    final jsonListStr = list.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_keyDramaHistory, jsonListStr);
  }

  /// 🌟 智能检测追剧更新：并发探测历史短剧最新集数
  /// 只有当服务端最新总集数 remoteTotal > 之前记录的 totalEpisodes 时，才判定为影片更新！
  static Future<List<DramaHistoryItem>> checkForUpdates() async {
    final history = await getHistoryList();
    if (history.isEmpty) return [];

    final List<DramaHistoryItem> newlyUpdated = [];
    bool hasAnyChange = false;

    // 针对最近观看的 15 部短剧并发检查更新
    final checkTargets = history.take(15).toList();

    await Future.wait(
      checkTargets.map((item) async {
        try {
          final detail = await DramaService.fetchDramaDetail(item.toShortDrama())
              .timeout(const Duration(seconds: 4));

          final remoteTotal = detail.totalEpisodes > 0
              ? detail.totalEpisodes
              : detail.episodes.length;

          // 🌟 核心修正：仅当远端总集数真正超过原本保存的总集数时，才属于影片更新！
          // 例如原本 33 集（即使只看到第 30 集，仍不算更新），当远端变成 34 集时才算更新！
          if (remoteTotal > item.totalEpisodes) {
            final updatedItem = item.copyWith(
              latestTotalEpisodes: remoteTotal,
            );

            final idx = history.indexWhere((h) => h.dramaId == item.dramaId);
            if (idx != -1) {
              history[idx] = updatedItem;
              hasAnyChange = true;
            }

            // 判断是否是未曾提醒过的新集数
            if (item.lastNotifiedEpisode == null || remoteTotal > item.lastNotifiedEpisode!) {
              newlyUpdated.add(updatedItem);
            }
          }
        } catch (_) {}
      }),
    );

    if (hasAnyChange) {
      _cachedHistory = history;
      _refreshUpdateCount();

      final prefs = await SharedPreferences.getInstance();
      final jsonListStr = history.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_keyDramaHistory, jsonListStr);
    }

    return newlyUpdated;
  }

  /// 标记某部短剧已提示更新
  static Future<void> markAsNotified(String dramaId, int episodeNum) async {
    final history = await getHistoryList();
    final idx = history.indexWhere((h) => h.dramaId == dramaId);
    if (idx != -1) {
      history[idx] = history[idx].copyWith(lastNotifiedEpisode: episodeNum);
      _cachedHistory = history;
      _refreshUpdateCount();

      final prefs = await SharedPreferences.getInstance();
      final jsonListStr = history.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_keyDramaHistory, jsonListStr);
    }
  }

  /// 删除单条历史记录
  static Future<void> deleteHistory(String dramaId) async {
    final list = await getHistoryList();
    list.removeWhere((item) => item.dramaId == dramaId);
    _cachedHistory = list;
    _refreshUpdateCount();

    final prefs = await SharedPreferences.getInstance();
    final jsonListStr = list.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_keyDramaHistory, jsonListStr);
  }

  /// 清空所有观看历史
  static Future<void> clearAllHistory() async {
    _cachedHistory = [];
    _refreshUpdateCount();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDramaHistory);
  }
}
