import 'package:dio/dio.dart';
import 'package:fitsense_mobile/features/consents/data/consents_repository.dart';

/// `GET /users/me/consents` exactly as backend 5977d28 answered for a user
/// registered with study participation (no approved terms or privacy yet).
Map<String, dynamic> consentsJson({String? terms, String? privacy, List<Map<String, dynamic>> extraHistory = const []}) => {
      'currentVersions': {'STUDY_PARTICIPATION': 'MVP-1.0', 'TERMS_OF_SERVICE': terms, 'PRIVACY_POLICY': privacy},
      'enforcedOnSignup': false,
      'history': [
        {'type': 'STUDY_PARTICIPATION', 'documentVersion': 'MVP-1.0', 'grantedAt': '2026-11-20T03:19:40Z', 'affirmativeAction': 'CASILLA_REGISTRO', 'source': 'APP', 'withdrawnAt': null},
        ...extraHistory,
      ],
    };

class ConsentsStub extends ConsentsRepository {
  ConsentsStub(this.json, {this.fails = false}) : super(Dio());
  Map<String, dynamic> json;
  final bool fails;
  final accepted = <String>[];
  @override
  Future<ConsentStatus> status() async {
    if (fails) throw DioException(requestOptions: RequestOptions(path: ConsentsRepository.path), type: DioExceptionType.connectionError);
    return ConsentStatus.fromJson(json);
  }

  @override
  Future<void> accept(ConsentType type, String version) async => accepted.add('${type.code}=$version');
}
