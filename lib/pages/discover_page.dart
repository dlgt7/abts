import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/source/source_manager.dart';
import '../core/source/source_store.dart';
import '../core/theme/app_theme.dart';
import '../data/seed_books.dart';
import '../models/book.dart';
import '../widgets/book_cards.dart';
import 'book_detail_page.dart';
import 'search_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  String _lastSourceId = '';
  int _cat = 0;
  bool _browseLoading = true;
  bool _browseLoadingMore = false;
  bool _browseNoMore = false;
  int _browsePage = 1;
  String? _browseError;
  List<Book> _browseBooks = [];
  final Map<int, ({List<Book> books, int page, bool noMore})> _browseCache = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadBrowse();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final pos = _scrollController.position.pixels;
    if (max - pos < 300 && !_browseLoadingMore && !_browseNoMore && !_browseLoading) {
      _loadMoreBrowse();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sourceId = SourceStore.instance.currentId;
    if (sourceId != _lastSourceId) {
      _lastSourceId = sourceId;
      _cat = 0;
      _browseCache.clear();
      _loadBrowse();
    }
  }

  bool get _isBili => SourceManager.instance.currentId == 'bili';

  List<({String label, IconData icon})> get _catLabels {
    if (_isBili) {
      return DiscoverSeeds.categories
          .map((c) => (label: c.label, icon: c.icon))
          .toList();
    }
    final source = SourceManager.instance.current;
    return [
      (label: '热门', icon: Icons.local_fire_department_rounded),
      ...source.categories
          .map((c) => (label: c.label, icon: Icons.menu_book_rounded)),
    ];
  }

  void _switchCategory(int i) {
    if (i == _cat) return;
    setState(() => _cat = i);
    _loadBrowse();
  }

  Future<void> _loadBrowse({bool force = false}) async {
    if (!force && _browseCache.containsKey(_cat)) {
      final cached = _browseCache[_cat]!;
      setState(() {
        _browseBooks = cached.books;
        _browseLoading = false;
        _browseError = null;
        _browsePage = cached.page;
        _browseNoMore = cached.noMore;
      });
      return;
    }
    setState(() {
      _browseLoading = true;
      _browseError = null;
      _browsePage = 1;
      _browseNoMore = false;
    });
    try {
      if (_isBili) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      final source = SourceManager.instance.current;
      final List<Book> list;
      if (_cat == 0) {
        list = await source.hot();
        _browseNoMore = true;
      } else if (_isBili) {
        final cat = DiscoverSeeds.categories[_cat];
        list = await source.search(cat.keyword);
        _browseNoMore = true;
      } else {
        final cats = source.categories;
        final idx = _cat - 1;
        list = idx < cats.length
            ? await source.category(cats[idx].id)
            : <Book>[];
        if (list.isEmpty) _browseNoMore = true;
      }
      if (!mounted) return;
      setState(() {
        _browseBooks = list;
        _browseCache[_cat] = (books: list, page: 1, noMore: _browseNoMore);
        _browseLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _browseLoading = false;
        _browseError = '$e';
      });
    }
  }

  Future<void> _loadMoreBrowse() async {
    if (_isBili || _cat == 0 || _browseNoMore) return;
    final source = SourceManager.instance.current;
    final cats = source.categories;
    final idx = _cat - 1;
    if (idx >= cats.length) return;
    setState(() => _browseLoadingMore = true);
    try {
      final nextPage = _browsePage + 1;
      final list = await source.category(cats[idx].id, page: nextPage);
      if (!mounted) return;
      if (list.isEmpty) {
        setState(() {
          _browseLoadingMore = false;
          _browseNoMore = true;
          _browseCache[_cat] = (books: _browseBooks, page: _browsePage, noMore: true);
        });
        return;
      }
      setState(() {
        _browsePage = nextPage;
        _browseBooks = [..._browseBooks, ...list];
        _browseCache[_cat] = (books: _browseBooks, page: nextPage, noMore: list.length < 12);
        _browseLoadingMore = false;
        if (list.length < 12) _browseNoMore = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _browseLoadingMore = false);
    }
  }

  void _openSearch([String? keyword]) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchPage(
          initialKeyword: keyword,
          autofocus: keyword == null || keyword.isEmpty,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<SourceStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('发现')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: InkWell(
                      onTap: _openSearch,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search,
                                size: 18, color: AppTheme.textHint),
                            const SizedBox(width: 8),
                            Text(
                              '搜索书名 / 作者 / 主播',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBrowseBody()),
        ],
      ),
    );
  }

  Widget _buildBrowseBody() {
    final cats = _catLabels;
    return Column(
      children: [
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: cats.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = cats[i];
              final selected = i == _cat;
              return GestureDetector(
                onTap: () => _switchCategory(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.accent : AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppTheme.accent : AppTheme.divider,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(c.icon,
                          size: 16,
                          color: selected
                              ? Colors.white
                              : AppTheme.textSub),
                      const SizedBox(width: 6),
                      Text(
                        c.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                          color:
                              selected ? Colors.white : AppTheme.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadBrowse(force: true),
            color: AppTheme.accent,
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
              children: _buildBrowseChildren(),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBrowseChildren() {
    if (_browseLoading) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 64),
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          ),
        ),
      ];
    }
    return [
      if (_browseError != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 40, color: AppTheme.textHint),
              const SizedBox(height: 8),
              Text(
                '加载失败，请稍后重试',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textHint),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _loadBrowse(force: true),
                child: const Text('重试'),
              ),
            ],
          ),
        )
      else if (_browseBooks.isNotEmpty)
        ..._buildRealResults(),
      if (_browseLoadingMore)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        )
      else if (!_browseNoMore && _browseBooks.isNotEmpty && !_isBili && _cat > 0)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              '上拉加载更多',
              style: TextStyle(fontSize: 12, color: AppTheme.textHint),
            ),
          ),
        ),
      if (_browseNoMore && _browseBooks.isNotEmpty && !_isBili && _cat > 0)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              '没有更多了',
              style: TextStyle(fontSize: 12, color: AppTheme.textHint),
            ),
          ),
        ),
      if (_isBili && _cat < DiscoverSeeds.categories.length)
        ..._buildAnchorsSection(DiscoverSeeds.categories[_cat]),
    ];
  }

  List<Widget> _buildRealResults() {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
        child: Row(
          children: [
            Icon(Icons.bolt_rounded, size: 20, color: AppTheme.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _cat == 0 ? '热门榜单' : _catLabels[_cat].label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
            ),
            Text(
              '${_browseBooks.length} 个结果',
              style: TextStyle(fontSize: 12, color: AppTheme.textHint),
            ),
            IconButton(
              onPressed: () => _loadBrowse(force: true),
              icon: Icon(Icons.refresh_rounded,
                  size: 18, color: AppTheme.textSub),
              tooltip: '刷新',
            ),
          ],
        ),
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          childAspectRatio: 0.55,
        ),
        itemCount: _browseBooks.length,
        itemBuilder: (context, i) {
          final b = _browseBooks[i];
          return BookGridItem(book: b, onTap: () => _open(b));
        },
      ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _buildAnchorsSection(DiscoverCategory cat) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
        child: Row(
          children: [
            Icon(Icons.mic_rounded, size: 18, color: AppTheme.accent),
            const SizedBox(width: 6),
            Text(
              '精选主播',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMain,
              ),
            ),
            const Spacer(),
            Text(
              '点击查看 TA 的作品',
              style: TextStyle(fontSize: 11, color: AppTheme.textHint),
            ),
          ],
        ),
      ),
      SizedBox(
        height: 116,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: cat.anchors.length,
          separatorBuilder: (_, _) => const SizedBox(width: 16),
          itemBuilder: (context, i) {
            final a = cat.anchors[i];
            return _AnchorTile(
              anchor: a,
              onTap: () => _openSearch(a.keyword),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  void _open(Book book) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookDetailPage(book: book)),
    );
  }
}

class _AnchorTile extends StatelessWidget {
  final AnchorPick anchor;
  final VoidCallback onTap;

  const _AnchorTile({required this.anchor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = anchor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    a.color.withValues(alpha: 0.9),
                    a.color.withValues(alpha: 0.55),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                a.name.characters.first,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              a.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              a.works,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: AppTheme.textHint),
            ),
          ],
        ),
      ),
    );
  }
}