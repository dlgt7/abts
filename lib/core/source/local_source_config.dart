import 'dart:convert';

class SourceCategoryConfig {
  final String id;
  final String label;
  const SourceCategoryConfig({required this.id, required this.label});

  Map<String, dynamic> toJson() => {'id': id, 'label': label};

  factory SourceCategoryConfig.fromJson(Map<String, dynamic> m) =>
      SourceCategoryConfig(
        id: m['id']?.toString() ?? '',
        label: m['label']?.toString() ?? '',
      );
}

class RegexFieldConfig {
  final String pattern;
  final int group;
  const RegexFieldConfig({required this.pattern, required this.group});

  Map<String, dynamic> toJson() => {'pattern': pattern, 'group': group};

  factory RegexFieldConfig.fromJson(Map<String, dynamic> m) => RegexFieldConfig(
        pattern: m['pattern']?.toString() ?? '',
        group: (m['group'] as num?)?.toInt() ?? 1,
      );

  RegExp? get regex {
    try {
      return RegExp(pattern, dotAll: true);
    } catch (_) {
      return null;
    }
  }
}

class ListParseConfig {
  final RegexFieldConfig item;
  final RegexFieldConfig? bookId;
  final RegexFieldConfig? title;
  final RegexFieldConfig? pic;
  final RegexFieldConfig? author;
  final RegexFieldConfig? announcer;
  final RegexFieldConfig? desc;

  const ListParseConfig({
    required this.item,
    this.bookId,
    this.title,
    this.pic,
    this.author,
    this.announcer,
    this.desc,
  });

  Map<String, dynamic> toJson() => {
        'item': item.toJson(),
        if (bookId != null) 'bookId': bookId!.toJson(),
        if (title != null) 'title': title!.toJson(),
        if (pic != null) 'pic': pic!.toJson(),
        if (author != null) 'author': author!.toJson(),
        if (announcer != null) 'announcer': announcer!.toJson(),
        if (desc != null) 'desc': desc!.toJson(),
      };

  factory ListParseConfig.fromJson(Map<String, dynamic> m) {
    RegexFieldConfig? f(String key) {
      final v = m[key];
      if (v is Map) return RegexFieldConfig.fromJson(v.cast<String, dynamic>());
      return null;
    }

    return ListParseConfig(
      item: RegexFieldConfig.fromJson(
          (m['item'] as Map).cast<String, dynamic>()),
      bookId: f('bookId'),
      title: f('title'),
      pic: f('pic'),
      author: f('author'),
      announcer: f('announcer'),
      desc: f('desc'),
    );
  }
}

class LocalSourceConfig {
  final String id;
  final String name;
  final String description;
  final String baseUrl;
  final List<SourceCategoryConfig> categories;
  final String searchPath;
  final String categoryPath;
  final String detailPath;
  final ListParseConfig listParse;
  final RegexFieldConfig? detailTitle;
  final RegexFieldConfig? detailPic;
  final RegexFieldConfig? detailAuthor;
  final RegexFieldConfig? detailAnnouncer;
  final RegexFieldConfig? detailDesc;
  final ListParseConfig chapterParse;
  final String audioExtractor;
  final Map<String, dynamic> audioConfig;

  const LocalSourceConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.baseUrl,
    required this.categories,
    required this.searchPath,
    required this.categoryPath,
    required this.detailPath,
    required this.listParse,
    this.detailTitle,
    this.detailPic,
    this.detailAuthor,
    this.detailAnnouncer,
    this.detailDesc,
    required this.chapterParse,
    required this.audioExtractor,
    required this.audioConfig,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'baseUrl': baseUrl,
        'categories': categories.map((c) => c.toJson()).toList(),
        'searchPath': searchPath,
        'categoryPath': categoryPath,
        'detailPath': detailPath,
        'listParse': listParse.toJson(),
        if (detailTitle != null) 'detailTitle': detailTitle!.toJson(),
        if (detailPic != null) 'detailPic': detailPic!.toJson(),
        if (detailAuthor != null) 'detailAuthor': detailAuthor!.toJson(),
        if (detailAnnouncer != null)
          'detailAnnouncer': detailAnnouncer!.toJson(),
        if (detailDesc != null) 'detailDesc': detailDesc!.toJson(),
        'chapterParse': chapterParse.toJson(),
        'audioExtractor': audioExtractor,
        'audioConfig': audioConfig,
      };

  factory LocalSourceConfig.fromJson(Map<String, dynamic> m) {
    RegexFieldConfig? f(String key) {
      final v = m[key];
      if (v is Map) return RegexFieldConfig.fromJson(v.cast<String, dynamic>());
      return null;
    }

    final cats = (m['categories'] as List? ?? [])
        .map((e) => SourceCategoryConfig.fromJson((e as Map).cast<String, dynamic>()))
        .toList();

    return LocalSourceConfig(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      description: m['description']?.toString() ?? '',
      baseUrl: m['baseUrl']?.toString() ?? '',
      categories: cats,
      searchPath: m['searchPath']?.toString() ?? '/search/{kw}',
      categoryPath: m['categoryPath']?.toString() ?? '/category/{catId}/{page}',
      detailPath: m['detailPath']?.toString() ?? '/book/{bookId}',
      listParse: ListParseConfig.fromJson(
          (m['listParse'] as Map).cast<String, dynamic>()),
      detailTitle: f('detailTitle'),
      detailPic: f('detailPic'),
      detailAuthor: f('detailAuthor'),
      detailAnnouncer: f('detailAnnouncer'),
      detailDesc: f('detailDesc'),
      chapterParse: ListParseConfig.fromJson(
          (m['chapterParse'] as Map).cast<String, dynamic>()),
      audioExtractor: m['audioExtractor']?.toString() ?? 'static_url',
      audioConfig:
          (m['audioConfig'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  static List<LocalSourceConfig> fromJsonList(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => LocalSourceConfig.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  static String toJsonList(List<LocalSourceConfig> configs) =>
      jsonEncode(configs.map((c) => c.toJson()).toList());
}