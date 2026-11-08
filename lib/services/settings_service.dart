import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyIps = 'custom_preferred_ips';
  static const String _keyNvidiaKey = 'custom_nvidia_key';
  static const String _keyNvidiaModel = 'custom_nvidia_model';
  static const String _keyDomain = 'custom_domain';
  static const String _keyDomains = 'custom_domains_list';
  static const String _keyDramaBaseUrl = 'custom_drama_base_url';
  static const String _keyDramaSourceType = 'custom_drama_source_type';
  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyOptIpEnabled = 'cloudflare_opt_ip_enabled';

  static const List<String> defaultIps = [
    '104.25.159.15',
    '104.21.245.19',
    '104.25.153.116',
    '104.22.154.72',
    '104.27.113.101',
    '104.20.92.26',
    '172.66.176.109',
    '172.68.21.106',
    '190.93.253.77',
    '104.19.180.144',
    '104.19.235.252',
    '104.19.112.17',
    '104.16.40.124',
    '104.17.166.57',
    '104.18.82.153',
  ];

  static const String defaultNvidiaKey =
      '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';
  static const String defaultNvidiaModel = 'deepseek-ai/deepseek-v4-flash-0731';

  // 🌟 短剧双源常量与预设地址
  static const String sourceHuangguo = 'huangguo';   // 源1：黄果短剧
  static const String sourceHgdju = 'hgdju';         // 源2：黄瓜短剧

  static const String _keySelectedDramaSource = 'custom_selected_drama_source';
  static const String _keyDramaUrlHuangguo = 'drama_url_huangguo';
  static const String _keyDramaUrlHgdju = 'drama_url_hgdju';

  static const String dramaSourceClassic = 'classic'; // 套系一：经典黄果短剧
  static const String dramaSourceHgdju = 'hgdju';     // 套系二：黄瓜短剧 (/browse 体系)
  static const String defaultHgdjuUrl = 'https://xyz.zgoqmlyp.cc';
  static const String defaultClassicUrl = 'https://huangguoai.ai';
  static const List<String> defaultClassicUrls = [
    'https://huangguoai.ai',
    'https://huangguoai.com',
    'https://hgai2.com',
    'https://huangguo8.com',
    'https://huangguo4.com',
    'https://huangguo2.com',
  ];

  static const String defaultDomain = 'https://zb.djseven.cc.cd';
  static const List<String> defaultDomains = [
    'https://zb.djseven.cc.cd',
  ];

  /// 当前选中的短剧源标识通知器（huangguo / hgdju）
  static final ValueNotifier<String> selectedDramaSourceNotifier = ValueNotifier<String>(sourceHuangguo);

  /// 短剧源地址通知器（支持跨组件即时响应与栏目显隐）
  static final ValueNotifier<String> dramaBaseUrlNotifier = ValueNotifier<String>('');

  /// 短剧源类型通知器（classic / hgdju）
  static final ValueNotifier<String> dramaSourceTypeNotifier = ValueNotifier<String>(dramaSourceClassic);

  /// 🌟 全局主题模式通知器：默认白天白色模式 (ThemeMode.light)
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

  /// ⚡ 优选 IP 启用状态通知器（默认开启 true）
  static final ValueNotifier<bool> optIpEnabledNotifier = ValueNotifier<bool>(true);

  static Future<void> initSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    var huangguoUrl = prefs.getString(_keyDramaUrlHuangguo) ?? '';
    var hgdjuUrl = prefs.getString(_keyDramaUrlHgdju) ?? '';
    var selectedSource = prefs.getString(_keySelectedDramaSource) ?? sourceHuangguo;

    // 智能自愈升级：如果黄瓜短剧保存的是发布页、失效旧线路或为空，自动升级为当前直连真实可用主线路
    if (hgdjuUrl.isEmpty ||
        hgdjuUrl.contains('hgdju1.com') ||
        hgdjuUrl.contains('hgdju.com') ||
        hgdjuUrl.contains('hgdj.ai') ||
        hgdjuUrl.contains('wuscaznx')) {
      hgdjuUrl = defaultHgdjuUrl;
      await prefs.setString(_keyDramaUrlHgdju, hgdjuUrl);
    }

    // 智能数据平滑迁移：若新独立key为空，但历史存有全局地址，自动归类迁移
    final oldUrl = prefs.getString(_keyDramaBaseUrl) ?? '';
    if (huangguoUrl.isEmpty && oldUrl.isNotEmpty) {
      if (detectDramaSourceType(oldUrl) != dramaSourceHgdju) {
        huangguoUrl = oldUrl;
        await prefs.setString(_keyDramaUrlHuangguo, huangguoUrl);
      }
    }
    if (huangguoUrl.isEmpty) {
      huangguoUrl = defaultClassicUrl;
      await prefs.setString(_keyDramaUrlHuangguo, huangguoUrl);
    }

    selectedDramaSourceNotifier.value = selectedSource;

    // 根据当前选中的短剧源，激活对应的 BaseUrl 与 SourceType
    final activeUrl = selectedSource == sourceHgdju ? hgdjuUrl : huangguoUrl;
    final activeType = selectedSource == sourceHgdju ? dramaSourceHgdju : dramaSourceClassic;

    dramaBaseUrlNotifier.value = activeUrl;
    dramaSourceTypeNotifier.value = activeType;
    await prefs.setString(_keyDramaBaseUrl, activeUrl);
    await prefs.setString(_keyDramaSourceType, activeType);

    optIpEnabledNotifier.value = prefs.getBool(_keyOptIpEnabled) ?? true;

    // 默认白天模式（白色）
    final savedTheme = prefs.getString(_keyThemeMode) ?? 'light';
    if (savedTheme == 'dark') {
      themeModeNotifier.value = ThemeMode.dark;
    } else if (savedTheme == 'system') {
      themeModeNotifier.value = ThemeMode.system;
    } else {
      themeModeNotifier.value = ThemeMode.light;
    }
  }

  static Future<bool> getOptIpEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOptIpEnabled) ?? true;
  }

  static Future<void> setOptIpEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOptIpEnabled, enabled);
    optIpEnabledNotifier.value = enabled;
  }

  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyThemeMode) ?? 'light';
    if (saved == 'dark') return ThemeMode.dark;
    if (saved == 'system') return ThemeMode.system;
    return ThemeMode.light;
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String val = 'light';
    if (mode == ThemeMode.dark) val = 'dark';
    if (mode == ThemeMode.system) val = 'system';
    await prefs.setString(_keyThemeMode, val);
    themeModeNotifier.value = mode;
  }

  static Future<List<String>> getPreferredIps() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyIps);
    if (list != null && list.isNotEmpty) return list;
    return List.from(defaultIps);
  }

  static Future<void> setPreferredIps(List<String> ips) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyIps, ips);
  }

  static Future<String> getNvidiaKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNvidiaKey) ?? defaultNvidiaKey;
  }

  static Future<void> setNvidiaKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNvidiaKey, key.trim());
  }

  static Future<String> getNvidiaModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNvidiaModel) ?? defaultNvidiaModel;
  }

  static Future<void> setNvidiaModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNvidiaModel, model.trim());
  }

  /// 获取用户配置的所有专属节点域名列表
  static Future<List<String>> getCustomDomains() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyDomains);
    if (list != null && list.isNotEmpty) {
      final clean = list.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (clean.isNotEmpty) return clean;
    }
    // 兼容历史单一域名设置
    final oldDomain = prefs.getString(_keyDomain);
    if (oldDomain != null && oldDomain.trim().isNotEmpty) {
      final split = oldDomain
          .split(RegExp(r'[\n,;\s]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (split.isNotEmpty) return split;
    }
    return List.from(defaultDomains);
  }

  /// 批量保存专属节点域名列表
  static Future<void> setCustomDomains(List<String> domains) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanList = domains
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    await prefs.setStringList(_keyDomains, cleanList);
    if (cleanList.isNotEmpty) {
      await prefs.setString(_keyDomain, cleanList.first);
    }
  }

  /// 获取首选主域名 (兼容旧接口)
  static Future<String> getCustomDomain() async {
    final domains = await getCustomDomains();
    return domains.isNotEmpty ? domains.first : defaultDomain;
  }

  /// 设置自定义域名 (支持多行或单域名传入)
  static Future<void> setCustomDomain(String domain) async {
    final domains = domain
        .split(RegExp(r'[\n,;\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    await setCustomDomains(domains);
  }

  /// 智能识别短剧源类型：根据输入的地址特征判定是套系一（经典黄果短剧）还是套系二（黄瓜短剧）
  static String detectDramaSourceType(String url) {
    final lower = url.toLowerCase().trim();
    if (lower.contains('hgdju') ||
        lower.contains('/browse') ||
        lower.contains('hgd') ||
        lower.contains('huangguaduanju') ||
        lower.contains('zgoqmlyp') ||
        lower.contains('wuscaznx') ||
        lower.contains('porncz') ||
        lower.contains('mkqjue') ||
        lower.contains('rixgqa')) {
      return dramaSourceHgdju;
    }
    return dramaSourceClassic;
  }

  /// 获取指定短剧源已保存记忆的专属地址
  static Future<String> getDramaUrlForSource(String source) async {
    final prefs = await SharedPreferences.getInstance();
    if (source == sourceHgdju) {
      final saved = prefs.getString(_keyDramaUrlHgdju) ?? '';
      if (saved.isEmpty || saved.contains('wuscaznx')) {
        return defaultHgdjuUrl;
      }
      return saved;
    }
    final saved = prefs.getString(_keyDramaUrlHuangguo) ?? '';
    return saved.isNotEmpty ? saved : defaultClassicUrl;
  }

  /// 保存指定短剧源的专属地址并持久化记忆
  static Future<void> saveDramaUrlForSource(String source, String url) async {
    final prefs = await SharedPreferences.getInstance();
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    if (source == sourceHgdju) {
      await prefs.setString(_keyDramaUrlHgdju, cleanUrl);
    } else {
      await prefs.setString(_keyDramaUrlHuangguo, cleanUrl);
    }

    // 若当前选中的正是该源，立即同步更新当前生效地址
    if (selectedDramaSourceNotifier.value == source) {
      await prefs.setString(_keyDramaBaseUrl, cleanUrl);
      dramaBaseUrlNotifier.value = cleanUrl;
      final activeType = source == sourceHgdju ? dramaSourceHgdju : dramaSourceClassic;
      await prefs.setString(_keyDramaSourceType, activeType);
      dramaSourceTypeNotifier.value = activeType;
    }
  }

  /// 切换当前选中的短剧源（huangguo 或 hgdju）并立即激活记忆的地址
  static Future<void> switchDramaSource(String source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedDramaSource, source);
    selectedDramaSourceNotifier.value = source;

    // 提取该源保存的记忆地址
    final savedUrl = source == sourceHgdju
        ? (prefs.getString(_keyDramaUrlHgdju) ?? '')
        : (prefs.getString(_keyDramaUrlHuangguo) ?? '');

    final activeType = source == sourceHgdju ? dramaSourceHgdju : dramaSourceClassic;

    await prefs.setString(_keyDramaBaseUrl, savedUrl);
    await prefs.setString(_keyDramaSourceType, activeType);

    dramaBaseUrlNotifier.value = savedUrl;
    dramaSourceTypeNotifier.value = activeType;
  }

  /// 获取当前激活的短剧源套系（classic / hgdju）
  static Future<String> getDramaSourceType() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyDramaSourceType);
    if (saved != null && saved.isNotEmpty) {
      dramaSourceTypeNotifier.value = saved;
      return saved;
    }
    final url = await getDramaBaseUrl();
    final detected = detectDramaSourceType(url);
    dramaSourceTypeNotifier.value = detected;
    return detected;
  }

  /// 设置短剧源类型（手动切换）
  static Future<void> setDramaSourceType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDramaSourceType, type);
    dramaSourceTypeNotifier.value = type;
  }

  /// 获取当前激活的自定义短剧源地址
  static Future<String> getDramaBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_keyDramaBaseUrl) ?? '';
    dramaBaseUrlNotifier.value = url;
    return url;
  }

  /// 设置当前生效的短剧源地址并自动同步到对应记忆库
  static Future<void> setDramaBaseUrl(String url, {String? explicitType}) async {
    final prefs = await SharedPreferences.getInstance();
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    await prefs.setString(_keyDramaBaseUrl, cleanUrl);
    dramaBaseUrlNotifier.value = cleanUrl;

    // 智能识别或指定并激活对应的短剧源套系
    final type = explicitType ?? detectDramaSourceType(cleanUrl);
    await setDramaSourceType(type);

    // 同步到独立记忆库
    final sourceKey = type == dramaSourceHgdju ? sourceHgdju : sourceHuangguo;
    await saveDramaUrlForSource(sourceKey, cleanUrl);
    await prefs.setString(_keySelectedDramaSource, sourceKey);
    selectedDramaSourceNotifier.value = sourceKey;
  }
}
