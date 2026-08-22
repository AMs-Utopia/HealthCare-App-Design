import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/api_client.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/article.dart';

/// All ARTICLE calls to the PHP API - the Health Tips magazine.
///
/// Two calls, not one: the list carries titles and a preview, and the article
/// itself is fetched when a title is tapped. Sending every article so that a
/// patient can read one would make the list slower every time something new is
/// published.
class ArticleService {
  // Only static helpers, never instantiated.
  ArticleService._();

  /// Every health tip, newest first.
  static Future<ArticleListResult> fetchAll() async {
    try {
      final response = await ApiClient
          .get(ApiConfig.endpoint('articles.php'))
          .timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return ArticleListResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success) {
        return ArticleListResult.failure(parsed.message);
      }

      final rows = decoded['data'];

      // An empty magazine is a success, not a failure - it just means nothing
      // has been published yet, and the server says so in its own words.
      return ArticleListResult.success(
        rows is List
            ? rows
                  .whereType<Map<String, dynamic>>()
                  .map(ArticleSummary.fromJson)
                  .toList()
            : const [],
        parsed.message,
      );
    } on SocketException {
      return ArticleListResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return ArticleListResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return ArticleListResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }

  /// One health tip, whole.
  static Future<ArticleResult> fetchOne(int articleId) async {
    try {
      final uri = ApiConfig.endpoint(
        'article.php',
      ).replace(queryParameters: {'article_id': '$articleId'});

      final response = await ApiClient.get(uri).timeout(ApiConfig.timeout);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return ArticleResult.failure(
          'The server sent back something unexpected. Check the PHP error log.',
        );
      }

      final parsed = ApiResponse.fromJson(decoded);

      if (!parsed.success || parsed.data == null) {
        return ArticleResult.failure(parsed.message);
      }

      return ArticleResult.success(Article.fromJson(parsed.data!));
    } on SocketException {
      return ArticleResult.failure(
        'Cannot reach the server at ${ApiConfig.baseUrl}.\n'
        'Check that Apache and MySQL are running in XAMPP.',
      );
    } on TimeoutException {
      return ArticleResult.failure(
        'The server took too long to answer. Please try again.',
      );
    } on FormatException {
      return ArticleResult.failure(
        'The server did not send valid JSON. Open the endpoint in a browser '
        'to see the PHP error.',
      );
    }
  }
}

/// Either the Health Tips list, or why it could not be loaded.
class ArticleListResult {
  const ArticleListResult._(this.articles, this.message, this.error);

  const ArticleListResult.success(List<ArticleSummary> articles, String message)
    : this._(articles, message, null);

  const ArticleListResult.failure(String error)
    : this._(const [], '', error);

  final List<ArticleSummary> articles;

  /// The server's own wording, used when the list came back empty.
  final String message;

  final String? error;

  bool get isSuccess => error == null;
}

/// Either one article, or why it could not be loaded.
class ArticleResult {
  const ArticleResult._(this.article, this.error);

  const ArticleResult.success(Article article) : this._(article, null);

  const ArticleResult.failure(String error) : this._(null, error);

  final Article? article;
  final String? error;

  bool get isSuccess => error == null && article != null;
}
