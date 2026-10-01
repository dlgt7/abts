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

  void register(BookSource source) {
    _sources[source.id] = source;
  }

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
}