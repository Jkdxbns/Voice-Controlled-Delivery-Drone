import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/app_logger.dart';
import '../../api/models/catalog_response.dart';
import 'api_headers.dart';

/// Service for server health and catalog operations
class HealthApiService {
  final String baseUrl;

  HealthApiService({required this.baseUrl});

  /// Check server health status
  /// Returns true if server is reachable and healthy
  Future<bool> checkHealth() async {
    try {
      final url = Uri.parse('$baseUrl${ApiEndpoints.health}');
      final headers = await ApiHeaders.getHeaders();
      final response = await http.get(url, headers: headers).timeout(
        AppConstants.apiTimeoutShort,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'] as String?;
        AppLogger.success('Server health: $status');
        return status == 'ok';
      }

      AppLogger.error('Health check failed: ${response.statusCode}');
      return false;
    } catch (e) {
      AppLogger.error('Cannot connect to server: $e');
      return false;
    }
  }

  /// Get model catalog from server
  /// Returns STT and LM models available on server
  Future<CatalogResponse?> getCatalog() async {
    try {
      final url = Uri.parse('$baseUrl${ApiEndpoints.catalog}');
      final headers = await ApiHeaders.getHeaders();
      final response = await http.get(url, headers: headers).timeout(
        AppConstants.apiTimeoutMedium,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final catalog = CatalogResponse.fromJson(json);
        
        AppLogger.success(
          'Catalog loaded: ${catalog.data.sttModels.length} STT, '
          '${catalog.data.lmModels.length} LM models',
        );
        
        return catalog;
      }

      AppLogger.error('Failed to load catalog: ${response.statusCode}');
      return null;
    } catch (e) {
      AppLogger.error('Cannot connect to server: $e');
      return null;
    }
  }

  /// Test echo endpoint
  Future<String?> echo(String text) async {
    try {
      final url = Uri.parse('$baseUrl${ApiEndpoints.echo}');
      final headers = await ApiHeaders.getJsonHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'text': text}),
      ).timeout(AppConstants.apiTimeoutShort);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['echo'] as String?;
      }

      return null;
    } catch (e) {
      AppLogger.error('Echo failed: $e');
      return null;
    }
  }
}
