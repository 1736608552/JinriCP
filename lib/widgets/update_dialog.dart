import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static Future<void> show(BuildContext context, UpdateInfo info) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(updateInfo: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _progressText = '';
  String _errorMsg = '';
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _errorMsg = '';
      _progressText = '准备开始下载...';
      _cancelToken = CancelToken();
    });

    final success = await UpdateService.downloadAndInstall(
      info: widget.updateInfo,
      cancelToken: _cancelToken,
      onProgress: (received, total) {
        if (mounted && total > 0) {
          final p = received / total;
          final rMb = (received / (1024 * 1024)).toStringAsFixed(1);
          final tMb = (total / (1024 * 1024)).toStringAsFixed(1);
          setState(() {
            _progress = p;
            _progressText = '${(p * 100).toStringAsFixed(0)}%  ($rMb MB / $tMb MB)';
          });
        }
      },
    );

    if (mounted) {
      if (!success) {
        setState(() {
          _isDownloading = false;
          _errorMsg = '下载安装失败，建议使用下方“浏览器下载”';
        });
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final cardBg = isDark ? const Color(0xFF1E2235) : Colors.white;
    final textPrimary = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶端美化横幅
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF2B54), Color(0xFFFF5277)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '发现新版本',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.updateInfo.tagName}  ·  ${widget.updateInfo.sizeText}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            // 中间更新日志内容
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '更新内容：',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141724) : const Color(0xFFF6F8FB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor(context), width: 0.6),
                      ),
                      child: Text(
                        widget.updateInfo.releaseNotes.trim(),
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                    ),

                    if (_isDownloading) ...[
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '正在高速下载...',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _progressText,
                            style: const TextStyle(color: Color(0xFFFF2B54), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          minHeight: 8,
                          backgroundColor: isDark ? Colors.white12 : Colors.black12,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF2B54)),
                        ),
                      ),
                    ],

                    if (_errorMsg.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMsg,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 底部操作按钮区域
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2B54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _isDownloading ? null : _startDownload,
                      child: Text(
                        _isDownloading ? '正在更新中...' : '立即在线更新',
                        style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final directUrl = await UpdateService.getDirectDownloadUrl(widget.updateInfo);
                            await UpdateService.openUrl(directUrl);
                          },
                          child: Text(
                            '浏览器下载',
                            style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            if (_isDownloading) {
                              _cancelToken?.cancel();
                            }
                            UpdateService.dismissVersion(widget.updateInfo.versionName);
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            '稍后提醒',
                            style: TextStyle(color: AppTheme.textMuted(context), fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
