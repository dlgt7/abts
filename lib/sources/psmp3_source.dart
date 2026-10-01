import 'package:dio/dio.dart';

import '../core/source/book_source.dart';
import '../models/book.dart';
import '../models/chapter.dart';

class Psmp3Source implements BookSource {
  @override
  String get id => 'psmp3';

  @override
  String get name => '评书随身听';

  @override
  String get description => 'psmp3.com 评书音频';

  static const _base = 'https://www.psmp3.com';
  static const _sourceId = 'psmp3';

  static const _ua =
      'Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

  late final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    responseType: ResponseType.plain,
  ));

  Map<String, String> _headers({String? referer}) => {
        'User-Agent': _ua,
        'Referer': referer ?? _base,
      };

  @override
  List<SourceCategory> get categories => const [
        SourceCategory(id: 'ykc', label: '袁阔成'),
        SourceCategory(id: 'stf', label: '单田芳'),
        SourceCategory(id: 'tly', label: '田连元'),
        SourceCategory(id: 'llf', label: '刘兰芳'),
        SourceCategory(id: 'llr', label: '连丽如'),
        SourceCategory(id: 'zsz', label: '张少佐'),
        SourceCategory(id: 'tzy', label: '战战元'),
      ];

  String _bookKey(String path) => '$_sourceId:$path';

  String _normalizeUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '$_base$url';
    return '$_base/$url';
  }

  String _extractPath(String url) {
    var path = url.trim();
    if (path.startsWith(_base)) path = path.substring(_base.length);
    if (!path.startsWith('/')) path = '/$path';
    if (path.endsWith('.html')) path = path.substring(0, path.length - 5);
    return path;
  }

  String _stripTags(String s) =>
      s.replaceAll(RegExp(r'<[^>]+>'), '').trim();

  Future<String> _fetch(String path, {String? referer}) async {
    final url = path.startsWith('http') ? path : '$_base$path';
    final res = await _dio.get(
      url,
      options: Options(headers: _headers(referer: referer), responseType: ResponseType.plain),
    );
    return res.data.toString();
  }

  List<Book> _parseList(String html) {
    final books = <Book>[];
    final seen = <String>{};
    final listRegex = RegExp(
      r'<li class="[^"]*post_list_li"[\s\S]*?'
      r'class="listtopimg[^"]*"[^>]*><img src="([^"]+)"[\s\S]*?'
      r'<div class="fenli"><a[^>]*>([^<]+)</a></div>[\s\S]*?'
      r'<h2><a href="([^"]+)">([^<]+)</a></h2>',
      caseSensitive: false,
    );
    for (final m in listRegex.allMatches(html)) {
      final pic = _normalizeUrl(m.group(1)!);
      final path = _extractPath(m.group(3)!);
      final title = m.group(4)!.trim();
      if (title.isEmpty || !seen.add(path)) continue;
      books.add(Book(
        bvid: _bookKey(path),
        aid: 0,
        title: title,
        pic: pic,
        author: m.group(2)!.trim(),
        sourceId: _sourceId,
        sourceBookId: path,
      ));
    }
    if (books.isEmpty) {
      final fbRegex = RegExp(
        r'<li class="[^"]*post_list_li"[\s\S]*?'
        r'<h2><a href="([^"]+)"\s*>(.*?)</a></h2>',
        caseSensitive: false,
        dotAll: true,
      );
      for (final m in fbRegex.allMatches(html)) {
        final path = _extractPath(m.group(1)!);
        final title = _stripTags(m.group(2)!);
        if (title.isEmpty || !seen.add(path)) continue;
        books.add(Book(
          bvid: _bookKey(path),
          aid: 0,
          title: title,
          pic: '',
          sourceId: _sourceId,
          sourceBookId: path,
        ));
      }
    }
    return books;
  }

  @override
  Future<List<Book>> search(String keyword, {int page = 1, int pageSize = 20}) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return [];
    try {
      final html = await _fetch('/search.php?q=${Uri.encodeComponent(kw)}', referer: _base);
      return _parseList(html);
    } catch (_) {
      throw Exception('评书搜索失败，请检查网络或使用分类浏览');
    }
  }

  @override
  Future<List<Book>> category(String catId, {int page = 1}) async {
    try {
      final html = await _fetch('/$catId/$page.html', referer: _base);
      return _parseList(html);
    } catch (_) {
      throw Exception('分类加载失败，请检查网络');
    }
  }

  @override
  Future<List<Book>> hot({int limit = 30}) async {
    try {
      final html = await _fetch('/ykc/1.html', referer: _base);
      return _parseList(html).take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Book> detail(String sourceBookId) async {
    final html = await _fetch('$sourceBookId.html', referer: _base);

    final titleMatch = RegExp(r'<h1[^>]*>([^<]+)</h1>', caseSensitive: false)
        .firstMatch(html);
    final title = titleMatch?.group(1)?.trim() ?? sourceBookId;

    final coverMatch = RegExp(r'cover:\s*"([^"]+)"', caseSensitive: false)
        .firstMatch(html);
    final pic = coverMatch != null ? _normalizeUrl(coverMatch.group(1)!) : '';

    final playRegex = RegExp(
      r'\{name:\s*"([^"]+)"[^}]*url:\s*"([^"]+)"',
      caseSensitive: false,
    );
    final chapters = <Chapter>[];
    var idx = 0;
    for (final m in playRegex.allMatches(html)) {
      final part = m.group(1)!.trim();
      chapters.add(Chapter(cid: idx, page: idx + 1, part: part));
      idx++;
    }

    return Book(
      bvid: _bookKey(sourceBookId),
      aid: 0,
      title: title,
      pic: pic,
      author: '',
      sourceId: _sourceId,
      sourceBookId: sourceBookId,
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> audioUrls(String sourceBookId, int chapterId) async {
    final html = await _fetch('$sourceBookId.html', referer: _base);
    final playRegex = RegExp(
      r'\{name:\s*"([^"]+)"[^}]*url:\s*"([^"]+)"',
      caseSensitive: false,
    );
    final urls = <String>[];
    for (final m in playRegex.allMatches(html)) {
      urls.add(_normalizeUrl(m.group(2)!));
    }
    if (chapterId >= 0 && chapterId < urls.length) {
      return [urls[chapterId]];
    }
    throw Exception('未找到评书音频地址');
  }
}