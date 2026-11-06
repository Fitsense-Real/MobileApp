import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_constants.dart';
import '../../../core/providers/dio_provider.dart';

class Equipment {
  const Equipment(this.code, this.name, this.requiresGym);
  final String code, name;
  final bool requiresGym;
  bool get selectedForGym => requiresGym || const {
    'dumbbell', 'band', 'rope', 'other', 'bench', 'pull-up bar',
    'suspension straps', 'step platform', 'stationary bike', 'treadmill',
  }.contains(code.toLowerCase().trim());
  factory Equipment.fromJson(Map<String, dynamic> json) => Equipment(json['code'] as String, json['nameEs'] as String, json['requiresGym'] == true);
}

class ProfileRepository {
  ProfileRepository(this.dio);
  final Dio dio;
  Future<Map<String, dynamic>?> fetch() async {
    try {
      final response = await dio.get(ApiConstants.profile);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
  Future<List<Equipment>> equipment() async {
    final response = await dio.get(ApiConstants.equipment);
    return (response.data as List).map((e) => Equipment.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
  Future<void> save(Map<String, dynamic> body, {required bool exists}) async {
    if (exists) { await dio.put(ApiConstants.profile, data: body); }
    else { await dio.post(ApiConstants.profile, data: body); }
  }
}
final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.read(dioProvider)));
