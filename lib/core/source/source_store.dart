import 'package:flutter/foundation.dart';

import 'source_manager.dart';
import 'book_source.dart';

class SourceStore extends ChangeNotifier {
  SourceStore._();
  static final SourceStore instance = SourceStore._();

  final _mgr = SourceManager.instance;

  BookSource get current => _mgr.current;
  String get currentId => _mgr.currentId;
  List<BookSource> get all => _mgr.all;
  List<BookSource> get enabled => _mgr.enabled;
  bool isEnabled(String id) => _mgr.isEnabled(id);
  bool isRegistered(String id) => _mgr.isRegistered(id);
  BookSource get(String id) => _mgr.get(id);

  Future<void> load() async {
    await _mgr.load();
    notifyListeners();
  }

  Future<void> setCurrent(String id) async {
    await _mgr.setCurrent(id);
    notifyListeners();
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await _mgr.setEnabled(id, enabled);
    notifyListeners();
  }
}