import 'package:dio/dio.dart';

import '../core/source/book_source.dart';
import '../models/book.dart';
import '../models/chapter.dart';

class Ting8Source implements BookSource {
  @override
  String get id => 'ting8';

  @override
  String get name => '听书吧';

  @override
  String get description => 'ting8.cc 免费有声小说';

  static const _base = 'https://www.ting8.cc';
  static const _sourceId = 'ting8';

  static const _ua =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  late final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 30),
    responseType: ResponseType.plain,
  ));

  Map<String, String> _headers({String? referer}) => {
        'User-Agent': _ua,
        'Referer': referer ?? _base,
      };

  @override
  List<SourceCategory> get categories => const [
        SourceCategory(id: '1', label: '玄幻'),
        SourceCategory(id: '2', label: '言情'),
        SourceCategory(id: '3', label: '都市'),
        SourceCategory(id: '4', label: '恐怖'),
        SourceCategory(id: '5', label: '惊悚'),
        SourceCategory(id: '6', label: '推理'),
        SourceCategory(id: '7', label: '武侠'),
        SourceCategory(id: '8', label: '历史'),
        SourceCategory(id: '9', label: '军事'),
        SourceCategory(id: '10', label: '穿越'),
        SourceCategory(id: '11', label: '科幻'),
        SourceCategory(id: '12', label: '网游'),
        SourceCategory(id: '13', label: '评书'),
        SourceCategory(id: '16', label: '儿童'),
        SourceCategory(id: '18', label: '广播'),
        SourceCategory(id: '20', label: '文学'),
        SourceCategory(id: '22', label: '经典'),
        SourceCategory(id: '23', label: '相声小品'),
        SourceCategory(id: '24', label: '百家讲坛'),
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

  @override
  Future<List<Book>> search(String keyword, {int page = 1, int pageSize = 20}) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return [];
    try {
      await _dio.get(_base, options: Options(headers: _headers()));
      final res = await _dio.get(
        '$_base/search.php',
        queryParameters: {'searchword': kw},
        options: Options(headers: _headers(_base)),
      );
      final html = res.data.toString();
      if (html.contains('安全验证') || html.contains('验证码')) {
        throw Exception('听书吧搜索触发验证码，请稍后再试或使用分类浏览');
      }
      return _parseCategoryList(html);
    } on DioException catch (_) {
      throw Exception('搜索失败，请检查网络');
    }
  }

  @override
  Future<List<Book>> category(String catId, {int page = 1}) async {
    final url = page <= 1
        ? '$_base/books/$catId.html'
        : '$_base/books/$catId-$page.html';
    final res = await _dio.get(
      url,
      options: Options(headers: _headers(url)),
    );
    return _parseCategoryList(res.data.toString());
  }

  @override
  Future<List<Book>> hot({int limit = 30}) async {
    final all = <Book>[];
    for (var p = 1; p <= 2 && all.length < limit; p++) {
      try {
        final list = await category('1', page: p);
        all.addAll(list);
        if (list.isEmpty) break;
      } catch (_) {
        break;
      }
    }
    return all.take(limit).toList();
  }

  List<Book> _parseCategoryList(String html) {
    final books = <Book>[];
    final liRegex = RegExp(
      r'<li[^>]*>\s*'
      r'<div[^>]*class="style-img[^"]*"[^>]*>\s*'
      r'<a[^>]*class="img-80[^"]*"[^>]*href="(/mp3/(\d+)\.html)"[^>]*>\s*'
      r'<span[^>]*>\s*'
      r'<img src="([^"]+)"[^>]*>\s*</span>\s*</a>\s*'
      r'<section>\s*'
      r'<h2[^>]*>\s*'
      r'<span[^>]*>\s*<i[^>]*></i>\s*([^<]+)</span>\s*'
      r'<a[^>]*class="f-bold"[^>]*>([^<]+)</a>',
      dotAll: true,
    );
    for (final m in liRegex.allMatches(html)) {
      final id = m.group(2)!;
      final pic = m.group(3)!.trim();
      final author = m.group(4)!.trim();
      final title = m.group(5)!.trim();
      if (title.isEmpty || id.isEmpty) continue;
      books.add(_bookFromId(id, title, pic, author));
    }
    return books;
  }

  @override
  Future<Book> detail(String sourceBookId) async {
    final res = await _dio.get(
      '$_base/mp3/$sourceBookId.html',
      options: Options(headers: _headers('$_base/books/1.html')),
    );
    final html = res.data.toString();

    final titleMatch =
        RegExp(r'<h1 class="style-title[^"]*">([^<]+)</h1>').firstMatch(html);
    final title = titleMatch?.group(1)?.trim() ?? '未知书名';

    final picMatch = RegExp(
      r'<div class="img-100[^"]*"[^>]*>.*?<img src="([^"]+)"',
      dotAll: true,
    ).firstMatch(html);
    final pic = picMatch?.group(1)?.trim() ?? '';

    final authorMatch = RegExp(
      r'作者：<a[^>]*>([^<]+)</a>',
    ).firstMatch(html);
    final author = authorMatch?.group(1)?.trim() ?? '';

    final announcerMatch = RegExp(
      r'由<a[^>]*>([^<]+)</a>\s*播音',
    ).firstMatch(html);
    final announcer = announcerMatch?.group(1)?.trim() ?? '';

    final descMatch = RegExp(r'内容介绍：([^<]+)').firstMatch(html);
    final desc = descMatch?.group(1)?.trim() ?? '';

    final chapters = <Chapter>[];
    final chapterRegex = RegExp(
      r'<a href="/play/\d+-0-(\d+)\.html"[^>]*>([^<]+)</a>',
      dotAll: true,
    );
    for (final m in chapterRegex.allMatches(html)) {
      final part = int.tryParse(m.group(1)!) ?? 0;
      final partTitle = m.group(2)!.trim();
      chapters.add(Chapter(
        cid: part,
        page: part + 1,
        part: partTitle,
      ));
    }

    return Book(
      bvid: _bookKey(sourceBookId),
      aid: 0,
      title: title,
      pic: pic.isEmpty ? '' : (pic.startsWith('http') ? pic : '$_base$pic'),
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
    final res = await _dio.get(
      '$_base/play/$sourceBookId-0-$chapterId.html',
      options: Options(headers: _headers('$_base/mp3/$sourceBookId.html')),
    );
    final html = res.data.toString();
    final audioMatch = RegExp(r'var now="([^"]+)"').firstMatch(html);
    final url = audioMatch?.group(1)?.trim();
    if (url == null || url.isEmpty) {
      throw Exception('未找到音频直链');
    }
    final urls = <String>[url];
    final nextMatch = RegExp(r'var next="([^"]+)"').firstMatch(html);
    final nextUrl = nextMatch?.group(1)?.trim();
    if (nextUrl != null && nextUrl.isNotEmpty) {
      urls.add(nextUrl);
    }
    return urls;
  }
}