import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/network/http_factory.dart';
import '../core/source/book_source.dart';
import '../models/book.dart';
import '../models/chapter.dart';

class Ting15Source implements BookSource {
  @override
  String get id => 'ting15';

  @override
  String get name => '有听网';

  @override
  String get description => 'ting15.com 免费有声小说';

  @override
  String? get baseUrl => _base;

  static const _base = 'https://www.ting15.com';
  static const _sourceId = 'ting15';

  static const _ua =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  late final Dio _dio = createDio(userAgent: _ua);

  @override
  List<SourceCategory> get categories => const [
        SourceCategory(id: 'wuxiaxuanhuan', label: '武侠玄幻'),
        SourceCategory(id: 'kongbulingyi', label: '恐怖灵异'),
        SourceCategory(id: 'tuilixuanyi', label: '推理悬疑'),
        SourceCategory(id: 'dushiyanqing', label: '都市言情'),
        SourceCategory(id: 'jiatinglunli', label: '家庭伦理'),
        SourceCategory(id: 'wenxuemingzhu', label: '官场职场'),
        SourceCategory(id: 'jingdianpingshu', label: '经典评书'),
        SourceCategory(id: 'quyixiqu', label: '曲艺戏曲'),
        SourceCategory(id: 'xiangshengxiaopin', label: '相声小品'),
        SourceCategory(id: 'yinyue', label: '助眠音频'),
      ];

  String _bookKey(String cat, String id) => '$_sourceId:$cat/$id';

  Book _bookFromCatId(String cat, String id, String title, String pic,
      String author, String announcer) {
    return Book(
      bvid: _bookKey(cat, id),
      aid: 0,
      title: title,
      pic: pic.isEmpty ? '' : pic,
      author: author,
      upName: announcer,
      sourceId: _sourceId,
      sourceBookId: '$cat/$id',
    );
  }

  Map<String, String> _headers({String referer = ''}) => {
        'User-Agent': _ua,
        'Referer': referer.isEmpty ? _base : referer,
      };

