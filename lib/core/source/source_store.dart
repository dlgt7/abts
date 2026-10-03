import 'package:flutter/foundation.dart';

import 'local_book_source.dart';
import 'local_source_config.dart';
import 'source_manager.dart';
import 'book_source.dart';

class SourceStore extends ChangeNotifier {
  SourceStore._();
  static final SourceStore instance = SourceStore._();

  final _mgr = SourceManager.instance;
  List<LocalSourceConfig> _customConfigs = [];

  BookSource get current => _mgr.current;
  String get currentId => _mgr.currentId;
  List<BookSource> get all => _mgr.all;
  List<BookSource> get enabled => _mgr.enabled;
  bool isEnabled(String id) => _mgr.isEnabled(id);
  bool isRegistered(String id) => _mgr.isRegistered(id);
  BookSource get(String id) => _mgr.get(id);

  List<LocalSourceConfig> get customConfigs => List.unmodifiable(_customConfigs);
  bool isCustom(String id) => _customConfigs.any((c) => c.id == id);
  bool get isCurrentCustom => _mgr.isCurrentCustom;

  Future<void> load() async {
    await _mgr.load();
    await _loadCustomConfigs();
    notifyListeners();
  }

  Future<void> _loadCustomConfigs() async {
    try {
      final json = await _mgr.loadCustomConfigsJson();
      _customConfigs = LocalSourceConfig.fromJsonList(json);
      for (final cfg in _customConfigs) {
        if (!_mgr.isRegistered(cfg.id)) {
          _mgr.register(LocalBookSource(cfg));
        }
      }
    } catch (e) {
      debugPrint('[SourceStore] load custom failed: $e');
    }
  }

  Future<void> setCurrent(String id) async {
    await _mgr.setCurrent(id);
    notifyListeners();
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await _mgr.setEnabled(id, enabled);
    notifyListeners();
  }

  Future<bool> addCustom(LocalSourceConfig cfg) async {
    if (cfg.id.isEmpty || cfg.name.isEmpty) return false;
    if (_mgr.isRegistered(cfg.id)) return false;
    _customConfigs.add(cfg);
    _mgr.register(LocalBookSource(cfg));
    await _mgr.saveCustomConfigsJson(
        LocalSourceConfig.toJsonList(_customConfigs));
    notifyListeners();
    return true;
  }

  Future<void> removeCustom(String id) async {
    if (id == 'bili') return;
    _customConfigs.removeWhere((c) => c.id == id);
    _mgr.unregister(id);
    await _mgr.saveCustomConfigsJson(
        LocalSourceConfig.toJsonList(_customConfigs));

    notifyListeners();
  }

  Future<bool> importFromJsonString(String jsonStr) async {
    try {
      final configs = LocalSourceConfig.fromJsonList(jsonStr);
      var added = false;
      for (final cfg in configs) {
        if (cfg.id.isEmpty) continue;
        if (_mgr.isRegistered(cfg.id)) continue;
        _customConfigs.add(cfg);
        _mgr.register(LocalBookSource(cfg));
        added = true;
      }
      if (added) {
        await _mgr.saveCustomConfigsJson(
            LocalSourceConfig.toJsonList(_customConfigs));
        notifyListeners();
      }
      return added;
    } catch (e) {
      debugPrint('[SourceStore] import failed: $e');
      return false;
    }
  }
}