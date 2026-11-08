import 'dart:convert';
import 'package:dio/dio.dart';
import 'settings_service.dart';

class AiTranslationService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  static const String _nvidiaApiUrl = 'https://integrate.api.nvidia.com/v1/chat/completions';

  /// 毫秒级极速韩语同传翻译
  Future<String> translateKoreanToChinese(String koreanText) async {
    if (koreanText.trim().isEmpty) return '';

    final apiKey = await SettingsService.getNvidiaKey();
    final primaryModel = await SettingsService.getNvidiaModel();

    final candidateModels = [
      primaryModel,
      'deepseek-ai/deepseek-v4-flash-0731',
      'deepseek-ai/deepseek-v4-pro-0813',
      'deepseek-ai/deepseek-coder-6.7b-instruct',
    ];

    for (final modelName in candidateModels) {
      try {
        final response = await _dio.post(
          _nvidiaApiUrl,
          options: Options(
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
          ),
          data: jsonEncode({
            'model': modelName,
            'messages': [
              {
                'role': 'system',
                'content': '你是一个专业高效的韩国女主播直播间实时同传助手。将收到的韩语口语直接翻译成生动地道、自然流畅的中文口语，不要有任何多余分析和解释，只输出单句翻译结果。'
              },
              {
                'role': 'user',
                'content': koreanText
              }
            ],
            'temperature': 0.1,
            'max_tokens': 60,
          }),
        );

        if (response.statusCode == 200) {
          final data = response.data;
          final choices = data['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            final content = choices[0]['message']?['content']?.toString()?.trim() ?? '';
            if (content.isNotEmpty) {
              return content;
            }
          }
        }
      } catch (_) {
        continue;
      }
    }
    return '';
  }
}
