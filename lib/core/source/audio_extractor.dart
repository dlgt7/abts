import 'dart:convert';

import 'package:dio/dio.dart';

String normalizeAudioUrl(String u) {
  if (u.isEmpty) return u;
  try {
    if (Uri.decodeComponent(u) != u) return u;
  } catch (_) {}
  try {
    final old = Uri.parse(u);
    return Uri(
      scheme: old.scheme,
      userInfo: old.userInfo,
      host: old.host,
      port: old.port,
      path: old.path,
      query: old.query,
      fragment: old.fragment,
    ).toString();
  } catch (_) {
    return u;
  }
}

class AudioContext {
  final Dio dio;
  final String baseUrl;
  final String sourceBookId;
  final int chapterId;
  final Map<String, dynamic> config;
  final Map<String, String> headers;

  AudioContext({
    required this.dio,
    required this.baseUrl,
    required this.sourceBookId,
    required this.chapterId,
    required this.config,
    required this.headers,
  });
}

abstract class AudioExtractor {
  Future<List<String>> extract(AudioContext ctx);
}

class AudioExtractorRegistry {
  AudioExtractorRegistry._();
  static final AudioExtractorRegistry instance = AudioExtractorRegistry._();

  final Map<String, AudioExtractor Function()> _factories = {
    'meta_api': MetaApiAudioExtractor.new,
    'static_url': StaticUrlAudioExtractor.new,
  };

  AudioExtractor? create(String type) {
    final f = _factories[type];
    return f?.call();
  }

  void register(String type, AudioExtractor Function() factory) {
    _factories[type] = factory;
  }

  bool has(String type) => _factories.containsKey(type);
}

class MetaApiAudioExtractor implements AudioExtractor {
  @override
  Future<List<String>> extract(AudioContext ctx) async {
    final cfg = ctx.config;
    final dio = ctx.dio;
    final base = ctx.baseUrl;
    final bookId = ctx.sourceBookId;
    final cid = ctx.chapterId;
    final extraHeaders = ctx.headers;

    final playPathTpl = cfg['playPath'] as String? ?? '/book/{bookId}-{cid}';
    final playUrl = base +
        playPathTpl
            .replaceAll('{bookId}', bookId)
            .replaceAll('{cid}', '$cid');

    final apiPath = cfg['apiPath'] as String? ?? '/nlinka';
    final apiUrl = base + apiPath;

    final metaToken = cfg['metaToken'] as String? ?? '_c';
    final metaBookId = cfg['metaBookId'] as String? ?? '_b';
    final metaIsPay = cfg['metaIsPay'] as String? ?? '_p';
    final metaL = cfg['metaL'] as String? ?? '_l';
    final headerToken = cfg['headerToken'] as String? ?? 'xt';
    final headerL = cfg['headerL'] as String? ?? 'l';
    final maxRetry = (cfg['maxRetry'] as num?)?.toInt() ?? 3;
    final retryDelayMs = (cfg['retryDelayMs'] as num?)?.toInt() ?? 1200;

    for (var attempt = 0; attempt < maxRetry; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: retryDelayMs));
      }
      final res = await dio.get(
        playUrl,
        options: Options(
          headers: {
            ...extraHeaders,
            'Referer': playUrl,
          },
        ),
      );
      final html = res.data.toString();

      String? meta(String name) =>
          RegExp('<meta name="$name" content="([^"]*)"').firstMatch(html)?.group(1);

      final token = meta(metaToken) ?? '';
      final b = meta(metaBookId) ?? bookId;
      final p = meta(metaIsPay) ?? '0';
      final l = meta(metaL) ?? '1';

      final apiRes = await dio.post(
        apiUrl,
        data: {'bookId': b, 'isPay': p, 'page': '$cid'},
        options: Options(
          headers: {
            ...extraHeaders,
            'Referer': playUrl,
            'Content-Type': 'application/x-www-form-urlencoded',
            headerToken: token,
            headerL: l,
          },
        ),
      );
      final raw = apiRes.data.toString();
      final clean = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
      final json = jsonDecode(clean);
      final status = json['status'];
      if (status == -2) continue;
      if (status == -1 || status == 0) {
        throw Exception('音频不可用（状态 $status）');
      }
      final ourl = json['ourl']?.toString() ?? '';
      final url = ourl.isNotEmpty ? ourl : (json['url']?.toString() ?? '');
      if (url.isEmpty) {
        throw Exception('未找到音频地址');
      }
      return [normalizeAudioUrl(url)];
    }
    throw Exception('切集限流，请稍后重试');
  }
}

class StaticUrlAudioExtractor implements AudioExtractor {
  @override
  Future<List<String>> extract(AudioContext ctx) async {
    final cfg = ctx.config;
    final dio = ctx.dio;
    final base = ctx.baseUrl;
    final bookId = ctx.sourceBookId;
    final cid = ctx.chapterId;
    final extraHeaders = ctx.headers;

    final playPathTpl = cfg['playPath'] as String? ?? '/book/{bookId}-{cid}';
    final playUrl = base +
        playPathTpl
            .replaceAll('{bookId}', bookId)
            .replaceAll('{cid}', '$cid');

    final res = await dio.get(
      playUrl,
      options: Options(headers: {...extraHeaders, 'Referer': playUrl}),
    );
    final html = res.data.toString();

    final patterns = <RegExp>[
      RegExp(r'<audio[^>]*src="([^"]+)"'),
      RegExp(r'<source[^>]*src="([^"]+)"'),
      RegExp("(https?://[^\\s\"'<>]+\\.(?:mp3|m4a|aac)[^\\s\"'<>]*)"),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(html);
      if (m != null) {
        final url = m.group(1)!.trim();
        if (url.isNotEmpty) return [normalizeAudioUrl(url)];
      }
    }
    throw Exception('未找到音频地址');
  }
}