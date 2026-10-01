import 'dart:convert';

import 'package:dio/dio.dart';

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

  static const _base = 'https://www.ting15.com';
  static const _sourceId = 'ting15';

  static const _ua =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  late final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    responseType: ResponseType.plain,
    headers: {
      'User-Agent': _ua,
      'Referer': _base,
    },
  ));

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

  Book _bookFromCatId(String cat, String id, String title, String pic, String author, String announcer) {
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

  Map<String, String> _h(String referer) => {
        'User-Agent': _ua,
        'Referer': referer.isEmpty ? _base : referer,
      };

  @override
  Future<List<Book>> search(String keyword, {int page = 1, int pageSize = 20}) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return [];
    final url =
        '$_base/?s=ting-search-wd-$kw.html';
    final res = await _dio.get(url, options: Options(headers: _h(_base)));
    final html = res.data.toString();
    return _parseBookList(html);
  }

  @override
  Future<List<Book>> category(String catId, {int page = 1}) async {
    final url = page <= 1 ? '$_base/$catId/' : '$_base/$catId/$page/';
    final res = await _dio.get(url, options: Options(headers: _h(_base)));
    final html = res.data.toString();
    return _parseBookList(html);
  }

  @override
  Future<List<Book>> hot({int limit = 30}) async {
    final res = await _dio.get(_base, options: Options(headers: _h(_base)));
    final html = res.data.toString();
    return _parseBookList(html).take(limit).toList();
  }

  List<Book> _parseBookList(String html) {
    final books = <Book>[];
    final liRegex = RegExp(
      r'<li>\s*<div class="img">\s*<a href="/(\w+)/(\d+)\.html"[^>]*>\s*<img src="([^"]*)"[^>]*alt="([^"]*)"[^>]*>',
      dotAll: true,
    );
    final catBookRegex = RegExp(
      r'<a href="/(?:wuxiaxuanhuan|kongbulingyi|tuilixuanyi|dushiyanqing|jiatinglunli|wenxuemingzhu|jingdianpingshu|quyixiqu|xiangshengxiaopin|yinyue)/(\d+)\.html"[^>]*alt="([^"]*)"',
    );

    for (final m in liRegex.allMatches(html)) {
      final cat = m.group(1)!;
      final id = m.group(2)!;
      final pic = m.group(3) ?? '';
      final title = (m.group(4) ?? '').trim();
      if (title.isEmpty) continue;
      books.add(_bookFromCatId(cat, id, title, pic, '', ''));
    }

    if (books.isEmpty) {
      for (final m in catBookRegex.allMatches(html)) {
        final id = m.group(1)!;
        final title = (m.group(2) ?? '').trim();
        if (title.isEmpty) continue;
        books.add(_bookFromCatId('wuxiaxuanhuan', id, title, '', '', ''));
      }
    }

    if (books.isEmpty) {
      final simpleRegex = RegExp(r'<a href="/(\w+)/(\d+)\.html"[^>]*>\s*([^<]{2,50})\s*</a>');
      for (final m in simpleRegex.allMatches(html)) {
        final cat = m.group(1)!;
        final id = m.group(2)!;
        final title = m.group(3)!.trim();
        if (title.isEmpty || title.contains('有声小说')) continue;
        books.add(_bookFromCatId(cat, id, title, '', '', ''));
      }
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
      options: Options(headers: _h('$_base/$cat/')),
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

    final authorMatch = RegExp(r'<span class="bz">\[著\]\s*([^<]+?)\s*<').firstMatch(html);
    final author = _stripHtml(authorMatch?.group(1) ?? '');

    final announcerMatch =
        RegExp(r'<span class="bys">.*?<a[^>]*>([^<]+?)</a>', dotAll: true).firstMatch(html);
    final announcer = _stripHtml(announcerMatch?.group(1) ?? '');

    final descMatch =
        RegExp(r'<div class="bxq">.*?<div class="cinfo">(.*?)</div>\s*</div>', dotAll: true)
            .firstMatch(html) ??
            RegExp(r'<div class="bxq">\s*(.*?)\s*</div>', dotAll: true).firstMatch(html);
    var desc = _stripHtml(descMatch?.group(1) ?? '');

    final chapters = <Chapter>[];
    final chapterRegex = RegExp(
      r'<a href="/$cat/$id/0-(\d+)\.html"[^>]*>(.*?)</a>',
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
    final res = await _dio.get(
      playUrl,
      options: Options(headers: _h('$_base/$cat/$bookId.html')),
    );
    final html = res.data.toString();

    String? _meta(String name) =>
        RegExp('<meta name="$name" content="([^"]*)"').firstMatch(html)?.group(1);

    final token = _meta('_c') ?? '';
    final b = _meta('_b') ?? bookId;
    final cp = _meta('_cp') ?? '$chapterId';
    final p = _meta('_p') ?? '0';
    final l = _meta('_l') ?? '1';

    final apiRes = await _dio.post(
      '$_base/?s=api-getneoplay',
      data: {'bookId': b, 'isPay': p, 'page': cp},
      options: Options(
        headers: {
          ..._h(playUrl),
          'Content-Type': 'application/x-www-form-urlencoded',
          'xt': token,
          'l': l,
        },
      ),
    );
    final json = jsonDecode(apiRes.data.toString());
    final status = json['status'];
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