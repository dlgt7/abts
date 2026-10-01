import '../../models/book.dart';

class SourceCategory {
  final String id;
  final String label;
  const SourceCategory({required this.id, required this.label});
}

abstract class BookSource {
  String get id;
  String get name;
  String get description;

  Future<List<Book>> search(String keyword, {int page = 1, int pageSize = 20});
  Future<Book> detail(String sourceBookId);
  Future<List<String>> audioUrls(String sourceBookId, int chapterId);

  List<SourceCategory> get categories => const [];
  Future<List<Book>> category(String catId, {int page = 1}) async => [];
  Future<List<Book>> hot({int limit = 30}) async => [];
}