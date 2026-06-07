import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _nimApiKeyStorageKey = 'nim_api_key';

class NimMessage {
  final String role; // 'system' | 'user' | 'assistant'
  final String content;

  const NimMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class NimService {
  NimService({
    required this.baseUrl,
    required this.model,
    required this.temperature,
    FlutterSecureStorage? secureStorage,
    Dio? dioClient,
  })  : _storage = secureStorage ?? const FlutterSecureStorage(),
        _dio = dioClient ?? Dio();

  final String baseUrl;
  final String model;
  final double temperature;
  final FlutterSecureStorage _storage;
  final Dio _dio;

  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage();

  static Future<void> saveApiKey(String key) async {
    await _defaultStorage.write(key: _nimApiKeyStorageKey, value: key);
  }

  static Future<String?> loadApiKey() async {
    return _defaultStorage.read(key: _nimApiKeyStorageKey);
  }

  static Future<void> deleteApiKey() async {
    await _defaultStorage.delete(key: _nimApiKeyStorageKey);
  }

  Future<String?> _getKey() => _storage.read(key: _nimApiKeyStorageKey);

  Options _buildOptions(String? apiKey) => Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      );

  /// Single-shot completion — returns the full assistant message content.
  Future<String> complete(List<NimMessage> messages) async {
    final apiKey = await _getKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('NVIDIA NIM API key not set. Configure it in Settings.');
    }

    final response = await _dio.post(
      '$baseUrl/chat/completions',
      options: _buildOptions(apiKey),
      data: {
        'model': model,
        'messages': messages.map((m) => m.toJson()).toList(),
        'temperature': temperature,
        'max_tokens': 1024,
      },
    );

    final content =
        response.data['choices'][0]['message']['content'] as String;
    return content.trim();
  }

  /// Streaming completion — yields delta tokens as they arrive via SSE.
  Stream<String> stream(List<NimMessage> messages) async* {
    final apiKey = await _getKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('NVIDIA NIM API key not set. Configure it in Settings.');
    }

    final response = await _dio.post<ResponseBody>(
      '$baseUrl/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.stream,
      ),
      data: {
        'model': model,
        'messages': messages.map((m) => m.toJson()).toList(),
        'temperature': temperature,
        'max_tokens': 1024,
        'stream': true,
      },
    );

    final stream = response.data!.stream;
    final buffer = StringBuffer();

    await for (final chunk in stream) {
      buffer.write(utf8.decode(chunk));
      final raw = buffer.toString();
      final lines = raw.split('\n');

      // Process all complete lines, keep the last potentially incomplete one
      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.startsWith('data: ')) {
          final payload = line.substring(6);
          if (payload == '[DONE]') return;
          try {
            final json = jsonDecode(payload) as Map<String, dynamic>;
            final delta =
                json['choices']?[0]?['delta']?['content'] as String?;
            if (delta != null && delta.isNotEmpty) yield delta;
          } catch (_) {
            // Ignore malformed SSE line
          }
        }
      }

      buffer
        ..clear()
        ..write(lines.last);
    }
  }

  /// Build the system prompt with current trade context.
  static NimMessage buildSystemPrompt({
    required String accountType,
    required double balance,
    required String openTradesJson,
    required double marginLevelPct,
    String language = 'en',
    String? closedTradeStats,
  }) {
    final langNote = language != 'en'
        ? '\n- Respond in the user\'s language (code: $language).'
        : '';
    final statsNote = closedTradeStats != null
        ? '\n- Historical performance: $closedTradeStats'
        : '';
    final prompt = '''
You are a concise multi-market trading coach and assistant.
The user trades Forex, precious metals (XAUUSD/XAGUSD), cryptocurrencies, and indices.

Current account context:
- Account type: $accountType
- Balance / Equity: \$${balance.toStringAsFixed(2)}
- Open trades: $openTradesJson
- Margin level: ${marginLevelPct == double.infinity ? 'No open trades' : '${marginLevelPct.toStringAsFixed(1)}%'}$statsNote

Rules:
- Be factual and concise (max 3 sentences for auto-insights).
- Always highlight risk clearly if margin level is below 150%.
- Use the account type to interpret lot sizes (cent account lots are 1/1000 of standard).
- Give actionable advice specific to the user\'s open positions.$langNote
''';
    return NimMessage(role: 'system', content: prompt);
  }
}
