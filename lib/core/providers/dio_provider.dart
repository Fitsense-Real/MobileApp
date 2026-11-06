import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_client.dart';

final dioProvider = Provider<Dio>((ref) {
  return DioClient.instance;
});