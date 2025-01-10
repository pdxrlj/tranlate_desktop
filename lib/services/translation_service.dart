import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_config.dart';

class TranslationService {
  final ApiConfig config;

  TranslationService(this.config);

  Future<String> translate(String text, {String targetLang = 'zh'}) async {
    try {
      final response = await http.post(
        Uri.parse('${config.baseUrl}/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer ${config.apiKey}',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'model': config.modelName.isNotEmpty ? config.modelName : 'deepseek-chat',
          'messages': [
            {
              'role': 'system',
              'content': '你是一个专业的翻译助手。请将用户输入的文本翻译成${targetLang == "zh" ? "中文" : "英文"}，只返回翻译结果，不需要解释。'
            },
            {
              'role': 'user',
              'content': text,
            }
          ],
          'temperature': 0.7,
          'max_tokens': 2000,
        }),
        encoding: utf8,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'].trim();
      } else {
        final errorBody = utf8.decode(response.bodyBytes);
        throw Exception('翻译失败: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      throw Exception('翻译服务错误: $e');
    }
  }
}
