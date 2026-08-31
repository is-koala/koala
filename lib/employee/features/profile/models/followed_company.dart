/// Takip edilen şirket. Backend `FollowedCompanyDto` karşılığı.
///
/// Şirketin tam hâli değil, liste için kırpılmış bir özet: kimlik alanı
/// `id` değil `companyId` geliyor ve galeri, adres, tür gibi alanlar yok.
/// Bu yüzden [Company] modeli kullanılmadı — eksik alanları `null`
/// doldurmak "şirketin adresi yok" gibi okunurdu.
class FollowedCompany {
  const FollowedCompany({
    required this.companyId,
    required this.name,
    this.logoUrl,
    this.description,
    this.followerCount = 0,
    this.followedAt,
  });

  final String companyId;
  final String name;
  final String? logoUrl;
  final String? description;
  final int followerCount;

  /// Takibin başladığı an. Liste bu alana göre sıralı geliyor.
  final DateTime? followedAt;

  factory FollowedCompany.fromJson(Map<String, dynamic> json) {
    return FollowedCompany(
      companyId: '${json['companyId']}',
      name: json['name'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
      description: json['description'] as String?,
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      followedAt: switch (json['followedAt']) {
        final String value => DateTime.tryParse(value),
        _ => null,
      },
    );
  }
}

/// Sayfalı takip listesi.
class FollowedCompanyPage {
  const FollowedCompanyPage({
    this.companies = const [],
    this.page = 0,
    this.totalElements = 0,
    this.last = true,
  });

  final List<FollowedCompany> companies;
  final int page;
  final int totalElements;
  final bool last;

  factory FollowedCompanyPage.fromJson(Map<String, dynamic> json) {
    final content = json['content'];

    return FollowedCompanyPage(
      companies: content is List
          ? content
                .whereType<Map<String, dynamic>>()
                .map(FollowedCompany.fromJson)
                .toList()
          : const [],
      page: json['page'] as int? ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      last: json['last'] as bool? ?? true,
    );
  }
}
