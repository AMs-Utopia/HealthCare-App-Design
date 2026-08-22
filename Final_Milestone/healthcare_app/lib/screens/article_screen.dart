import 'package:flutter/material.dart';

import '../models/article.dart';
import '../services/article_service.dart';
import '../theme/app_colors.dart';
import '../widgets/neon_divider.dart';
import '../widgets/screen_header.dart';

/// Screen 26a (User / Patient) - one health tip, read in full.
///
/// Opened by tapping a title on the Health Tips list. The whole text is
/// fetched here rather than travelling with the list, so the list stays the
/// same size however long the magazine gets.
///
/// The title and category are passed in as well as fetched: they are already
/// known from the row that was tapped, so the screen has a heading to draw the
/// instant it opens instead of a blank space above a spinner.
class ArticleScreen extends StatefulWidget {
  const ArticleScreen({
    super.key,
    required this.articleId,
    required this.title,
    this.category,
  });

  final int articleId;

  /// Known from the list, so the header is right before the fetch returns.
  final String title;
  final String? category;

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  Article? _article;
  bool _isLoading = true;
  String? _loadError;

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

    final result = await ArticleService.fetchOne(widget.articleId);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _article = result.article;
      } else {
        _loadError = result.error;
      }
    });
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
              // "Health Tips" rather than the article's own title: the title
              // is long, and it is drawn properly below where there is room
              // for it. The header says which part of the app this is.
              const ScreenHeader(title: 'Health Tips'),
              const SizedBox(height: 16),

              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
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

    final article = _article;
    final category = article?.category ?? widget.category;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (category != null && category.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                iconForCategory(category),
                size: 18,
                color: AppColors.logoGreen,
              ),
              const SizedBox(width: 8),
              Text(
                category.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.logoGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // Drawn from what the list already knew, so it is here before the
        // article has finished loading.
        Text(
          article?.title ?? widget.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            height: 1.25,
            color: AppColors.textDark,
          ),
        ),

        if (article != null) ...[
          const SizedBox(height: 8),
          Text(
            '${article.readingMinutes} min read',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
        ],

        const SizedBox(height: 14),
        const NeonDivider(),
        const SizedBox(height: 18),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.logoGreen),
            ),
          )
        else ...[
          // Paragraph by paragraph with space between them, rather than one
          // block of text nobody finishes.
          for (final paragraph in article!.paragraphs) ...[
            Text(
              paragraph,
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.6,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (article.paragraphs.isEmpty)
            const Text(
              'This article has nothing written in it yet.',
              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),

          const SizedBox(height: 8),
          const _GeneralAdviceNote(),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

/// The line at the end of every tip.
///
/// These articles are general guidance written for everybody, and the app they
/// sit in is one where a patient can book a doctor in three taps. Saying so at
/// the end of the reading is the honest thing to do, and it points at the part
/// of the app that can actually help with a particular problem.
class _GeneralAdviceNote extends StatelessWidget {
  const _GeneralAdviceNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.logoBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.logoBlue, width: 1.2),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.logoBlue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'General health guidance, not advice about your own condition. '
              'Anything that worries you is worth taking to a doctor.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textDark,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
