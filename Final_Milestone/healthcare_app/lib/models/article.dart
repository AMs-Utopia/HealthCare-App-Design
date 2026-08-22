/// The Health Tips magazine.
///
/// One article is read in two shapes, and they are two classes rather than one
/// with a nullable body:
///
///  * [ArticleSummary] is a title on the list - what the list screen shows,
///    with a taste of the article under it. It never carries the whole text.
///  * [Article] is the article itself, fetched when a title is tapped.
///
/// Keeping them apart means the list screen cannot accidentally be written to
/// depend on a body it was never sent, and the list stays the same size as the
/// magazine grows.
library;

import 'package:flutter/material.dart';

/// One title on the Health Tips list.
class ArticleSummary {
  const ArticleSummary({
    required this.id,
    required this.title,
    this.category,
    this.preview,
    this.isTruncated = false,
  });

  final int id;
  final String title;

  /// What kind of tip it is, e.g. "Prevention". Drawn as the chip on the card.
  final String? category;

  /// The opening of the article, cut short by the server.
  final String? preview;

  /// True when [preview] stopped mid article, so the card knows to trail off
  /// rather than look like the whole thing.
  final bool isTruncated;

  /// The teaser as the card prints it: the opening, on one flowing line, with
  /// an ellipsis when there is more to read.
  String get previewLine {
    final text = (preview ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

    if (text.isEmpty) return '';

    return isTruncated ? '$text...' : text;
  }

  factory ArticleSummary.fromJson(Map<String, dynamic> json) {
    return ArticleSummary(
      id: int.tryParse('${json['article_id']}') ?? 0,
      title: (json['title'] as String?) ?? '',
      category: json['category'] as String?,
      preview: json['preview'] as String?,
      // MySQL sends its booleans back as 0 and 1.
      isTruncated: '${json['is_truncated']}' == '1',
    );
  }
}

/// One health tip, whole.
class Article {
  const Article({
    required this.id,
    required this.title,
    this.category,
    this.content,
  });

  final int id;
  final String title;
  final String? category;

  /// The whole text, with a blank line between paragraphs.
  final String? content;

  /// The article split into paragraphs, so it can be laid out with space
  /// between them instead of arriving as one unreadable block.
  ///
  /// A blank line is what separates them, however many newlines or stray
  /// spaces are actually sitting in the column.
  List<String> get paragraphs {
    final text = (content ?? '').trim();

    if (text.isEmpty) return const [];

    return text
        .split(RegExp(r'\n\s*\n'))
        .map((paragraph) => paragraph.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList();
  }

  /// Roughly how long this takes to read, at the 200 words a minute an average
  /// adult reads at. Rounded up, because no article takes zero minutes.
  int get readingMinutes {
    final words = (content ?? '').split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;

    if (words == 0) return 1;

    final minutes = (words / 200).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: int.tryParse('${json['article_id']}') ?? 0,
      title: (json['title'] as String?) ?? '',
      category: json['category'] as String?,
      content: json['content'] as String?,
    );
  }
}

/// The icon that goes with a category.
///
/// The categories are free text in ARTICLE.category rather than a fixed list,
/// so anything unrecognised falls back to the same lightbulb the Health Tips
/// box on the Services screen uses - a new category added later shows up
/// looking deliberate rather than broken.
IconData iconForCategory(String? category) {
  switch ((category ?? '').toLowerCase()) {
    case 'prevention':
      return Icons.shield_outlined;
    case 'heart health':
      return Icons.favorite_outline;
    case 'diabetes':
      return Icons.water_drop_outlined;
    case 'fitness':
      return Icons.directions_walk_outlined;
    case 'nutrition':
      return Icons.restaurant_outlined;
    case 'wellbeing':
      return Icons.self_improvement_outlined;
    case 'when to seek care':
      return Icons.local_hospital_outlined;
    default:
      return Icons.tips_and_updates_outlined;
  }
}
