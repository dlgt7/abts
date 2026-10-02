import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/stream/chacha20poly1305.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';

import '../core/source/book_source.dart';
import '../models/book.dart';
import '../models/chapter.dart';

class TingyouSource implements BookSource {
  @override
  String get id => 'tingyou';

  @override
  String get name => '听友';

  @override
  String get description => 'tingyou.fm 有声书';

  static const _apiBase = 'https://tingyou.fm/api/';
  static const _referer = 'https://tingyou.fm/';
  static const _origin = 'https://tingyou.fm';
  static const _sourceId = 'tingyou';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  static const _jsonUrls = [
    'https://json.hgeuz.cn/tyfm/json_v1',
    'https://json.fmfm.pro/tyfm/json_v1',
    'https://json.tingyou8.vip/tyfm/json_v1',
  ];
  static final _cryptoKey =
      _hexDecode('ea9d9d4f9a983fe6f6382f29c7b46b8d6dc47abc6da36662e6ddff8c78902f65');
  static const _sigma = [0x61707865, 0x3320646e, 0x79622d32, 0x6b206574];
  static const _cacheTtlMs = 30 * 60 * 1000;

  late final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    responseType: ResponseType.plain,
  ));

  String? _dfp;
  bool _initialized = false;
  Future<void>? _initFuture;
  final Map<String, ({Book book, int ts})> _detailCache = {};

  @override
  List<SourceCategory> get categories => const [
        SourceCategory(id: '46', label: '玄幻奇幻'),
        SourceCategory(id: '11', label: '武侠小说'),
        SourceCategory(id: '19', label: '言情通俗'),
        SourceCategory(id: '21', label: '相声小品'),
        SourceCategory(id: '14', label: '恐怖惊悚'),
        SourceCategory(id: '17', label: '官场商战'),
        SourceCategory(id: '15', label: '历史军事'),
        SourceCategory(id: '9', label: '百家讲坛'),
        SourceCategory(id: '16', label: '刑侦反腐'),
        SourceCategory(id: '10', label: '有声文学'),
        SourceCategory(id: '18', label: '人物纪实'),
        SourceCategory(id: '36', label: '广播剧'),
        SourceCategory(id: '22', label: '英文读物'),
        SourceCategory(id: '23', label: '轻音清心'),
        SourceCategory(id: '31', label: '二人转'),
        SourceCategory(id: '33', label: '健康养生'),
        SourceCategory(id: '34', label: '综艺娱乐'),
        SourceCategory(id: '40', label: '头条'),
        SourceCategory(id: '38', label: '戏曲'),
        SourceCategory(id: '41', label: '脱口秀'),
        SourceCategory(id: '42', label: '商业财经'),
        SourceCategory(id: '43', label: '亲子教育'),
        SourceCategory(id: '44', label: '教育培训'),
        SourceCategory(id: '45', label: '时尚生活'),
        SourceCategory(id: '20', label: '童话寓言'),
        SourceCategory(id: '47', label: '未分类'),
        SourceCategory(id: '1', label: '单田芳'),
        SourceCategory(id: '2', label: '刘兰芳'),
        SourceCategory(id: '3', label: '田连元'),
        SourceCategory(id: '4', label: '袁阔成'),
        SourceCategory(id: '5', label: '连丽如'),
        SourceCategory(id: '8', label: '孙一'),
        SourceCategory(id: '30', label: '王子封臣'),
        SourceCategory(id: '25', label: '马长辉'),
        SourceCategory(id: '26', label: '昊儒书场'),
        SourceCategory(id: '27', label: '王军'),
        SourceCategory(id: '28', label: '王玥波'),
        SourceCategory(id: '29', label: '石连君'),
        SourceCategory(id: '12', label: '粤语评书'),
        SourceCategory(id: '35', label: '关永超'),
        SourceCategory(id: '6', label: '张少佐'),
        SourceCategory(id: '7', label: '田战义'),
        SourceCategory(id: '13', label: '其他评书'),
      ];

  static Uint8List _hexDecode(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static String _hexEncode(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write((b & 0xff).toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static int _rotl(int v, int c) => ((v << c) | (v >>> (32 - c))) & 0xffffffff;

  static int _le(Uint8List b, int off) =>
      (b[off] & 0xff) |
      ((b[off + 1] & 0xff) << 8) |
      ((b[off + 2] & 0xff) << 16) |
      ((b[off + 3] & 0xff) << 24);

  static void _writeLe(Uint8List b, int off, int v) {
    b[off] = v & 0xff;
    b[off + 1] = (v >>> 8) & 0xff;
    b[off + 2] = (v >>> 16) & 0xff;
    b[off + 3] = (v >>> 24) & 0xff;
  }

  static void _qr(List<int> s, int a, int b, int c, int d) {
    s[a] = (s[a] + s[b]) & 0xffffffff;
    s[d] = _rotl(s[a] ^ s[d], 16);
    s[c] = (s[c] + s[d]) & 0xffffffff;
    s[b] = _rotl(s[c] ^ s[b], 12);
    s[a] = (s[a] + s[b]) & 0xffffffff;
    s[d] = _rotl(s[a] ^ s[d], 8);
    s[c] = (s[c] + s[d]) & 0xffffffff;
    s[b] = _rotl(s[c] ^ s[b], 7);
  }

  static Uint8List _hChaCha20(Uint8List key, Uint8List nonce16) {
    final s = List<int>.filled(16, 0);
    for (var i = 0; i < 4; i++) {
      s[i] = _sigma[i];
    }
    for (var i = 0; i < 8; i++) {
      s[4 + i] = _le(key, i * 4);
    }
    for (var i = 0; i < 4; i++) {
      s[12 + i] = _le(nonce16, i * 4);
    }
    for (var r = 0; r < 10; r++) {
      _qr(s, 0, 4, 8, 12);
      _qr(s, 1, 5, 9, 13);
      _qr(s, 2, 6, 10, 14);
      _qr(s, 3, 7, 11, 15);
      _qr(s, 0, 5, 10, 15);
      _qr(s, 1, 6, 11, 12);
      _qr(s, 2, 7, 8, 13);
      _qr(s, 3, 4, 9, 14);
    }
    final out = Uint8List(32);
    for (var i = 0; i < 4; i++) {
      _writeLe(out, i * 4, s[i]);
    }
    for (var i = 0; i < 4; i++) {
      _writeLe(out, 16 + i * 4, s[12 + i]);
    }
    return out;
  }

  String _decryptPayload(String hexStr) {
    final data = _hexDecode(hexStr);
    if (data.length < 41) throw Exception('payload too short');
    final version = data[0];
    final nonce24 = Uint8List.fromList(data.sublist(1, 25));
    var ciphertext = Uint8List.fromList(data.sublist(25));
    if (version == 2) ciphertext = Uint8List.fromList(ciphertext.reversed.toList());
    final subKey = _hChaCha20(_cryptoKey, Uint8List.fromList(nonce24.sublist(0, 16)));
    final aeadNonce = Uint8List(12);
    aeadNonce.setRange(4, 12, nonce24.sublist(16, 24));
    final cipher = ChaCha20Poly1305();
    cipher.init(false, AEADParameters(KeyParameter(subKey), 128, aeadNonce, Uint8List(0)));
    final out = Uint8List(cipher.getOutputSize(ciphertext.length));
    var off = cipher.processBytes(ciphertext, 0, ciphertext.length, out, 0);
    off += cipher.doFinal(out, off);
    return utf8.decode(out.sublist(0, off));
  }

  String _encryptPayload(String plain) {
    final iv = Uint8List.fromList(
        List.generate(12, (_) => Random.secure().nextInt(256)));
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(true, AEADParameters(KeyParameter(_cryptoKey), 128, iv, Uint8List(0)));
    final bytes = utf8.encode(plain);
    final out = Uint8List(cipher.getOutputSize(bytes.length));
    var off = cipher.processBytes(bytes, 0, bytes.length, out, 0);
    off += cipher.doFinal(out, off);
    final result = Uint8List(1 + 12 + off);
    result[0] = 1;
    result.setRange(1, 13, iv);
    result.setRange(13, 13 + off, out.sublist(0, off));
    return _hexEncode(result);
  }

  String _generateDfp() {
    final now = DateTime.now();
    final ts =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    var n = BigInt.parse(ts);
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    var b36 = '';
    while (n > BigInt.zero) {
      b36 = chars[n.remainder(BigInt.from(36)).toInt()] + b36;
      n = n ~/ BigInt.from(36);
    }
    final rand = Uint8List.fromList(
        List.generate(48, (_) => Random.secure().nextInt(256)));
    return 'f-$b36:f-${base64.encode(rand)}';
  }

  Map<String, String> _headers() => {
        'User-Agent': _ua,
        'Referer': _referer,
        'Origin': _origin,
        'Content-Type': 'text/plain',
        'X-Payload-Version': '1',
      };

  Future<void> _ensureInit() {
    if (_initialized) return Future.value();
    _initFuture ??= () async {
      _dfp = _generateDfp();
      await _apiRequest('me', {});
      _initialized = true;
    }();
    return _initFuture!;
  }

  Future<Map<String, dynamic>> _apiRequest(
      String path, Map<String, dynamic> body) async {
    final encrypted = _encryptPayload(jsonEncode(body));
    final headers = _headers();
    if (_dfp != null) headers['Cookie'] = 'dfp=$_dfp';
    final resp = await _dio.post(
      '$_apiBase$path',
      data: encrypted,
      options: Options(headers: headers, responseType: ResponseType.plain),
    );
    final text = (resp.data ?? '').toString();
    if (text.isEmpty) return {};
    final json = jsonDecode(text) as Map<String, dynamic>;
    if (json['payload'] == null) return json;
    return jsonDecode(_decryptPayload(json['payload'] as String))
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _fetchStaticJson(String path) async {
    Exception? lastError;
    for (final base in _jsonUrls) {
      try {
        final resp = await _dio.get(
          '$base/$path',
          options: Options(
            headers: {'User-Agent': _ua, 'Referer': _referer},
            responseType: ResponseType.plain,
          ),
        );
        final text = (resp.data ?? '').toString();
        if (text.isNotEmpty) {
          final json = jsonDecode(text) as Map<String, dynamic>;
          if (json['payload'] != null) {
            return jsonDecode(_decryptPayload(json['payload'] as String))
                as Map<String, dynamic>;
          }
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
      }
    }
    throw lastError ?? Exception('staticJson empty: $path');
  }

  String _bookKey(String id) => '$_sourceId:$id';

  Book _bookFromItem(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final status = item['status'] == 1 ? '完结' : '连载';
    final count = item['count'] as int? ?? 0;
    final remarks = count > 0 ? '$count集 · $status' : status;
    return Book(
      bvid: _bookKey(id),
      aid: 0,
      title: item['title'] as String? ?? '',
      pic: Book.normalizePic(item['cover_url'] as String? ?? ''),
      desc: remarks,
      sourceId: _sourceId,
      sourceBookId: id,
    );
  }

  List<Book> _parseList(List? arr) {
    final list = <Book>[];
    if (arr == null) return list;
    for (final e in arr) {
      if (e is Map) list.add(_bookFromItem(e.cast<String, dynamic>()));
    }
    return list;
  }

  @override
  Future<List<Book>> search(String keyword,
      {int page = 1, int pageSize = 20}) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return [];
    try {
      final resp = await _apiRequest('search', {'keyword': kw, 'page': page});
      return _parseList(resp['results'] as List?);
    } catch (_) {
      throw Exception('听友搜索失败，请检查网络');
    }
  }

  @override
  Future<List<Book>> category(String catId, {int page = 1}) async {
    try {
      final json =
          await _fetchStaticJson('types/$catId/0/comprehensive/p$page');
      return _parseList(json['data'] as List?);
    } catch (_) {
      throw Exception('分类加载失败，请检查网络');
    }
  }

  @override
  Future<List<Book>> hot({int limit = 30}) async {
    try {
      final json = await _fetchStaticJson('homepage');
      final list =
          json['recommends'] as List? ?? json['recent_updates'] as List?;
      return _parseList(list).take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Book> detail(String sourceBookId) async {
    final cached = _detailCache[sourceBookId];
    if (cached != null &&
        DateTime.now().millisecondsSinceEpoch - cached.ts < _cacheTtlMs) {
      return cached.book;
    }
    final info = await _fetchStaticJson('album_info/$sourceBookId');
    final chaptersJson =
        await _fetchStaticJson('album_chapters/$sourceBookId');
    final chaptersArr = chaptersJson['chapters'] as List? ?? [];
    final chapters = <Chapter>[];
    for (var i = 0; i < chaptersArr.length; i++) {
      final ch = (chaptersArr[i] as Map).cast<String, dynamic>();
      final index = ch['index'] as int? ?? (i + 1);
      var title = ch['title'] as String? ?? '';
      if (title.isEmpty) title = index.toString().padLeft(3, '0');
      chapters.add(Chapter(cid: index, page: i + 1, part: title));
    }
    final book = Book(
      bvid: _bookKey(sourceBookId),
      aid: 0,
      title: info['title'] as String? ?? '',
      pic: Book.normalizePic(info['cover_url'] as String? ?? ''),
      author: info['author'] as String? ?? '',
      upName: info['teller'] as String? ?? '',
      desc: info['synopsis'] as String? ?? info['description'] as String? ?? '',
      sourceId: _sourceId,
      sourceBookId: sourceBookId,
      pages: chapters.length,
      chapters: chapters,
    );
    _detailCache[sourceBookId] =
        (book: book, ts: DateTime.now().millisecondsSinceEpoch);
    return book;
  }

  @override
  Future<List<String>> audioUrls(String sourceBookId, int chapterId) async {
    await _ensureInit();
    final albumId = int.tryParse(sourceBookId);
    if (albumId == null) throw Exception('听友 bookId 无效');
    try {
      final resp = await _apiRequest(
          'play_token', {'album_id': albumId, 'chapter_idx': chapterId});
      final url = resp['play_url'] as String? ?? resp['url'] as String? ?? '';
      if (url.isEmpty) {
        throw Exception(resp['detail'] as String? ?? '未找到音频地址');
      }
      return [url];
    } catch (e) {
      throw Exception('听友播放失败: $e');
    }
  }
}