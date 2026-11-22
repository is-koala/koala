import 'package:koala/employee/features/home/models/job_detail.dart';

enum EvidenceKind {
  image,
  pdf,
  other;

  /// Sunucunun `contentType`'ından, gerekirse dosya adından.
  static EvidenceKind of({required String contentType, required String name}) {
    final type = contentType.toLowerCase();
    if (type.startsWith('image/')) return image;
    if (type == 'application/pdf') return pdf;

    final dot = name.lastIndexOf('.');
    final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return switch (extension) {
      'png' || 'jpg' || 'jpeg' => image,
      'pdf' => pdf,
      _ => other,
    };
  }
}

/// Kanıt dosyasının **metadata**'sı; dosyanın kendisi indirme ucundan.
class DisputeEvidence {
  const DisputeEvidence({
    required this.id,
    required this.disputeId,
    required this.fileName,
    required this.contentType,
    required this.fileSize,
    this.uploadedBy,
    this.createdAt,
  });

  final String id;
  final String disputeId;

  final JobCreator? uploadedBy;

  final String fileName;

  /// Sunucunun uzantıdan türettiği tür.
  final String contentType;

  final int fileSize;

  final DateTime? createdAt;

  EvidenceKind get kind =>
      EvidenceKind.of(contentType: contentType, name: fileName);

  /// Ad boşsa kullanıcı adı, o da yoksa "Kullanıcı".
  String get uploaderName {
    final user = uploadedBy;
    if (user == null) return 'Kullanıcı';
    final name = user.fullName;
    if (name.isNotEmpty) return name;
    final username = user.username?.trim();
    return username == null || username.isEmpty ? 'Kullanıcı' : username;
  }

  factory DisputeEvidence.fromJson(Map<String, dynamic> json) {
    final uploader = json['uploadedBy'];
    final name = json['fileName'];
    final size = json['fileSize'];

    return DisputeEvidence(
      id: '${json['id']}',
      disputeId: '${json['disputeId']}',
      uploadedBy: uploader is Map<String, dynamic>
          ? JobCreator.fromJson(uploader)
          : null,
      fileName: name is String && name.trim().isNotEmpty
          ? name.trim()
          : 'Kanıt dosyası',
      contentType: json['contentType'] is String
          ? json['contentType'] as String
          : 'application/octet-stream',
      fileSize: size is num && size >= 0 ? size.toInt() : 0,
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

/// `842 B`, `1,4 MB`; 1024 tabanı, sunucunun sınırı da MiB.
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${_oneDecimal(bytes / 1024)} KB';
  }
  return '${_oneDecimal(bytes / (1024 * 1024))} MB';
}

String _oneDecimal(double value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0')
      ? fixed.substring(0, fixed.length - 2)
      : fixed.replaceFirst('.', ',');
}
