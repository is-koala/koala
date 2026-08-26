enum MyJobStatus {
  pending, // Başvuruldu, onay bekleniyor
  approved, // Onaylandı, gidilmesi bekleniyor
  completed, // İş bitti, ödeme bekleniyor
  past, // Ödeme alındı, geçmişe taşındı
}

extension MyJobStatusExtension on MyJobStatus {
  String get displayName {
    switch (this) {
      case MyJobStatus.pending:
        return 'Başvuru Bekliyor';
      case MyJobStatus.approved:
        return 'Onaylandı';
      case MyJobStatus.completed:
        return 'Ödeme Bekleniyor';
      case MyJobStatus.past:
        return 'Tamamlandı';
    }
  }

  String get description {
    switch (this) {
      case MyJobStatus.pending:
        return 'Başvurunuz değerlendiriliyor';
      case MyJobStatus.approved:
        return 'İşe gitmeniz bekleniyor';
      case MyJobStatus.completed:
        return 'Ödemeniz işleniyor';
      case MyJobStatus.past:
        return 'Ödeme alındı';
    }
  }
}

class MyJob {
  final String id;
  final String title;
  final String company;
  final String? companyId;
  final String description;
  final String date;
  final double price;
  final MyJobStatus status;

  const MyJob({
    required this.id,
    required this.title,
    required this.company,
    this.companyId,
    required this.description,
    required this.date,
    required this.price,
    required this.status,
  });
}
