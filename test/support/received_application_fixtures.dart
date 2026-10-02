import 'package:koala/product/network/api_paths.dart';

import 'fake_api.dart';

/// `GET /users/me/received-applications` yanıtının bir satırı
/// (`ReceivedApplicationDto`, koala-backend#233).
Map<String, dynamic> receivedApplicationJson(
  String id, {
  String status = 'APPLIED',
  String firstName = 'Ayşe',
  String lastName = 'Yılmaz',
  String workerId = 'worker-1',
  String jobId = 'job-1',
  String postingTitle = 'Barista',
  String jobStatus = 'OPEN',
  String? companyId,
  String? companyName,
  String? notes,
  String? answeredDateTime,
  String? assignmentId,
  String applicationDateTime = '2026-09-15T08:00:00Z',
}) {
  return {
    'id': id,
    'status': status,
    'applicationDateTime': applicationDateTime,
    'answeredDateTime': answeredDateTime,
    'notes': notes,
    'applicant': {
      'id': workerId,
      'firstName': firstName,
      'lastName': lastName,
      'username': firstName.toLowerCase(),
      'profilePictureUrl': null,
    },
    'jobId': jobId,
    'postingTitle': postingTitle,
    'jobStatus': jobStatus,
    'companyId': companyId,
    'companyName': companyName,
    'assignmentId': assignmentId,
  };
}

/// Sayfalı gelen kutusu yanıtı (`PageDto<ReceivedApplicationDto>`).
FakeApiResponse receivedApplicationsResponse(
  List<Map<String, dynamic>> content, {
  int page = 0,
  int size = 20,
  bool last = true,
}) {
  return FakeApiResponse(
    statusCode: 200,
    body: {
      'success': true,
      'data': {
        'content': content,
        'page': page,
        'size': size,
        'totalElements': content.length,
        'totalPages': last ? page + 1 : page + 2,
        'first': page == 0,
        'last': last,
      },
    },
  );
}

/// Sunucu hatası: gelen kutusu çağrısının başarısızlığı.
const receivedApplicationsFailure = FakeApiResponse(
  statusCode: 500,
  body: {'success': false, 'message': 'Başvurular alınamadı'},
);

/// İstek gelen kutusunu mu çağırıyor.
bool isReceivedApplicationsRequest(String path) =>
    path == ApiPaths.receivedApplications;
