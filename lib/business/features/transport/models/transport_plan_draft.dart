import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/features/transport/models/transport_plan_write.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/models/confirmed_address.dart';

/// İşverenin düzenleyicide kurduğu ulaşım planı (is-koala/koala#197).
///
/// Sunucudaki [TransportPlan] salt okunur; düzenleyici bu taslak üzerinde
/// çalışıyor ve kaydederken [toWrite] ile `TransportPlanWriteDto`'ya
/// çeviriyor. `id` taşıyan servis/durak yerinde güncelleniyor ve koltuklar
/// korunuyor; [seatsTaken] sunucudan gelen sayı, silme uyarısı ve kapasite
/// alt sınırı bunu okuyor.
///
/// Doğrulama sunucunun kurallarının kopyası ([validate]): kullanıcıya eksik
/// alanı Türkçe ve sırayla söylemek, `400`'ün tek alan adını göstermekten
/// iyi. Sunucunun `409`ları (kapasite koltukların altında, yön kilitli)
/// yine de yakalanıyor — ekran başka bir cihazda değişmiş olabilir.
class TransportPlanDraft with TransportMethods {
  TransportPlanDraft({
    this.outboundMethod = TransportMethod.none,
    this.returnMethod = TransportMethod.none,
    this.allowanceAmount,
    this.allowanceNote = '',
    this.notes = '',
    List<ShuttleDraft>? shuttles,
  }) : shuttles = shuttles ?? [];

  /// Sunucudaki plandan düzenlenebilir kopya.
  factory TransportPlanDraft.fromPlan(TransportPlan plan) => TransportPlanDraft(
    outboundMethod: plan.outboundMethod,
    returnMethod: plan.returnMethod,
    allowanceAmount: plan.allowanceAmount,
    allowanceNote: plan.allowanceNote ?? '',
    notes: plan.notes ?? '',
    shuttles: [for (final shuttle in plan.shuttles) ShuttleDraft.from(shuttle)],
  );

  @override
  TransportMethod outboundMethod;
  @override
  TransportMethod returnMethod;
  @override
  double? allowanceAmount;
  String allowanceNote;
  String notes;
  final List<ShuttleDraft> shuttles;

  /// Sunucudaki alan sınırları (`TransportPlanWriteDto`).
  static const int maxAllowanceNoteLength = 500;
  static const int maxNotesLength = 1000;

  void setMethod(ShuttleDirection direction, TransportMethod method) {
    switch (direction) {
      case ShuttleDirection.outbound:
        outboundMethod = method;
      case ShuttleDirection.returnTrip:
        returnMethod = method;
    }
  }

  List<ShuttleDraft> shuttlesFor(ShuttleDirection direction) =>
      shuttles.where((shuttle) => shuttle.direction == direction).toList();

  /// Derin kopya: düzenleyici kopya üstünde çalışır ki geri çıkınca
  /// çağıranın elindeki taslak değişmemiş olsun.
  TransportPlanDraft copy() => TransportPlanDraft(
    outboundMethod: outboundMethod,
    returnMethod: returnMethod,
    allowanceAmount: allowanceAmount,
    allowanceNote: allowanceNote,
    notes: notes,
    shuttles: [for (final shuttle in shuttles) shuttle.copy()],
  );

  /// Hiç plan girilmemiş hâl: iki yön de "sağlanmıyor", servis ve not yok.
  /// İlan oluşturma bu hâlde planı hiç yazmıyor.
  bool get isBlank =>
      outboundMethod == TransportMethod.none &&
      returnMethod == TransportMethod.none &&
      shuttles.isEmpty &&
      notes.trim().isEmpty;

  /// Bu taslak kaydedilirse kaç koltuk düşer: [original]'da olup listede
  /// olmayan servislerin ve durakların `seatsTaken` toplamı. Silme
  /// uyarısının sayısı buradan ("N çalışanın koltuğu düşecek").
  int droppedSeats(TransportPlan? original) {
    if (original == null) return 0;
    var dropped = 0;
    for (final shuttle in original.shuttles) {
      final kept = shuttles
          .where((candidate) => candidate.id == shuttle.id)
          .firstOrNull;
      if (kept == null) {
        dropped += shuttle.seatsTaken;
        continue;
      }
      for (final stop in shuttle.stops) {
        final stopKept = kept.stops.any((candidate) => candidate.id == stop.id);
        if (!stopKept) dropped += stop.seatsTaken;
      }
    }
    return dropped;
  }

