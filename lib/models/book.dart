import 'chapter.dart';

class Book {
  final String bvid;
  final int aid;
  final String title;
  final String pic;
  final int pages;
  final int duration;
  final String author;
  final int mid;
  final String authorFace;
  final String desc;
  final int play;
  final int like;
  final int coin;
  final int favorite;
  final int pubdate;
  final String upName;
  final String sourceId;
  final String sourceBookId;

  final List<Chapter>? chapters;

  Book({
    required this.bvid,
    required this.aid,
    required this.title,
    required this.pic,
    this.pages = 1,
    this.duration = 0,
    this.author = '',
    this.mid = 0,
    this.authorFace = '',
    this.desc = '',
    this.play = 0,
    this.like = 0,
    this.coin = 0,
    this.favorite = 0,
    this.pubdate = 0,
    this.upName = '',
    this.sourceId = 'bili',
    this.sourceBookId = '',
    this.chapters,
  }) {
    assert(bvid.isNotEmpty, 'bvid (bookKey) must not be empty');
  }

  String get cleanTitle => title
      .replaceAll('<em class="keyword">', '')
      .replaceAll('</em>', '');

  static String normalizePic(String input) {
    final u = input.trim();
    if (u.isEmpty) return u;
    if (u.startsWith('//')) return 'https:$u';
    if (u.startsWith('http://')) return 'https://${u.substring(7)}';
    return u;
  }

  static int parseDurationSeconds(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = '$v'.trim();
    if (s.isEmpty) return 0;
    final parts = s.split(':');
    if (parts.length >= 2) {
      var total = 0;
      for (final p in parts) {
        total = total * 60 + (int.tryParse(p.trim()) ?? 0);
      }
      return total;
    }
    return int.tryParse(s) ?? 0;
  }

  String get durationText {
    if (duration <= 0) return '';
    final h = duration ~/ 3600;
    final m = (duration % 3600) ~/ 60;
    final s = duration % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  factory Book.fromSearch(Map<String, dynamic> m) {
    final bvid = m['bvid'] as String? ?? '';
    return Book(
      bvid: bvid,
      aid: int.tryParse('${m['aid'] ?? 0}') ?? 0,
      title: m['title'] as String? ?? '',
      pic: normalizePic(m['pic'] as String? ?? ''),
      pages: int.tryParse('${m['videos'] ?? 1}') ?? 1,
      duration: parseDurationSeconds(m['duration']),
      author: m['author'] as String? ?? '',
      mid: int.tryParse('${m['mid'] ?? 0}') ?? 0,
      play: int.tryParse('${m['play'] ?? 0}') ?? 0,
      pubdate: int.tryParse('${m['pubdate'] ?? 0}') ?? 0,
      desc: m['description'] as String? ?? '',
      sourceId: 'bili',
      sourceBookId: bvid,
    );
  }

  factory Book.fromView(Map<String, dynamic> m) {
    final owner = m['owner'] as Map? ?? {};
    final stat = m['stat'] as Map? ?? {};
    final pages = m['pages'] as List? ?? [];
    final bvid = m['bvid'] as String? ?? '';
    return Book(
      bvid: bvid,
      aid: int.tryParse('${m['aid'] ?? 0}') ?? 0,
      title: m['title'] as String? ?? '',
      pic: normalizePic(m['pic'] as String? ?? ''),
      pages: pages.isEmpty ? 1 : pages.length,
      duration: int.tryParse('${m['duration'] ?? 0}') ?? 0,
      author: owner['name'] as String? ?? '',
      mid: int.tryParse('${owner['mid'] ?? 0}') ?? 0,
      authorFace: owner['face'] as String? ?? '',
      desc: m['desc'] as String? ?? '',
      play: int.tryParse('${stat['view'] ?? 0}') ?? 0,
      like: int.tryParse('${stat['like'] ?? 0}') ?? 0,
      coin: int.tryParse('${stat['coin'] ?? 0}') ?? 0,
      favorite: int.tryParse('${stat['favorite'] ?? 0}') ?? 0,
      pubdate: int.tryParse('${m['pubdate'] ?? 0}') ?? 0,
      upName: owner['name'] as String? ?? '',
      sourceId: 'bili',
      sourceBookId: bvid,
      chapters: pages
          .map((e) => Chapter.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'bvid': bvid,
        'aid': aid,
        'title': cleanTitle,
        'pic': pic,
        'pages': pages,
        'duration': duration,
        'author': author,
        'mid': mid,
        'authorFace': authorFace,
        'desc': desc,
        'play': play,
        'sourceId': sourceId,
        'sourceBookId': sourceBookId,
      };

  factory Book.fromJson(Map<String, dynamic> m) {
    final bvid = m['bvid'] as String? ?? '';
    final sourceId = m['sourceId'] as String? ?? 'bili';
    final sourceBookId = m['sourceBookId'] as String? ?? bvid;
    return Book(
      bvid: bvid,
      aid: int.tryParse('${m['aid'] ?? 0}') ?? 0,
      title: m['title'] as String? ?? '',
      pic: normalizePic(m['pic'] as String? ?? ''),
      pages: int.tryParse('${m['pages'] ?? 1}') ?? 1,
      duration: int.tryParse('${m['duration'] ?? 0}') ?? 0,
      author: m['author'] as String? ?? '',
      mid: int.tryParse('${m['mid'] ?? 0}') ?? 0,
      authorFace: m['authorFace'] as String? ?? '',
      desc: m['desc'] as String? ?? '',
      play: int.tryParse('${m['play'] ?? 0}') ?? 0,
      sourceId: sourceId,
      sourceBookId: sourceBookId,
    );
  }
}