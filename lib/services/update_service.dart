import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateInfo {
  final String tagName;
  final String title;
  final String releaseNotes;
  final String publishedAt;
  final String versionName;
  final int buildNumber;
  final int assetId;
  final String assetName;
  final int assetSize;
  final String downloadUrl;
  final String browserUrl;
  final bool hasNewVersion;

  UpdateInfo({
    required this.tagName,
    required this.title,
    required this.releaseNotes,
    required this.publishedAt,
    required this.versionName,
    required this.buildNumber,
    required this.assetId,
    required this.assetName,
    required this.assetSize,
    required this.downloadUrl,
    required this.browserUrl,
    required this.hasNewVersion,
  });

  String get sizeText {
    if (assetSize <= 0) return '';
    final mb = assetSize / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class UpdateService {
  static const String currentVersionName = '1.1.9';
  static const int currentBuildNumber = 110; // 本地当前构建编号

  static const String _defaultOwner = 'q52694787-hash';
  static const String _defaultRepo = 'jinricp-pure-app';
  static const String _defaultToken = '';

  static const MethodChannel _channel = MethodChannel('com.jinri.pureapp/system_controls');

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: true,
      maxRedirects: 5,
    ),
  );

  static Future<String> getGithubToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('custom_github_token') ?? _defaultToken;
  }

  static Future<void> setGithubToken(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('custom_github_token', token.trim());
  }

  /// 比较两个语义化版本号（如 "1.0.41" vs "1.0.37"），远程大则返回正数
  static int compareVersion(String remote, String local) {
    final rParts = remote.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final lParts = local.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final maxLen = rParts.length > lParts.length ? rParts.length : lParts.length;
    for (int i = 0; i < maxLen; i++) {
      final r = i < rParts.length ? rParts[i] : 0;
      final l = i < lParts.length ? lParts[i] : 0;
      if (r != l) return r.compareTo(l);
    }
    return 0;
  }

  /// 获取当前已安装 APK 的真实版本名与 Build 编号
  static Future<Map<String, dynamic>> getInstalledVersionInfo() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getAppVersion');
      if (res != null) {
        return {
          'versionName': res['versionName']?.toString() ?? currentVersionName,
          'versionCode': (res['versionCode'] as num?)?.toInt() ?? currentBuildNumber,
        };
      }
    } catch (_) {}
    return {
      'versionName': currentVersionName,
      'versionCode': currentBuildNumber,
    };
  }

  static Future<int> getInstalledBuildNumber() async {
    final info = await getInstalledVersionInfo();
    return info['versionCode'] as int;
  }

  static Future<String> getInstalledVersionName() async {
    final info = await getInstalledVersionInfo();
    return info['versionName'] as String;
  }

  /// 针对 GitHub 私有仓库，通过 API 获取 302 重定向后的云端预签名临时直链（有效期内全网直连）
  static Future<String?> fetchSignedDownloadUrl(int assetId) async {
    if (assetId <= 0) return null;
    try {
      final token = await getGithubToken();
      final assetApiUrl = 'https://api.github.com/repos/$_defaultOwner/$_defaultRepo/releases/assets/$assetId';
      final probeDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          followRedirects: false, // 严禁自动跟随，截获 302 Location
          validateStatus: (status) => status != null && status >= 200 && status < 400,
        ),
      );

      final headers = <String, String>{
        'Accept': 'application/octet-stream',
        'User-Agent': 'JinriCP-Pure-App-Updater',
      };
      if (token.isNotEmpty) {
        headers['Authorization'] = 'token $token';
      }

      final resp = await probeDio.get(
        assetApiUrl,
        options: Options(headers: headers),
      );

      if (resp.statusCode == 302 || resp.statusCode == 301) {
        final loc = resp.headers.value('location');
        if (loc != null && loc.isNotEmpty) {
          debugPrint('Successfully extracted signed private asset URL');
          return loc;
        }
      }
    } catch (e) {
      debugPrint('Fetch signed asset url error: $e');
    }
    return null;
  }

  /// 获取可供直接访问下载的 URL（优先返回私有预签名云直链，次选浏览器直链）
  static Future<String> getDirectDownloadUrl(UpdateInfo info) async {
    if (info.assetId > 0) {
      final signedUrl = await fetchSignedDownloadUrl(info.assetId);
      if (signedUrl != null && signedUrl.isNotEmpty) {
        return signedUrl;
      }
    }
    return info.browserUrl;
  }

  /// 记录稍后提醒该版本（防打扰 24 小时）
  static Future<void> dismissVersion(String version) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt('last_dismissed_update_time', DateTime.now().millisecondsSinceEpoch);
      await sp.setString('last_dismissed_update_version', version);
    } catch (_) {}
  }

  /// 检查是否有新版本可用
  static Future<UpdateInfo?> checkUpdate({bool force = false}) async {
    try {
      final token = await getGithubToken();
      final headers = <String, String>{
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'JinriCP-Pure-App-Updater',
      };
      if (token.isNotEmpty) {
        headers['Authorization'] = 'token $token';
      }

      final url = 'https://api.github.com/repos/$_defaultOwner/$_defaultRepo/releases';
      final response = await _dio.get<List<dynamic>>(
        url,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
        // 优先在 releases 列表中寻找首个包含有效 .apk 资产的 release
        Map<String, dynamic>? latest;
        for (final item in response.data!) {
          if (item is Map<String, dynamic>) {
            final assets = item['assets'] as List<dynamic>? ?? [];
            if (assets.any((a) => (a['name']?.toString() ?? '').endsWith('.apk'))) {
              latest = item;
              break;
            }
          }
        }
        latest ??= response.data!.first as Map<String, dynamic>;

        final tagName = latest['tag_name']?.toString() ?? '';
        final title = latest['name']?.toString() ?? '发现新版本';
        final body = latest['body']?.toString() ?? '日常体验优化与问题修复。';
        final publishedAt = latest['published_at']?.toString() ?? '';
        final htmlUrl = latest['html_url']?.toString() ?? 'https://github.com/$_defaultOwner/$_defaultRepo/releases';

        // 1. 提取远程版本号，如 v1.0.46 -> 1.0.46
        String remoteVer = tagName.replaceAll(RegExp(r'^v', caseSensitive: false), '');
        if (remoteVer.contains('-')) {
          remoteVer = remoteVer.split('-').first;
        }

        // 2. 查找 release 中的 apk 资产
        final assets = latest['assets'] as List<dynamic>? ?? [];
        int assetId = 0;
        String assetName = '';
        int assetSize = 0;
        String browserDownloadUrl = '';

        for (final a in assets) {
          final name = a['name']?.toString() ?? '';
          if (name.endsWith('.apk')) {
            assetId = a['id'] as int? ?? 0;
            assetName = name;
            assetSize = a['size'] as int? ?? 0;
            browserDownloadUrl = a['browser_download_url']?.toString() ?? '';
            break;
          }
        }

        // 3. 获取本地已安装版本信息并进行严格语义化比对
        final installedInfo = await getInstalledVersionInfo();
        final localVer = installedInfo['versionName'] as String;
        final installedBuild = installedInfo['versionCode'] as int;

        // 核心规则：仅当远程版本号严格大于本地版本时才判定为新版本
        bool hasNewVersion = false;
        final verCmp = compareVersion(remoteVer, localVer);
        if (verCmp > 0) {
          hasNewVersion = true;
        }

        // 自动静默检测模式下：若版本已是最新或更早，坚决不返回弹窗，彻底杜绝打扰
        if (!force && !hasNewVersion) {
          return null;
        }

        // 4. 防打扰拦截：若用户对该版本已点击过“稍后提醒”，24 小时内不自动弹窗
        if (!force && hasNewVersion) {
          try {
            final sp = await SharedPreferences.getInstance();
            final dismissedTime = sp.getInt('last_dismissed_update_time') ?? 0;
            final dismissedVer = sp.getString('last_dismissed_update_version') ?? '';
            final now = DateTime.now().millisecondsSinceEpoch;
            if (dismissedVer == remoteVer && (now - dismissedTime < 24 * 60 * 60 * 1000)) {
              return null;
            }
          } catch (_) {}
        }

        if (assetId > 0 && (hasNewVersion || force)) {
          final directDownloadUrl = browserDownloadUrl.isNotEmpty
              ? browserDownloadUrl
              : 'https://github.com/$_defaultOwner/$_defaultRepo/releases/download/$tagName/$assetName';

          return UpdateInfo(
            tagName: tagName,
            title: title,
            releaseNotes: body,
            publishedAt: publishedAt,
            versionName: remoteVer,
            buildNumber: installedBuild + 1,
            assetId: assetId,
            assetName: assetName,
            assetSize: assetSize,
            downloadUrl: directDownloadUrl,
            browserUrl: browserDownloadUrl.isNotEmpty ? browserDownloadUrl : htmlUrl,
            hasNewVersion: hasNewVersion,
          );
        }
      }
    } catch (e) {
      debugPrint('Check update error: $e');
    }
    return null;
  }

  /// 获取下载存储目录
  static Future<String> getDownloadDirectory() async {
    try {
      final dir = await _channel.invokeMethod<String>('getDownloadDir');
      if (dir != null && dir.isNotEmpty) return dir;
    } catch (_) {}
    return '/sdcard/Download';
  }

  /// 在线下载 APK 并触发系统原生安装（多通道智能回退与私有直链极速下载）
  static Future<bool> downloadAndInstall({
    required UpdateInfo info,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final downloadDir = await getDownloadDirectory();
      final safeName = info.assetName.isNotEmpty ? info.assetName : 'JinriCP-Pure-${info.versionName}.apk';
      final savePath = '$downloadDir/$safeName';
      final file = File(savePath);

      // 如果已完整下载过该 APK（大小吻合且大于 5MB），直接唤起系统安装
      if (await file.exists()) {
        final length = await file.length();
        if (info.assetSize > 0 && length == info.assetSize && length > 5 * 1024 * 1024) {
          debugPrint('APK already downloaded and size matches, triggering install: $savePath');
          return await installApk(savePath);
        }
      }

      final tempPath = '$savePath.download';
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      // 构建下载候选直链列表：首选私有签名直链，备选官方直链与镜像代理
      final candidateUrls = <String>[];

      // 1. 首选：针对私有仓库，通过 GitHub API 提取 302 Azure 签名极速直链
      if (info.assetId > 0) {
        final signed = await fetchSignedDownloadUrl(info.assetId);
        if (signed != null && signed.isNotEmpty) {
          candidateUrls.add(signed);
        }
      }

      // 2. 备选：公开下载直链与镜像代理直链（降级兜底）
      if (info.downloadUrl.isNotEmpty) {
        candidateUrls.add(info.downloadUrl);
        candidateUrls.add('https://ghfast.top/${info.downloadUrl}');
        candidateUrls.add('https://mirror.ghproxy.com/${info.downloadUrl}');
      }

      if (candidateUrls.isEmpty) {
        debugPrint('No available download URLs');
        return false;
      }

      // 3. 实例化纯净 Dio（无 Authorization 头，避免触发云存储鉴权冲突 400 错误）
      final cleanDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 10),
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      bool downloaded = false;
      for (final targetUrl in candidateUrls) {
        try {
          if (cancelToken?.isCancelled == true) break;
          debugPrint('Trying download from candidate URL...');

          await cleanDio.download(
            targetUrl,
            tempPath,
            options: Options(
              headers: {
                'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile)',
                'Accept': '*/*',
              },
            ),
            onReceiveProgress: onProgress,
            cancelToken: cancelToken,
          );

          if (await tempFile.exists()) {
            final len = await tempFile.length();
            if (len > 5 * 1024 * 1024) {
              downloaded = true;
              break;
            } else {
              debugPrint('Downloaded file too small ($len bytes), discarding invalid response');
              await tempFile.delete();
            }
          }
        } catch (e) {
          debugPrint('Download error from candidate: $e');
          if (await tempFile.exists()) {
            try {
              await tempFile.delete();
            } catch (_) {}
          }
        }
      }

      if (downloaded && await tempFile.exists()) {
        if (await file.exists()) {
          await file.delete();
        }
        await tempFile.rename(savePath);
        debugPrint('APK download completed: $savePath, triggering installation');
        return await installApk(savePath);
      }
    } catch (e) {
      debugPrint('Download and install error: $e');
    }
    return false;
  }

  /// 调用 Android 系统安装器
  static Future<bool> installApk(String filePath) async {
    try {
      final res = await _channel.invokeMethod<bool>('installApk', {'filePath': filePath});
      return res ?? false;
    } catch (e) {
      debugPrint('Install APK error: $e');
      return false;
    }
  }

  /// 使用外部系统浏览器打开更新链接
  static Future<bool> openUrl(String url) async {
    try {
      final res = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      return res ?? false;
    } catch (e) {
      debugPrint('Open URL error: $e');
      return false;
    }
  }
}
