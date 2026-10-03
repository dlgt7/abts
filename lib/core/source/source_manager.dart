import 'package:shared_preferences/shared_preferences.dart';

import 'book_source.dart';

class SourceManager {
  SourceManager._();
  static final SourceManager instance = SourceManager._();

  final Map<String, BookSource> _sources = {};
  String _currentId = 'bili';
  List<String> _enabledIds = ['bili'];

  static const _prefCurrent = 'abts_current_source';
  static const _prefEnabled = 'abts_enabled_sources';
  static const _prefCustom = 'abts_custom_sources';

  void register(BookSource source) {
    _sources[source.id] = source;
  }

  void unregister(String id) {
    if (id == 'bili') return;
    _sources.remove(id);
    _enabledIds.remove(id);
    if (_currentId == id) _currentId = 'bili';
  }

  bool get isCurrentCustom => _currentId != 'bili' && !const ['ting15', 'psmp3', 'tingyou'].contains(_currentId);

  BookSource get(String id) {
    final s = _sources[id];
    if (s == null) {
      throw StateError('未知书源: $id');
    }
    return s;
  }

  BookSource get current => _sources[_currentId] ?? _sources['bili']!;
  String get currentId => _currentId;
  List<BookSource> get all => _sources.values.toList();
  bool isRegistered(String id) => _sources.containsKey(id);

  List<BookSource> get enabled =>
      _enabledIds.map((id) => _sources[id]).whereType<BookSource>().toList();

  BookSource? findByUrl(String url) {
    if (url.isEmpty) return null;
    final lower = url.toLowerCase();
    BookSource? fallback;
    for (final s in enabled) {
      final b = s.baseUrl;
      if (b == null || b.isEmpty) continue;
      if (lower.startsWith(b.toLowerCase())) return s;
      fallback ??= s;
    }
    return fallback;
  }

  bool isEnabled(String id) => _enabledIds.contains(id);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final cur = prefs.getString(_prefCurrent);
    if (cur != null && _sources.containsKey(cur)) {
      _currentId = cur;
    }
    final en = prefs.getStringList(_prefEnabled);
    if (en != null) {
      _enabledIds = en.where((id) => _sources.containsKey(id)).toList();
    }
    if (!_enabledIds.contains('bili')) {
      _enabledIds.insert(0, 'bili');
    }
    if (!_enabledIds.contains(_currentId)) {
      _currentId = 'bili';
    }
  }

  Future<void> setCurrent(String id) async {
    if (!_sources.containsKey(id)) return;
    _currentId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCurrent, id);
  }

  Future<void> setEnabled(String id, bool enabled) async {
    if (id == 'bili') return;
    if (enabled) {
      if (!_enabledIds.contains(id)) _enabledIds.add(id);
    } else {
      _enabledIds.remove(id);
      if (_currentId == id) _currentId = 'bili';
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefEnabled, _enabledIds);
  }

  Future<String> loadCustomConfigsJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefCustom) ?? '[]';
  }

  Future<void> saveCustomConfigsJson(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefCustom, json);
  }
}