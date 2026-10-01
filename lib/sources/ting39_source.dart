
import 'package:dio/dio.dart';

import '../core/source/book_source.dart';
import '../models/book.dart';
import '../models/chapter.dart';

class Ting39Source implements BookSource {
  @override
  String get id => 'ting39';

  @override
  String get name => '幻听网';

  @override
  String get description => 'ting39.com 免费有声小说';

  static const _base = 'https://www.ting39.com';
  static const _sourceId = 'ting39';

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

  String? _cookie;

  @override
  List<SourceCategory> get categories => const [
        SourceCategory(id: 'all', label: '全部'),
        SourceCategory(id: 'xhqh', label: '玄幻奇幻'),
        SourceCategory(id: 'ysyz', label: '影视原著'),
        SourceCategory(id: 'wxxx', label: '武侠仙侠'),
        SourceCategory(id: 'pingshu', label: '长篇评书'),
        SourceCategory(id: 'cyjk', label: '穿越架空'),
        SourceCategory(id: 'xytl', label: '悬疑推理'),
        SourceCategory(id: 'khjj', label: '科幻竞技'),
        SourceCategory(id: 'lsjs', label: '历史军事'),
        SourceCategory(id: 'xdyq', label: '现代言情'),
        SourceCategory(id: 'qcxy', label: '青春校园'),
        SourceCategory(id: 'hxyq', label: '幻想言情'),
        SourceCategory(id: 'gdyq', label: '古代言情'),
        SourceCategory(id: 'wxmz', label: '文学名著'),
        SourceCategory(id: 'xcsh', label: '乡村生活'),
        SourceCategory(id: 'ertong', label: '儿童频道'),
        SourceCategory(id: 'gxjd', label: '国学经典'),
        SourceCategory(id: 'bxzt', label: '博闻杂谈'),
        SourceCategory(id: 'zcgh', label: '职场干货'),
        SourceCategory(id: 'mjcj', label: '名家传记'),
        SourceCategory(id: 'dajs', label: '档案纪实'),
        SourceCategory(id: 'xsqy', label: '相声曲艺'),
        SourceCategory(id: 'zwts', label: '自我提升'),
        SourceCategory(id: 'mxdt', label: '明星电台'),
      ];

  String _bookKey(String id) => '$_sourceId:$id';

  Book _bookFromId(String id, String title, String pic, String author) {
    return Book(
      bvid: _bookKey(id),
      aid: 0,
      title: title,
      pic: pic.isEmpty ? '' : (pic.startsWith('http') ? pic : '$_base$pic'),
      author: author,
      sourceId: _sourceId,
      sourceBookId: id,
    );
  }

  Map<String, String> _headers() => {
        'User-Agent': _ua,
        if (_cookie != null) 'Cookie': 'pt_guid=$_cookie',
      };

  Future<String> _fetch(String url, {String? referer}) async {
    final res = await _dio.get(
      url,
      options: Options(
        headers: {
          'User-Agent': _ua,
          'Referer': referer ?? _base,
          if (_cookie != null) 'Cookie': 'pt_guid=$_cookie',
        },
        responseType: ResponseType.plain,
      ),
    );
    return res.data.toString();
  }

  void _captureCookie(String html) {
    final m = RegExp(r"var token = '([^']+)'").firstMatch(html);
    if (m != null) {
      _cookie = m.group(1);
    }
  }