  /// İlk eksik alanın Türkçe açıklaması; taslak geçerliyse `null`.
  String? validate() {
    if (hasCashAllowance) {
      final amount = allowanceAmount;
      if (amount == null || amount < 0) {
        return 'Yol parası tutarını girin';
      }
    }
    if (allowanceNote.trim().length > maxAllowanceNoteLength) {
      return 'Yol parası notu en fazla $maxAllowanceNoteLength karakter '
          'olabilir';
    }
    if (notes.trim().length > maxNotesLength) {
      return 'Ulaşım notu en fazla $maxNotesLength karakter olabilir';
    }
    for (final direction in ShuttleDirection.values) {
      final list = shuttlesFor(direction);
      if (list.isNotEmpty && !usesShuttle(direction)) {
        return '${direction.displayName} yöntemi servis değilken '
            '${direction.displayName.toLowerCase()} servisi tanımlanamaz; '
            'servisleri silin ya da yöntemi değiştirin';
      }
      if (list.isEmpty && usesShuttle(direction)) {
        return '${direction.displayName} için en az bir servis ekleyin';
      }
    }
    for (final shuttle in shuttles) {
      final error = shuttle.validate();
      if (error != null) return error;
    }
    return null;
  }

  TransportPlanWrite toWrite() => TransportPlanWrite(
    outboundMethod: outboundMethod,
    returnMethod: returnMethod,
    allowanceAmount: hasCashAllowance ? allowanceAmount : null,
    allowanceNote: hasCashAllowance ? allowanceNote : null,
    notes: notes,
    shuttles: [for (final shuttle in shuttles) shuttle.toWrite()],
  );
}

/// Düzenleyicideki servis.
class ShuttleDraft {
  ShuttleDraft({
    required this.direction,
    this.id,
    this.name = '',
    this.plate = '',
    this.capacity,
    this.driverName = '',
    this.driverPhone = '',
    this.seatsTaken = 0,
    List<StopDraft>? stops,
  }) : stops = stops ?? [];

  factory ShuttleDraft.from(Shuttle shuttle) => ShuttleDraft(
    id: shuttle.id,
    direction: shuttle.direction,
    name: shuttle.name,
    plate: shuttle.plate ?? '',
    capacity: shuttle.capacity,
    driverName: shuttle.driverName ?? '',
    driverPhone: shuttle.driverPhone ?? '',
    seatsTaken: shuttle.seatsTaken,
    stops: [for (final stop in shuttle.stops) StopDraft.from(stop)],
  );

  /// Sunucudaki kimlik; yeni serviste `null`. Yön kaydedildikten sonra
  /// değiştirilemiyor (`TRANSPORT_SHUTTLE_DIRECTION_LOCKED`).
  final String? id;
  final ShuttleDirection direction;
  String name;
  String plate;
  int? capacity;
  String driverName;
  String driverPhone;

  /// Sunucudaki seçilmiş koltuk sayısı; kapasite bunun altına inemez ve
  /// silme bu kadar koltuğu düşürür.
  final int seatsTaken;
  final List<StopDraft> stops;

  /// Sunucudaki alan sınırları (`ShuttleWriteDto`).
  static const int minCapacity = 1;
  static const int maxCapacity = 100;
  static const int maxNameLength = 120;
  static const int maxPlateLength = 20;
  static const int maxDriverNameLength = 120;
  static const int maxDriverPhoneLength = 32;

  /// Kapasite alanının kabul ettiği basamak sayısı; [maxCapacity]'den
  /// türüyor ki üst sınır değişince alan da değişsin.
  static final int capacityDigits = maxCapacity.toString().length;

  bool get isNew => id == null;

  /// Bu servisin silinmesiyle düşecek koltuk sayısı.
  int get droppedSeatsIfRemoved => seatsTaken;

  /// Kart altındaki tek satır: `34 ABC 12 · 12 koltuk · 3 durak`.
  String get summaryLine {
    final parts = [
      if (plate.trim().isNotEmpty) plate.trim(),
      if (capacity != null) '$capacity koltuk',
      '${stops.length} durak',
    ];
    return parts.join(' · ');
  }

  ShuttleDraft copy() => ShuttleDraft(
    id: id,
    direction: direction,
    name: name,
    plate: plate,
    capacity: capacity,
    driverName: driverName,
    driverPhone: driverPhone,
    seatsTaken: seatsTaken,
    stops: [for (final stop in stops) stop.copy()],
  );

