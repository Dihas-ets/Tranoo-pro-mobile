import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:logging/logging.dart';

/// Compteur global de vues par article (`Article.views` côté API).
class ViewsService {
  static final ViewsService _instance = ViewsService._internal();
  factory ViewsService() => _instance;
  ViewsService._internal() {
    _dio.options.baseUrl = UserService().dio.options.baseUrl;
  }

  final Dio _dio = Dio();
  final Logger _logger = Logger('ViewsService');

  Future<bool> recordView(String articleId) async {
    try {
      if (articleId.isEmpty) return false;

      final headers = <String, String>{'Content-Type': 'application/json'};
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _dio.post(
        '/views/articles/$articleId/view',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        _logger.info('Vue enregistrée pour l\'article: $articleId');
        return true;
      }
      return false;
    } catch (e) {
      _logger.warning('Erreur enregistrement vue: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getArticleViews(String articleId) async {
    try {
      if (articleId.isEmpty) return null;

      final response = await _dio.get('/views/articles/$articleId/views');

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _logger.warning('Erreur récupération vues: $e');
      return null;
    }
  }
}