  @override
  Future<List<Book>> search(String keyword, {int page = 1, int pageSize = 20}) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return [];
    try {
      final res = await _dio.post(
        '$_base/search.html',
        data: {'searchword': kw},
        options: Options(
          headers: {
            'User-Agent': _ua,
            'Referer': _base,
            'Content-Type': 'application/x-www-form-urlencoded',
            if (_cookie != null) 'Cookie': 'pt_guid=$_cookie',
          },
        ),
      );
      final html = res.data.toString();
      if (html.contains('ptcms_guard_retry')) {
        _captureCookie(html);
        throw Exception('幻听网搜索触发防爬，请稍后再试');
      }
      return _parseBookList(html);
    } on DioException {
      throw Exception('搜索失败，请检查网络');
    }
  }

  @override
  Future<List<Book>> category(String catId, {int page = 1}) async {
    final url = page <= 1
        ? '$_base/book/$catId/lastupdate.html'
        : '$_base/book/$catId/lastupdate/$page.html';
    final html = await _fetch(url);
    if (html.contains('ptcms_guard_retry')) {
      _captureCookie(html);
      throw Exception('幻听网分类触发防爬，请稍后再试');
    }
    return _parseBookList(html);
  }

  @override
  Future<List<Book>> hot({int limit = 30}) async {
    final res = await _dio.get(
      '$_base/top/allvisit.html',
      options: Options(
        headers: {'User-Agent': _ua, 'Referer': _base},
        responseType: ResponseType.plain,
      ),
    );
    final html = res.data.toString();
    if (html.contains('ptcms_guard_retry')) {
      _captureCookie(html);
      throw Exception('幻听网排行触发防爬，请稍后再试');
    }
    return _parseBookList(html).take(limit).toList();
  }

  List<Book> _parseBookList(String html) {
    final books = <Book>[];
    final blockRegex = RegExp(
      r'<a[^>]*class="thumb"[^>]*href="(/book/(\d+)\.html)"[^>]*>.*?'
      r'<img[^>]*data-original="([^"]*)"[^>]*>.*?'
      r'<figcaption class="tab-book-title">\s*<a[^>]*>([^<]+)</a>\s*</figcaption>',
      dotAll: true,
    );
    for (final m in blockRegex.allMatches(html)) {
      final id = m.group(2)!;
      final pic = m.group(3)!.trim();
      final title = m.group(4)!.trim();
      if (title.isEmpty) continue;
      books.add(_bookFromId(id, title, pic, ''));
    }

    if (books.isEmpty) {
      final liRegex = RegExp(
        r'<li class="works-li">.*?'
        r'<a[^>]*href="(/book/(\d+)\.html)"[^>]*>.*?'
        r'<img[^>]*data-original="([^"]*)"[^>]*>.*?'
        r'<a href="/book/\d+\.html"[^>]*>([^<]+)</a>\s*</dt>',
        dotAll: true,
      );
      for (final m in liRegex.allMatches(html)) {
        final id = m.group(2)!;
        final pic = m.group(3)!.trim();
        final title = m.group(4)!.trim();
        if (title.isEmpty) continue;
        books.add(_bookFromId(id, title, pic, ''));
      }
    }

    if (books.isEmpty) {
      final simpleRegex = RegExp(
        r'<a href="/book/(\d+)\.html"[^>]*>([^<]{2,50})</a>',
      );
      final seen = <String>{};
      for (final m in simpleRegex.allMatches(html)) {
        final id = m.group(1)!;
        if (!seen.add(id)) continue;
        final title = m.group(2)!.trim();
        if (title.isEmpty) continue;
        books.add(_bookFromId(id, title, '', ''));
      }
    }
    return books;
  }

  @override
  Future<Book> detail(String sourceBookId) async {
    var html = await _fetch(
      '$_base/book/$sourceBookId.html',
      referer: _base,
    );

    if (html.contains('ptcms_guard_retry')) {
      _captureCookie(html);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (_cookie == null) {
        throw Exception('幻听网防爬限制，请稍后再试');
      }
      html = await _fetch(
        '$_base/book/$sourceBookId.html',
        referer: '$_base/book/$sourceBookId.html',
      );
      if (html.contains('ptcms_guard_retry')) {
        throw Exception('幻听网防爬限制，请稍后再试');
      }
    }

    final titleMatch =
        RegExp(r'<h1 class="book-title"[^>]*>\s*([^<]+?)\s*<').firstMatch(html);
    final title = titleMatch?.group(1)?.trim() ?? '未知书名';

    final picMatch = RegExp(
      r'data-original="(/public/cover/[^"]+)"',
    ).firstMatch(html) ??
        RegExp(r'<img[^>]*src="(/public/cover/[^"]+)"').firstMatch(html);
    final pic = picMatch?.group(1)?.trim() ?? '';

    final announcerMatch = RegExp(
      r'<span>演播：</span>\s*<a href="/boyin/[^"]+"[^>]*>([^<]+)</a>',
    ).firstMatch(html);
    final announcer = announcerMatch?.group(1)?.trim() ?? '';

    final descMatch = RegExp(
      r'<div class="book-des">\s*(.*?)\s*</div>',
      dotAll: true,
    ).firstMatch(html);
    var desc = descMatch?.group(1)?.trim() ?? '';
    desc = _stripHtmlTags(desc);

    final dirUrlMatch = RegExp(
      r'href="(/bookdir/[^"]+\.html)"',
    ).firstMatch(html);
    final dirPath = dirUrlMatch?.group(1)?.trim();

    final chapters = <Chapter>[];

    if (dirPath != null) {
      final dirHtml = await _fetchWithCookie(
        '$_base$dirPath',
        referer: '$_base/book/$sourceBookId.html',
      );
      chapters.addAll(_parseChapters(dirHtml, sourceBookId));
    }

    if (chapters.isEmpty) {
      chapters.addAll(_parseChapters(html, sourceBookId));
    }


    final book = Book(
      bvid: _bookKey(sourceBookId),
      aid: 0,
      title: title,
      pic: pic.isEmpty ? '' : '$_base$pic',
      author: '',
      upName: announcer,
      desc: desc,
      pages: chapters.length,
      sourceId: _sourceId,
      sourceBookId: sourceBookId,
      chapters: chapters,
    );
    return book;
  }

  Future<String> _fetchWithCookie(String url, {String? referer}) async {
    final res = await _dio.get(
      url,
      options: Options(
        headers: {
          'User-Agent': _ua,
          'Referer': referer ?? _base,
          if (_cookie != null) 'Cookie': 'pt_guid=$_cookie',
        },
        responseType: ResponseType.plain,
      ),
    );
    final html = res.data.toString();
    if (html.contains('ptcms_guard_retry')) {
      _captureCookie(html);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final retry = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': _ua,
            'Referer': referer ?? _base,
            'Cookie': 'pt_guid=$_cookie',
          },
          responseType: ResponseType.plain,
        ),
      );
      final retryHtml = retry.data.toString();
      if (retryHtml.contains('ptcms_guard_retry')) {
        throw Exception('幻听网防爬限制，请稍后再试');
      }
      return retryHtml;
    }
    return html;
  }

  List<Chapter> _parseChapters(String html, String sourceBookId) {
    final chapters = <Chapter>[];
    final escapedId = RegExp.escape(sourceBookId);
    final chapterRegex = RegExp(
      RegExp.escape('<a href="/tingshu/$escapedId/') +
          r'(\d+)\.html"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    for (final m in chapterRegex.allMatches(html)) {
      final cid = int.tryParse(m.group(1)!) ?? 0;
      var part = m.group(2)!.trim();
      part = _stripHtmlTags(part);
      chapters.add(Chapter(cid: cid, page: cid, part: part));
    }
    chapters.sort((a, b) => a.page.compareTo(b.page));
    return chapters;
  }

  @override
  Future<List<String>> audioUrls(String sourceBookId, int chapterId) async {
    final url = '$_base/tingshu/$sourceBookId/$chapterId.html';
    var html = await _fetchWithCookie(
      url,
      referer: '$_base/book/$sourceBookId.html',
    );

    final directAudio = RegExp(
      r'https?://[^\s\x22\x27<>]+\.(mp3|m4a|wav|ogg|flac)',
      caseSensitive: false,
    ).firstMatch(html);
    if (directAudio != null) {
      return [directAudio.group(0)!];
    }

    if (html.contains('ptcms_guard_retry') || html.contains('var reversed')) {
      throw Exception('幻听网播放页受防爬保护，无法获取音频');
    }

    final audioTagMatch =
        RegExp(r'<audio[^>]*src="([^"]+)"').firstMatch(html);
    if (audioTagMatch != null) {
      return [audioTagMatch.group(1)!];
    }

    final m3u8Match = RegExp(
      r'https?://[^\s\x22\x27<>]+\.m3u8',
      caseSensitive: false,
    ).firstMatch(html);
    if (m3u8Match != null) {
      return [m3u8Match.group(0)!];
    }

    throw Exception('未找到幻听网音频地址');
  }

  static String _stripHtmlTags(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }
}