  @override
  Future<List<Book>> search(String keyword, {int page = 1, int pageSize = 20}) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return [];
    try {
      final res = await _dio.post(
        '$_base/?s=ting-search',
        data: {'wd': kw},
        options: Options(
          headers: {
            ..._headers(),
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );
      return _parseBookList(res.data.toString());
    } on DioException catch (_) {
      throw Exception('搜索失败，请检查网络');
    }
  }

  @override
  Future<List<Book>> category(String catId, {int page = 1}) async {
    final baseUrl = '$_base/$catId/';
    final url = page <= 1
        ? baseUrl
        : '$baseUrl/index$page.html';
    final res = await _dio.get(
      url,
      options: Options(headers: _headers(referer: baseUrl)),
    );
    return _parseBookList(res.data.toString());
  }

  @override
  Future<List<Book>> hot({int limit = 30}) async {
    final res = await _dio.get(
      '$_base/wuxiaxuanhuan/',
      options: Options(headers: _headers()),
    );
    return _parseBookList(res.data.toString()).take(limit).toList();
  }

  List<Book> _parseBookList(String html) {
    final books = <Book>[];
    final liRegex = RegExp(
      r'<li>\s*'
      r'<div class="img">\s*'
      r'<a href="/(\w+)/(\d+)\.html"[^>]*title="([^"]*)"[^>]*>\s*'
      r'<img[^>]*src="([^"]*)"[^>]*>',
      dotAll: true,
    );
    final infoRegex = RegExp(
      r'<div class="info">\s*'
      r'<h4>\s*'
      r'<a href="/\w+/(\d+)\.html"[^>]*title="[^"]*"[^>]*>\s*'
      r'([^<]+)',
      dotAll: true,
    );
    final authorRegex = RegExp(r'<p>作者：([^<]+)</p>');
    final announcerRegex = RegExp(r'<p>播音：([^<]+)</p>');

    for (final m in liRegex.allMatches(html)) {
      final cat = m.group(1)!;
      final id = m.group(2)!;
      final pic = m.group(4)!.trim();
      final startIdx = m.end;
      final remaining = html.substring(startIdx);
      final infoMatch = infoRegex.firstMatch(remaining);
      if (infoMatch == null) continue;
      final restAfterInfo = remaining.substring(infoMatch.end);
      final authorMatch = authorRegex.firstMatch(restAfterInfo);
      final announcerMatch = announcerRegex.firstMatch(restAfterInfo);
      final title = (infoMatch.group(2) ?? '').trim();
      final author = (authorMatch?.group(1) ?? '').trim();
      final announcer = (announcerMatch?.group(1) ?? '').trim();
      if (title.isEmpty) continue;
      books.add(_bookFromCatId(cat, id, title, pic, author, announcer));
    }
    return books;
  }

  @override
  Future<Book> detail(String sourceBookId) async {
    final parts = sourceBookId.split('/');
    final cat = parts.isNotEmpty ? parts[0] : 'wuxiaxuanhuan';
    final id = parts.length > 1 ? parts[1] : parts[0];

    final res = await _dio.get(
      '$_base/$cat/$id.html',
      options: Options(headers: _headers(referer: '$_base/$cat/')),
    );
    var html = res.data.toString();

    final titleMatch = RegExp(r'<div class="binfo">\s*<h1>(.*?)</h1>', dotAll: true)
            .firstMatch(html) ??
        RegExp(r'<h1[^>]*>(.*?)</h1>', dotAll: true).firstMatch(html);
    final title = _stripHtml(titleMatch?.group(1) ?? '未知书名');

    final picMatch = RegExp(r'<div class="bimg">\s*<img src="([^"]+)"', dotAll: true)
            .firstMatch(html) ??
        RegExp(r'<img[^>]*class="bimg"[^>]*src="([^"]+)"').firstMatch(html);
    final pic = picMatch?.group(1)?.trim() ?? '';

    final authorMatch = RegExp(r'<p>作者：([^<]+)</p>').firstMatch(html);
    final author = _stripHtml(authorMatch?.group(1) ?? '');

    final announcerMatch =
        RegExp(r'<p>播音：<span class="bys">.*?<a[^>]*>([^<]+?)</a>', dotAll: true)
            .firstMatch(html);
    final announcer = _stripHtml(announcerMatch?.group(1) ?? '');

    final descMatch =
        RegExp(r'<div class="bxq">.*?<div class="cinfo">(.*?)</div>\s*</div>', dotAll: true)
            .firstMatch(html) ??
            RegExp(r'<div class="bxq">\s*(.*?)\s*</div>', dotAll: true).firstMatch(html);
    var desc = _stripHtml(descMatch?.group(1) ?? '');

    final chapters = <Chapter>[];
    final chapterRegex = RegExp(
      '<a[^>]*href="/${RegExp.escape(cat)}/${RegExp.escape(id)}/0-(\\d+)\\.html"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    for (final m in chapterRegex.allMatches(html)) {
      final cp = int.tryParse(m.group(1)!) ?? 0;
      final part = _stripHtml(m.group(2)!.trim());
      chapters.add(Chapter(cid: cp, page: cp + 1, part: part));
    }
    chapters.sort((a, b) => a.page.compareTo(b.page));

    return Book(
      bvid: _bookKey(cat, id),
      aid: 0,
      title: title,
      pic: pic,
      author: author,
      upName: announcer,
      desc: desc,
      pages: chapters.length,
      sourceId: _sourceId,
      sourceBookId: sourceBookId,
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> audioUrls(String sourceBookId, int chapterId) async {
    final parts = sourceBookId.split('/');
    final cat = parts.isNotEmpty ? parts[0] : 'wuxiaxuanhuan';
    final bookId = parts.length > 1 ? parts[1] : parts[0];

    final playUrl = '$_base/$cat/$bookId/0-$chapterId.html';
    final referer = '$_base/$cat/$bookId.html';

    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      final res = await _dio.get(
        playUrl,
        options: Options(headers: _headers(referer: referer)),
      );
      final html = res.data.toString();

      String? _meta(String name) =>
          RegExp('<meta name="$name" content="([^"]*)"').firstMatch(html)?.group(1);

      final token = _meta('_c') ?? '';
      final b = _meta('_b') ?? bookId;
      final p = _meta('_p') ?? '0';
      final l = _meta('_l') ?? '1';

      final apiRes = await _dio.post(
        '$_base/?s=api-getneoplay',
        data: {'bookId': b, 'isPay': p, 'page': '$chapterId'},
        options: Options(
          headers: {
            ..._headers(referer: playUrl),
            'Content-Type': 'application/x-www-form-urlencoded',
            'xt': token,
            'l': l,
          },
        ),
      );
      final raw = apiRes.data.toString();
      final clean = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
      final json = jsonDecode(clean);
      final status = json['status'];
      if (status == -2) continue;
      if (status == -1 || status == 0) {
        throw Exception('有听网音频不可用（状态 $status）');
      }
      final ourl = json['ourl']?.toString() ?? '';
      final url = ourl.isNotEmpty ? ourl : (json['url']?.toString() ?? '');
      if (url.isEmpty) {
        throw Exception('未找到有听网音频地址');
      }
      return [url];
    }
    throw Exception('有听网切集限流，请稍后重试');
  }

  static String _stripHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }
}