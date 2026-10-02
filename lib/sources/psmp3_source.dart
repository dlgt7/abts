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
  static const _cacheTtlMs = 30 * 60 * 1000;

  static const _ua =
      'Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

  late final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    responseType: ResponseType.plain,
  ));

  final Map<String, ({List<({String name, String url})> items, int ts})>
      _volumeCache = {};

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
        SourceCategory(id: 'tzy', label: '田战义'),
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

  List<({String name, String url})> _parsePlayItems(String html) {
    final items = <({String name, String url})>[];
    final playRegex = RegExp(
      r'\{name:\s*"([^"]+)"[^}]*url:\s*"([^"]+)"',
      caseSensitive: false,
    );
    for (final m in playRegex.allMatches(html)) {
      final name = m.group(1)!.trim();
      final url = _normalizeUrl(m.group(2)!);
      if (name.isEmpty || url.isEmpty) continue;
      items.add((name: name, url: url));
    }
    return items;
  }

  String _volumePrefix(String path) {
    final m = RegExp(r'-(\d+)$').firstMatch(path);
    if (m == null) return '';
    return path.substring(0, m.start + 1);
  }

  List<String> _volumePaths(String html, String currentPath) {
    final prefix = _volumePrefix(currentPath);
    final dir = currentPath.startsWith('/') ? currentPath.substring(1) : currentPath;
    final found = <String>{currentPath};
    for (final m in RegExp('href="([^"]+)"').allMatches(html)) {
      final raw = m.group(1)!;
      if (!raw.endsWith('.html')) continue;
      var p = raw.startsWith('http')
          ? raw
          : raw.startsWith('/')
              ? '$_base$raw'
              : '';
      if (!p.startsWith('$_base/')) continue;
      p = _extractPath(p);
      if (prefix.isNotEmpty) {
        if (!p.startsWith(prefix)) continue;
        if (!RegExp(r'^\d+$').hasMatch(p.substring(prefix.length))) continue;
        found.add(p);
      } else if (RegExp('^/$dir/[^/]+-\\d+\$').hasMatch(p)) {
        found.add(p);
      }
    }
    final list = found.toList();
    list.sort((a, b) {
      final na = int.tryParse(a.split('-').last) ?? 0;
      final nb = int.tryParse(b.split('-').last) ?? 0;
      return na.compareTo(nb);
    });
    return list;
  }

  String _bookPathFromPrefix(String prefix) {
    final idx = prefix.indexOf('/', 1);
    if (idx <= 0) return '';
    return prefix.substring(0, idx);
  }

  Future<List<({String name, String url})>> _loadAllItems(
    String sourceBookId, {
    String? rootHtml,
  }) async {
    final cached = _volumeCache[sourceBookId];
    if (cached != null &&
        DateTime.now().millisecondsSinceEpoch - cached.ts < _cacheTtlMs) {
      return cached.items;
    }
    final rootPath = _extractPath(sourceBookId);
    final html = rootHtml ?? await _fetch('$rootPath.html', referer: _base);
    final rootItems = _parsePlayItems(html);
    var paths = _volumePaths(html, rootPath);

    final prefix = _volumePrefix(rootPath);
    var bookPath = '';
    if (prefix.isNotEmpty) {
      bookPath = _bookPathFromPrefix(prefix);
      if (bookPath.isNotEmpty) {
        try {
          final bookHtml = await _fetch('$bookPath.html', referer: _base);
          paths = _volumePaths(bookHtml, bookPath);
        } catch (_) {}
      }
    }

    final items = <({String name, String url})>[];
    for (final p in paths) {
      if (p == rootPath) {
        items.addAll(rootItems);
        continue;
      }
      if (bookPath.isNotEmpty && p == bookPath) continue;
      try {
        final volHtml = await _fetch('$p.html', referer: _base);
        items.addAll(_parsePlayItems(volHtml));
      } catch (_) {}
    }
    if (items.isEmpty) items.addAll(rootItems);
    if (items.isNotEmpty) {
      _volumeCache[sourceBookId] =
          (items: items, ts: DateTime.now().millisecondsSinceEpoch);
    }
    return items;
  }

  @override
  Future<Book> detail(String sourceBookId) async {
    final rootPath = _extractPath(sourceBookId);
    final rootHtml = await _fetch('$rootPath.html', referer: _base);

    var title = RegExp(r'<h1[^>]*>([^<]+)</h1>', caseSensitive: false)
            .firstMatch(rootHtml)
            ?.group(1)
            ?.trim() ??
        sourceBookId;
    title = title.replaceAll(RegExp(r'在线收听[,，]免费下载$'), '').trim();

    final coverMatch = RegExp(r'cover:\s*"([^"]+)"', caseSensitive: false)
        .firstMatch(rootHtml);
    final pic = coverMatch != null ? _normalizeUrl(coverMatch.group(1)!) : '';

    final items = await _loadAllItems(sourceBookId, rootHtml: rootHtml);
    final chapters = <Chapter>[];
    for (var i = 0; i < items.length; i++) {
      chapters.add(Chapter(cid: i, page: i + 1, part: items[i].name));
    }

    return Book(
      bvid: _bookKey(rootPath),
      aid: 0,
      title: title,
      pic: pic,
      author: '',
      sourceId: _sourceId,
      sourceBookId: rootPath,
      pages: chapters.length,
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> audioUrls(String sourceBookId, int chapterId) async {
    final items = await _loadAllItems(sourceBookId);
    if (chapterId >= 0 && chapterId < items.length) {
      return [items[chapterId].url];
    }
    throw Exception('未找到评书音频地址');
  }
}