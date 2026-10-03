import 'package:dio/dio.dart';

import '../../core/network/http_factory.dart';
import '../../models/book.dart';
import '../../models/chapter.dart';
import 'audio_extractor.dart';
import 'book_source.dart';
import 'local_source_config.dart';

class LocalBookSource implements BookSource {
  final LocalSourceConfig config;

  LocalBookSource(this.config);

  @override
  String get id => config.id;

  @override
  String get name => config.name;

  @override
  String? get baseUrl => config.baseUrl;

  @override
  String get description => config.description;

  @override
  List<SourceCategory> get categories => config.categories
      .map((c) => SourceCategory(id: c.id, label: c.label))
      .toList();

  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  late final Dio _dio = createDio(userAgent: config.userAgent ?? _ua);

  Map<String, String> _headers({String referer = ''}) => {
        'User-Agent': config.userAgent ?? _ua,
        if (referer.isNotEmpty) 'Referer': referer,
      };

  String _fill(String tpl, Map<String, String> vars) {
    var s = tpl;
    vars.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  String _fullUrl(String path) {
    if (path.startsWith('http')) return path;
    return config.baseUrl + path;
  }

  Book _bookFromMatch(String bookId, String title, String pic, String author,
      String announcer) {
    return Book(
      bvid: '${config.id}:$bookId',
      aid: 0,
      title: title,
      pic: pic.isEmpty ? '' : Book.normalizePic(pic),
      author: author,
      upName: announcer,
      sourceId: config.id,
      sourceBookId: bookId,
    );
  }

  List<Book> _parseList(String html) {
    final lp = config.listParse;
    final itemRegex = lp.item.regex;
    if (itemRegex == null) return [];
    final books = <Book>[];
    for (final m in itemRegex.allMatches(html)) {
      final bookId = m.group(lp.bookId?.group ?? 1)?.trim() ?? '';
      final title = m.group(lp.title?.group ?? 2)?.trim() ?? '';
      if (bookId.isEmpty || title.isEmpty) continue;
      final block = html.substring(m.start, m.end);
      final pic = _subMatch(block, lp.pic);
      final author = _subMatch(block, lp.author);
      final announcer = _subMatch(block, lp.announcer);
      books.add(_bookFromMatch(bookId, title, pic, author, announcer));
    }
    return books;
  }

  String _subMatch(String text, RegexFieldConfig? field) {
    if (field == null) return '';
    final r = field.regex;
    if (r == null) return '';
    final m = r.firstMatch(text);
    return m?.group(field.group)?.trim() ?? '';
  }

  @override
  Future<List<Book>> search(String keyword, {int page = 1, int pageSize = 20}) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return [];
    final path = _fill(config.searchPath, {
      'kw': Uri.encodeComponent(kw),
      'page': '$page',
    });
    final res = await _dio.get(
      _fullUrl(path),
      options: Options(headers: _headers(referer: config.baseUrl)),
    );
    return _parseList(res.data.toString());
  }

  @override
  Future<List<Book>> category(String catId, {int page = 1}) async {
    final tpl = page > 1
        ? (config.categoryPagePath ?? config.categoryPath)
        : config.categoryPath;
    final path = _fill(tpl, {
      'catId': catId,
      'page': '$page',
    });
    final res = await _dio.get(
      _fullUrl(path),
      options: Options(headers: _headers(referer: config.baseUrl)),
    );
    return _parseList(res.data.toString());
  }

  @override
  Future<List<Book>> hot({int limit = 30}) async {
    if (config.categories.isEmpty) return [];
    return category(config.categories.first.id, page: 1).then(
      (list) => list.take(limit).toList(),
    );
  }

  @override
  Future<Book> detail(String sourceBookId) async {
    final path = _fill(config.detailPath, {'bookId': sourceBookId});
    final url = _fullUrl(path);
    final res = await _dio.get(
      url,
      options: Options(headers: _headers(referer: config.baseUrl)),
    );
    final html = res.data.toString();

    final title = _subMatch(html, config.detailTitle);
    final pic = _subMatch(html, config.detailPic);
    final author = _subMatch(html, config.detailAuthor);
    final announcer = _subMatch(html, config.detailAnnouncer);
    final desc = _subMatch(html, config.detailDesc);

    final chapters = <Chapter>[];
    final cp = config.chapterParse;
    final itemPattern = cp.item.pattern.replaceAll('{bookId}', sourceBookId);
    final itemRegex = RegExp(itemPattern, dotAll: true);
    for (final m in itemRegex.allMatches(html)) {
      final cidStr = m.group(cp.bookId?.group ?? 1)?.trim() ?? '';
      final part = m.group(cp.title?.group ?? 2)?.trim() ?? '';
      final cid = int.tryParse(cidStr) ?? chapters.length + 1;
      chapters.add(Chapter(cid: cid, page: chapters.length + 1, part: part));
    }

    return Book(
      bvid: '${config.id}:$sourceBookId',
      aid: 0,
      title: title.isEmpty ? sourceBookId : title,
      pic: pic.isEmpty ? '' : Book.normalizePic(pic),
      author: author,
      upName: announcer,
      desc: desc,
      pages: chapters.length,
      sourceId: config.id,
      sourceBookId: sourceBookId,
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> audioUrls(String sourceBookId, int chapterId) async {
    final extractor =
        AudioExtractorRegistry.instance.create(config.audioExtractor);
    if (extractor == null) {
      throw Exception('未知音频提取器: ${config.audioExtractor}');
    }
    return extractor.extract(AudioContext(
      dio: _dio,
      baseUrl: config.baseUrl,
      sourceBookId: sourceBookId,
      chapterId: chapterId,
      config: config.audioConfig,
      headers: _headers(),
    ));
  }
}