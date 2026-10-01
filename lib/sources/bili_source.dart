import '../core/source/book_source.dart';
import '../models/audio_stream.dart';
import '../models/book.dart';
import '../services/bili_api.dart';

class BiliSource implements BookSource {
  @override
  String get id => 'bili';

  @override
  String get name => 'B站听书';

  @override
  String get description => '哔哩哔哩有声小说';

  final _api = BiliApi.instance;

  @override
  Future<List<Book>> search(String keyword, {int page = 1, int pageSize = 20}) {
    return _api.search(keyword, page: page, pageSize: pageSize);
  }

  @override
  Future<Book> detail(String sourceBookId) => _api.detail(sourceBookId);

  @override
  Future<List<String>> audioUrls(String sourceBookId, int chapterId) async {
    final audio = await _api.playUrl(sourceBookId, chapterId);
    return extractAudioUrls(audio);
  }

  @override
  Future<List<Book>> hot({int limit = 30}) => _api.rankHotNovel(limit: limit);

  @override
  List<SourceCategory> get categories => const [];

  @override
  Future<List<Book>> category(String catId, {int page = 1}) async => [];

  static List<String> extractAudioUrls(BookAudio audio) {
    final list = <String>[];
    void add(AudioTrack? t) {
      if (t == null) return;
      String toHttps(String u) =>
          u.startsWith('http://') ? 'https://${u.substring(7)}' : u;
      if (t.baseUrl.isNotEmpty) list.add(toHttps(t.baseUrl));
      for (final b in t.backupUrls) {
        if (b.isNotEmpty) list.add(toHttps(b));
      }
    }

    final aac = [...audio.tracks]
      ..sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
    for (final t in aac) {
      add(t);
    }
    add(audio.flac);
    add(audio.dolby);
    return list.toSet().toList();
  }
}