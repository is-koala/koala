import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/employee/features/company_detail/models/address.dart';
import 'package:koala/employee/features/company_detail/models/company_image.dart';

/// Fake şirket verilerini sağlayan repository
/// Backend hazır olduğunda burası gerçek API'ye bağlanacak
class CompanyService {
  /// Singleton instance
  static final CompanyService _instance = CompanyService._internal();
  factory CompanyService() => _instance;
  CompanyService._internal();

  /// Fake şirket verileri
  final Map<String, Company> _fakeCompanies = {
    'comp_1': Company(
      id: 'comp_1',
      name: 'Özlem & Murat Düğün Organizasyonu',
      email: 'info@omlmdugum.com',
      phoneNumber: '+90 312 555 0101',
      logo: CompanyImage(
        id: 'logo_1',
        url:
            'https://ui-avatars.com/api/?name=Özlem+Murat&size=256&background=E91E63&color=ffffff&bold=true&format=png',
        name: 'Özlem & Murat Logo',
        contentType: 'image/png',
      ),
      website: 'www.ozlemmuratdugun.com',
      description:
          'Ankara\'da 10 yıldır hizmet veren profesyonel düğün organizasyon şirketi. Hayalinizdeki düğünü gerçeğe dönüştürüyoruz.',
      address: Address(
        id: 'addr_1',
        street: 'Kızılırmak Mahallesi, 1443. Cadde No:12/5',
        city: 'Ankara',
        district: 'Çankaya',
        postalCode: '06510',
        country: 'Türkiye',
        latitude: 39.9334,
        longitude: 32.8597,
      ),
      taxNumber: '1234567890',
      type: CompanyType.individual,
      isApproved: true,
    ),
    'comp_2': Company(
      id: 'comp_2',
      name: 'Kahve Durağı Cafe',
      email: 'iletisim@kahveduragi.com',
      phoneNumber: '+90 312 555 0202',
      logo: CompanyImage(
        id: 'logo_2',
        url:
            'https://ui-avatars.com/api/?name=Kahve+Durağı&size=256&background=795548&color=ffffff&bold=true&format=png',
        name: 'Kahve Durağı Logo',
        contentType: 'image/png',
      ),
      website: 'www.kahveduragi.com',
      description:
          'Kızılay\'ın kalbinde özel kahve çeşitleri ve ev yapımı pastalarıyla hizmet veren samimi bir cafe. Her gün taze kahve ve sıcak bir ortam.',
      address: Address(
        id: 'addr_2',
        street: 'Ziya Gökalp Caddesi No:45/A',
        city: 'Ankara',
        district: 'Kızılay',
        postalCode: '06420',
        country: 'Türkiye',
        latitude: 39.9208,
        longitude: 32.8541,
      ),
      taxNumber: '2345678901',
      type: CompanyType.corporate,
      isApproved: true,
    ),
    'comp_3': Company(
      id: 'comp_3',
      name: 'Ahmet Yılmaz (Bireysel)',
      email: 'ahmet.yilmaz@email.com',
      phoneNumber: '+90 532 555 0303',
      logo: CompanyImage(
        id: 'logo_3',
        url:
            'https://ui-avatars.com/api/?name=Ahmet+Yılmaz&size=256&background=4CAF50&color=ffffff&bold=true&format=png',
        name: 'Ahmet Yılmaz Avatar',
        contentType: 'image/png',
      ),
      description:
          'Hayvan sever bireysel iş veren. Kedilerime iyi bakılmasını istiyorum.',
      address: Address(
        id: 'addr_3',
        street: 'Çukurambar Mahallesi',
        city: 'Ankara',
        district: 'Çankaya',
        postalCode: '06530',
        country: 'Türkiye',
        latitude: 39.9427,
        longitude: 32.8564,
      ),
      type: CompanyType.individual,
      isApproved: true,
    ),
    'comp_4': Company(
      id: 'comp_4',
      name: 'Lezzet Durağı Restaurant',
      email: 'info@lezzetduragi.com',
      phoneNumber: '+90 312 555 0404',
      logo: CompanyImage(
        id: 'logo_4',
        url:
            'https://ui-avatars.com/api/?name=Lezzet+Durağı&size=256&background=FF5722&color=ffffff&bold=true&format=png',
        name: 'Lezzet Durağı Logo',
        contentType: 'image/png',
      ),
      website: 'www.lezzetduragi.com',
      description:
          'Modern ve geleneksel Türk mutfağını bir araya getiren özgün konseptli restoranımız yakında açılıyor. Lezzet dolu bir yolculuğa hazır olun!',
      address: Address(
        id: 'addr_4',
        street: 'Tunalı Hilmi Caddesi No:78/B',
        city: 'Ankara',
        district: 'Kavaklıdere',
        postalCode: '06680',
        country: 'Türkiye',
        latitude: 39.9180,
        longitude: 32.8619,
      ),
      taxNumber: '3456789012',
      type: CompanyType.corporate,
      isApproved: true,
    ),
    'comp_5': Company(
      id: 'comp_5',
      name: 'Brew & Co. Specialty Coffee',
      email: 'hello@brewandco.com',
      phoneNumber: '+90 312 555 0505',
      logo: CompanyImage(
        id: 'logo_5',
        url:
            'https://ui-avatars.com/api/?name=Brew+Co&size=256&background=3E2723&color=ffffff&bold=true&format=png',
        name: 'Brew & Co Logo',
        contentType: 'image/png',
      ),
      website: 'www.brewandco.com',
      description:
          'Ankara\'nın ilk specialty coffee mekânlarından biri. Dünyanın dört bir yanından özenle seçilmiş kahve çekirdekleri ve profesyonel barista ekibi.',
      address: Address(
        id: 'addr_5',
        street: 'Tunalı Hilmi Caddesi No:125/3',
        city: 'Ankara',
        district: 'Çankaya',
        postalCode: '06700',
        country: 'Türkiye',
        latitude: 39.9281,
        longitude: 32.8673,
      ),
      taxNumber: '4567890123',
      type: CompanyType.corporate,
      isApproved: true,
    ),
    'comp_6': Company(
      id: 'comp_6',
      name: 'TrendShop E-ticaret',
      email: 'destek@trendshop.com',
      phoneNumber: '+90 312 555 0606',
      logo: CompanyImage(
        id: 'logo_6',
        url:
            'https://ui-avatars.com/api/?name=Trend+Shop&size=256&background=9C27B0&color=ffffff&bold=true&format=png',
        name: 'TrendShop Logo',
        contentType: 'image/png',
      ),
      website: 'www.trendshop.com',
      description:
          'Moda ve aksesuar e-ticaret platformu. En yeni trendleri uygun fiyatlarla müşterilerimize ulaştırıyoruz.',
      address: Address(
        id: 'addr_6',
        street: 'Ümit Mahallesi, 2450. Cadde No:8/12',
        city: 'Ankara',
        district: 'Ümitköy',
        postalCode: '06810',
        country: 'Türkiye',
        latitude: 39.9356,
        longitude: 32.8489,
      ),
      taxNumber: '5678901234',
      type: CompanyType.corporate,
      isApproved: true,
    ),
    'comp_7': Company(
      id: 'comp_7',
      name: 'Elit Organizasyon',
      email: 'info@elitorganizasyon.com',
      phoneNumber: '+90 312 555 0707',
      logo: CompanyImage(
        id: 'logo_7',
        url:
            'https://ui-avatars.com/api/?name=Elit+Org&size=256&background=1565C0&color=ffffff&bold=true&format=png',
        name: 'Elit Organizasyon Logo',
        contentType: 'image/png',
      ),
      website: 'www.elitorganizasyon.com',
      description:
          'Kurumsal etkinlik, toplantı ve özel organizasyon hizmetlerinde 15 yıllık deneyim. Her detayda mükemmellik.',
      address: Address(
        id: 'addr_7',
        street: 'Sheraton Hotel & Convention Center',
        city: 'Ankara',
        district: 'Çankaya',
        postalCode: '06700',
        country: 'Türkiye',
        latitude: 39.9123,
        longitude: 32.8712,
      ),
      taxNumber: '6789012345',
      type: CompanyType.corporate,
      isApproved: true,
    ),
    'comp_8': Company(
      id: 'comp_8',
      name: 'Zeynep Kaya (Bireysel)',
      email: 'zeynep.kaya@email.com',
      phoneNumber: '+90 535 555 0808',
      logo: CompanyImage(
        id: 'logo_8',
        url:
            'https://ui-avatars.com/api/?name=Zeynep+Kaya&size=256&background=FF8F00&color=ffffff&bold=true&format=png',
        name: 'Zeynep Kaya Avatar',
        contentType: 'image/png',
      ),
      description:
          'Golden Retriever sahibi. Köpeğime profesyonel ve sevgi dolu bir bakım arıyorum.',
      address: Address(
        id: 'addr_8',
        street: 'Bahçelievler Mahallesi',
        city: 'Ankara',
        district: 'Çankaya',
        postalCode: '06490',
        country: 'Türkiye',
        latitude: 39.9398,
        longitude: 32.8398,
      ),
      type: CompanyType.individual,
      isApproved: true,
    ),
    'comp_9': Company(
      id: 'comp_9',
      name: 'FitLife Spor Salonu',
      email: 'bilgi@fitlifegym.com',
      phoneNumber: '+90 312 555 0909',
      logo: CompanyImage(
        id: 'logo_9',
        url:
            'https://ui-avatars.com/api/?name=Fit+Life&size=256&background=00C853&color=ffffff&bold=true&format=png',
        name: 'FitLife Logo',
        contentType: 'image/png',
      ),
      website: 'www.fitlifegym.com',
      description:
          'Modern ekipman, profesyonel eğitmenler ve motivasyon dolu bir ortam. Sağlıklı yaşam yolculuğunuz FitLife ile başlasın!',
      address: Address(
        id: 'addr_9',
        street: 'Çayyolu Caddesi No:156/C',
        city: 'Ankara',
        district: 'Çankaya',
        postalCode: '06810',
        country: 'Türkiye',
        latitude: 39.9245,
        longitude: 32.8456,
      ),
      taxNumber: '7890123456',
      type: CompanyType.corporate,
      isApproved: true,
    ),
    'comp_10': Company(
      id: 'comp_10',
      name: 'Coffee Break Cafe',
      email: 'info@coffeebreak.com',
      phoneNumber: '+90 312 555 1010',
      logo: CompanyImage(
        id: 'logo_10',
        url:
            'https://ui-avatars.com/api/?name=Coffee+Break&size=256&background=6D4C41&color=ffffff&bold=true&format=png',
        name: 'Coffee Break Logo',
        contentType: 'image/png',
      ),
      website: 'www.coffeebreakcafe.com',
      description:
          'Kızılay\'da bulunan huzurlu ve samimi atmosferli cafe. Kaliteli kahve, taze sandviçler ve güler yüzlü ekip.',
      address: Address(
        id: 'addr_10',
        street: 'Necatibey Caddesi No:89/2',
        city: 'Ankara',
        district: 'Kızılay',
        postalCode: '06420',
        country: 'Türkiye',
        latitude: 39.9312,
        longitude: 32.8534,
      ),
      taxNumber: '8901234567',
      type: CompanyType.corporate,
      isApproved: true,
    ),
  };

  /// Tüm şirketleri getir
  Future<List<Company>> getCompanies() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _fakeCompanies.values.toList();
  }

  /// Belirli bir şirketi ID ile getir
  Future<Company?> getCompanyById(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _fakeCompanies[id];
  }

  /// Şirket ismine göre şirket getir
  Future<Company?> getCompanyByName(String name) async {
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      return _fakeCompanies.values.firstWhere(
        (company) => company.name == name,
      );
    } catch (e) {
      return null;
    }
  }

  /// Onaylı şirketleri getir
  Future<List<Company>> getApprovedCompanies() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _fakeCompanies.values.where((c) => c.isApproved).toList();
  }

  /// Şirket tipine göre şirketleri getir
  Future<List<Company>> getCompaniesByType(CompanyType type) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _fakeCompanies.values.where((c) => c.type == type).toList();
  }
}
