import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_social_media/core/constants/api_constants.dart';

final adminRepositoryProvider = Provider((ref) => AdminRepository(Dio(BaseOptions(baseUrl: ApiConstants.baseUrl))));

class AdminRepository {
  final Dio _dio;

  AdminRepository(this._dio);

  Future<List<dynamic>> getReports() async {
    final response = await _dio.get('/admin/reports');
    return response.data as List;
  }

  Future<void> resolveReport(String reportId, String status) async {
    await _dio.put('/admin/reports/$reportId/status', data: {'status': status});
  }

  Future<void> banUser(String userId) async {
    await _dio.post('/admin/users/$userId/ban');
  }
}