  String? validate() {
    final label = name.trim().isEmpty ? 'Servis' : name.trim();
    if (name.trim().isEmpty) return 'Servis adı zorunlu';
    if (name.trim().length > maxNameLength) {
      return 'Servis adı en fazla $maxNameLength karakter olabilir';
    }
    if (plate.trim().length > maxPlateLength) {
      return 'Plaka en fazla $maxPlateLength karakter olabilir';
    }
    final seats = capacity;
    if (seats == null || seats < minCapacity || seats > maxCapacity) {
      return '$label: kapasite $minCapacity ile $maxCapacity arasında olmalı';
    }
    if (seats < seatsTaken) {
      return '$label: kapasite seçilmiş koltuk sayısının ($seatsTaken) '
          'altına inemez';
    }
    if (driverName.trim().length > maxDriverNameLength) {
      return 'Şoför adı en fazla $maxDriverNameLength karakter olabilir';
    }
    if (driverPhone.trim().length > maxDriverPhoneLength) {
      return 'Şoför telefonu en fazla $maxDriverPhoneLength karakter olabilir';
    }
    if (stops.isEmpty) return '$label: en az bir durak ekleyin';
    for (final stop in stops) {
      final error = stop.validate();
      if (error != null) return '$label: $error';
    }
    return null;
  }

  ShuttleWrite toWrite() => ShuttleWrite(
    id: id,
    direction: direction,
    name: name,
    plate: plate,
    capacity: capacity ?? minCapacity,
    driverName: driverName,
    driverPhone: driverPhone,
    stops: [for (final stop in stops) stop.toWrite()],
  );
}

/// Düzenleyicideki durak.
///
/// Adres iki kaynaktan gelebiliyor: sunucudaki kayıt ([existingAddress],
/// yalnız `id`'li durakta) ve haritada yeni onaylanan [pickedAddress].
/// Yeni seçilen varsa gövdeye o gidiyor; yoksa ve durak eskiyse adres hiç
/// gönderilmiyor — sunucu mevcut adresi koruyor. Yeni durakta adres
/// zorunlu.
class StopDraft {
  StopDraft({
    this.id,
    this.label = '',
    this.scheduledAt,
    this.existingAddress,
    this.pickedAddress,
    this.seatsTaken = 0,
  });

  factory StopDraft.from(ShuttleStop stop) => StopDraft(
    id: stop.id,
    label: stop.label ?? '',
    scheduledAt: stop.scheduledAt.toLocal(),
    existingAddress: stop.address,
    seatsTaken: stop.seatsTaken,
  );

  final String? id;
  String label;

  /// Yerel saatle tutuluyor; gövdeye UTC yazılıyor.
  DateTime? scheduledAt;
  final CanonicalAddress? existingAddress;
  ConfirmedAddress? pickedAddress;

  /// Sunucudaki, bu durağı seçen koltuk sayısı.
  final int seatsTaken;

  static const int maxLabelLength = 120;

  bool get isNew => id == null;

  bool get hasAddress => pickedAddress != null || existingAddress != null;

  /// Haritayı yeniden açarken ön dolum: yeni seçilen, yoksa kayıttaki.
  ConfirmedAddress? get addressForMap =>
      pickedAddress ?? ConfirmedAddress.fromCanonical(existingAddress);

  /// Ekranda yazılan adres: yeni seçilenin özeti, yoksa kayıttaki satır.
  String? get addressSummary {
    final picked = pickedAddress;
    if (picked != null) return picked.summary;
    final line = existingAddress?.displayAddress;
    if (line != null && line.isNotEmpty) return line;
    return existingAddress?.shortLabel;
  }

  /// Listede yazılan ad: etiket, yoksa adresin ilçesi, o da yoksa "Durak".
  String get displayName {
    if (label.trim().isNotEmpty) return label.trim();
    final district =
        pickedAddress?.district.name ?? existingAddress?.districtName;
    return district == null || district.isEmpty ? 'Durak' : district;
  }

  StopDraft copy() => StopDraft(
    id: id,
    label: label,
    scheduledAt: scheduledAt,
    existingAddress: existingAddress,
    pickedAddress: pickedAddress,
    seatsTaken: seatsTaken,
  );

  String? validate() {
    if (label.trim().length > maxLabelLength) {
      return 'durak adı en fazla $maxLabelLength karakter olabilir';
    }
    if (scheduledAt == null) return 'durağın kalkış saatini seçin';
    if (!hasAddress) return 'durağın adresini haritadan seçin';
    return null;
  }

  ShuttleStopWrite toWrite() => ShuttleStopWrite(
    id: id,
    label: label,
    scheduledAt: scheduledAt ?? DateTime.now(),
    address: pickedAddress?.toWrite(),
  );
}
