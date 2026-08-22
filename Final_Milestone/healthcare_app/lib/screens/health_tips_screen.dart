import 'package:flutter/material.dart';

import '../models/article.dart';
import '../services/article_service.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_header.dart';
import 'article_screen.dart';

/// Screen 26 (User / Patient) - Health Tips.
///
/// Reached from the Health Tips box on the Services screen.
///
/// The magazine's front page: a list of titles, one row each, tapped to read
/// the whole thing. That is exactly what the wireframe draws - "Paragraph 1 >",
/// "Paragraph 2 >", etc - with the row lighting up neon green on the way in,
/// the same as every other list in the app.
///
/// Only titles are fetched here. The article itself is read when a title is
/// tapped, so the list does not get slower every time something new is
/// published.
class HealthTipsScreen extends StatefulWidget {
  const HealthTipsScreen({super.key});

  @override
  State<HealthTipsScreen> createState() => _HealthTipsScreenState();
}

class _HealthTipsScreenState extends State<HealthTipsScreen> {
  List<ArticleSummary> _articles = [];
  bool _isLoading = true;
  String? _loadError;
  String _emptyMessage = '';

  /// The row tapped last, so it stays lit up while the article opens.
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final result = await ArticleService.fetchAll();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _articles = result.articles;
        _emptyMessage = result.message;
      } else {
        _loadError = result.error;
      }
    });
  }

  Future<void> _openArticle(ArticleSummary article) async {
    setState(() => _selectedId = article.id);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleScreen(
          articleId: article.id,
          title: article.title,
          category: article.category,
        ),
      ),
    );

    // Back from an article leaves the list as it was, but the row it came
    // from stops being the one lit up.
    if (mounted) setState(() => _selectedId = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Health Tips'),
              const SizedBox(height: 12),

              if (!_isLoading && _loadError == null && _articles.isNotEmpty)
                Text(
                  _articles.length == 1
                      ? '1 article'
                      : '${_articles.length} articles · newest first',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              const SizedBox(height: 14),

              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.logoGreen),
            SizedBox(height: 16),
            Text(
              'Loading health tips...',
              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.red.shade900),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.logoGreen,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_articles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.menu_book_outlined,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 14),
              Text(
                _emptyMessage.isEmpty
                    ? 'No health tips have been published yet.'
                    : _emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.logoGreen,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.logoGreen,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _articles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _TipCard(
          article: _articles[index],
          selected: _selectedId == _articles[index].id,
          onTap: () => _openArticle(_articles[index]),
        ),
      ),
    );
  }
}

/// One title on the list.
///
/// Lit up neon green while it is the one being opened, which is the same
/// treatment the dashboard boxes and the drawer rows use.
class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.article,
    required this.selected,
    required this.onTap,
  });

  final ArticleSummary article;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0FFEC) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.neonGreen : AppColors.fieldBorder,
            width: selected ? 3 : 1.5,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: AppColors.neonGreen,
                    blurRadius: 14,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.logoGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.logoGreen, width: 1.2),
              ),
              child: Icon(
                iconForCategory(article.category),
                size: 22,
                color: AppColors.logoGreen,
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (article.category != null &&
                      article.category!.isNotEmpty) ...[
                    _CategoryChip(category: article.category!),
                    const SizedBox(height: 6),
                  ],

                  Text(
                    article.title,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                      color: selected
                          ? AppColors.logoGreen
                          : AppColors.textDark,
                    ),
                  ),

                  // The taste of the article that makes this a magazine
                  // rather than a menu. Two lines is enough to decide by and
                  // short enough that every row stays the same height.
                  if (article.previewLine.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      article.previewLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // The chevron the wireframe puts at the end of every row.
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Icon(
                Icons.chevron_right,
                color: selected ? AppColors.logoGreen : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What kind of tip this is.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.logoBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.logoBlue),
      ),
      child: Text(
        category,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.logoBlue,
        ),
      ),
    );
  }
}
