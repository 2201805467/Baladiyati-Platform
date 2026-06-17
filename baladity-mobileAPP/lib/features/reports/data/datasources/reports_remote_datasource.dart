import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_constants.dart';
import '../models/report_category_model.dart';
import '../models/report_image_classification_model.dart';
import '../models/report_model.dart';

abstract class ReportsRemoteDataSource {
  Future<List<ReportModel>> getReports({int page = 1});
  Future<List<ReportCategoryModel>> getCategories();
  Future<ReportImageClassificationModel> classifyImage({
    required String imagePath,
  });
  Future<ReportModel> createReport({
    required String category,
    required String description,
    double? latitude,
    double? longitude,
    String? locationAddress,
    String? imagePath,
  });
}

class ReportsRemoteDataSourceImpl implements ReportsRemoteDataSource {
  ReportsRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<List<ReportModel>> getReports({int page = 1}) async {
    try {
      final res = await _dio.get(
        ApiConstants.reports,
        queryParameters: {'page': page},
      );
      final list = res.data['data'] ?? res.data;
      return (list as List)
          .map((e) => ReportModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _extract(e);
    }
  }

  @override
  Future<List<ReportCategoryModel>> getCategories() async {
    try {
      final res = await _dio.get(ApiConstants.reportCategories);
      final list = res.data['categories'] ?? res.data['data'] ?? res.data;
      return (list as List)
          .map((e) => ReportCategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _extract(e);
    }
  }

  @override
  Future<ReportImageClassificationModel> classifyImage({
    required String imagePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imagePath,
          filename: 'report.jpg',
        ),
      });
      final res = await _dio.post(
        ApiConstants.reportClassifyImage,
        data: formData,
      );
      return ReportImageClassificationModel.fromJson(
        res.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _extract(e);
    }
  }

  @override
  Future<ReportModel> createReport({
    required String category,
    required String description,
    double? latitude,
    double? longitude,
    String? locationAddress,
    String? imagePath,
  }) async {
    try {
      final categoryId = int.tryParse(category) ?? 1;
      final formData = FormData.fromMap({
        'title': description.isNotEmpty ? description : category,
        'description': description,
        'category_id': categoryId,
        'latitude': ?latitude?.toString(),
        'longitude': ?longitude?.toString(),
        if (imagePath case final String p?)
          'images[]': await MultipartFile.fromFile(p, filename: 'report.jpg'),
      });

      final res = await _dio.post(ApiConstants.reports, data: formData);
      final data = res.data['report'] ?? res.data['data'] ?? res.data;
      return ReportModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _extract(e);
    }
  }

  Exception _extract(DioException e) => e.error is Exception
      ? e.error as Exception
      : const ServerException('حدث خطأ غير متوقع');
}
