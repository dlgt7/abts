import 'dart:async';

import 'package:webview_flutter/webview_flutter.dart';

import 'audio_extractor.dart';

WebViewController Function()? _globalControllerFactory;

void setWebViewControllerFactory(WebViewController Function() factory) {
  _globalControllerFactory = factory;
}

const _kExtractJs = """
(function(){
  try {
    var a = document.querySelector('audio[src]');
    if (a && a.src) return a.src;
    var s = document.querySelector('source[src]');
    if (s && s.src) return s.src;
    var all = document.querySelectorAll('audio');
    for (var i=0;i<all.length;i++){ if(all[i].src) return all[i].src; }
    var links = document.querySelectorAll('a[href]');
    for (var i=0;i<links.length;i++){
      var h = links[i].href;
      if (h && /\\.(mp3|m4a|aac)(\\?|$)/i.test(h)) return h;
    }
  } catch(e) {}
  return '';
})()
""";

class WebViewAudioExtractor implements AudioExtractor {
  final WebViewController Function()? controllerFactory;
  final Duration pollInterval;
  final Duration timeout;

  WebViewAudioExtractor({
    this.controllerFactory,
    this.pollInterval = const Duration(milliseconds: 500),
    this.timeout = const Duration(seconds: 12),
  });

  @override
  Future<List<String>> extract(AudioContext ctx) async {
    final factory = controllerFactory ?? _globalControllerFactory;
    if (factory == null) {
      throw Exception('WebView 控制器未配置，请先调用 setWebViewControllerFactory');
    }
    final cfg = ctx.config;
    final base = ctx.baseUrl;
    final bookId = ctx.sourceBookId;
    final cid = ctx.chapterId;
    final playPathTpl = cfg['playPath'] as String? ?? '/book/{bookId}-{cid}';
    final playUrl = base +
        playPathTpl
            .replaceAll('{bookId}', bookId)
            .replaceAll('{cid}', '$cid');

    final controller = factory();
    await controller.loadRequest(Uri.parse(playUrl));
    await _waitForLoad(controller, timeout);

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final raw = await controller.runJavaScriptReturningResult(_kExtractJs);
        final url = _extractString(raw).trim();
        if (url.isNotEmpty) return [normalizeAudioUrl(url)];
      } catch (_) {}
      await Future<void>.delayed(pollInterval);
    }
    throw Exception('WebView 提取音频超时');
  }

  Future<void> _waitForLoad(WebViewController c, Duration max) async {
    final deadline = DateTime.now().add(max);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final canEval = await c.runJavaScriptReturningResult('1');
        if (canEval.toString() == '1') return;
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  String _extractString(Object raw) {
    if (raw is String) return raw;
    return raw.toString();
  }
}