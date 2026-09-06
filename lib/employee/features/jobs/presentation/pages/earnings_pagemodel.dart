part of 'earnings_page.dart';

abstract class EarningsPagemodel extends State<EarningsPage> {
  List<Payout> _payouts = const [];
  Map<String, Assignment> _assignments = const {};
  bool _isLoading = true;
  String? _errorMessage;

  PayoutService get _service => widget.service ?? PayoutService();

  AssignmentService get _assignmentService =>
      widget.assignmentService ?? AssignmentService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Ödeme listesini ekranın asıl verisi olarak yükler.
  ///
  /// Atama başlıkları ikinci istektir ve bu listeyi bekletmez; ödeme satırları
  /// gelir gelmez çizilir, atamalar daha sonra kimlik üzerinden eşleşirse iş
  /// başlığı eklenir.
  Future<void> _load() async {
    setState(() {
      _isLoading = _payouts.isEmpty;
      _errorMessage = null;
    });

    try {
      final payouts = await _service.fetchMyPayouts();
      if (!mounted) return;
      setState(() => _payouts = payouts);
      unawaited(_loadAssignments());
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAssignments() async {
    try {
      final page = await _assignmentService.fetchMyAssignments();
      if (!mounted) return;
      setState(() {
        _assignments = {
          for (final assignment in page.assignments) assignment.id: assignment,
        };
      });
    } on ApiException {
      // Atama etiketi yardımcı bilgidir; ödeme listesini asla kapatmaz.
    }
  }

  List<_CurrencyTotal> _totalsFor(Set<PayoutStatus> statuses) {
    final grouped = <String, List<String>>{};
    for (final payout in _payouts.where(
      (payout) => statuses.contains(payout.status),
    )) {
      grouped.putIfAbsent(payout.currency, () => []).add(payout.amount);
    }

    if (grouped.isEmpty) {
      final fallbackCurrency = _payouts.firstOrNull?.currency ?? 'TRY';
      return [_CurrencyTotal(currency: fallbackCurrency, amount: '0')];
    }

    return [
      for (final entry in grouped.entries)
        _CurrencyTotal(
          currency: entry.key,
          amount: _sumDecimalStrings(entry.value),
        ),
    ];
  }

  /// Ondalık tutarları ikili kayan noktaya çevirmeden toplar.
  ///
  /// Bu yalnızca kullanıcının ödeme listesinin özetidir; komisyon, hizmet
  /// bedeli veya işveren toplamı hesaplamaz. Her ödeme tutarı backend'den
  /// geldiği biçimde önce tam sayı basamaklarına ayrılır.
  static String _sumDecimalStrings(Iterable<String> values) {
    final decimals = values.map(_FixedDecimal.parse).toList();
    if (decimals.isEmpty) return '0';

    final scale = decimals.fold<int>(
      0,
      (maximum, decimal) => decimal.scale > maximum ? decimal.scale : maximum,
    );
    final total = decimals.fold<BigInt>(BigInt.zero, (sum, decimal) {
      return sum + decimal.unscaled * _powerOfTen(scale - decimal.scale);
    });

    return _FixedDecimal(unscaled: total, scale: scale).toPlainString();
  }

  static BigInt _powerOfTen(int exponent) => BigInt.from(10).pow(exponent);

  static String _money(String amount, String currency) {
    final decimal = _FixedDecimal.parse(amount).toPlainString();
    final parts = decimal.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    final localized = parts.length == 1 ? whole : '$whole,${parts.last}';
    return currency == 'TRY' ? '$localized ₺' : '$localized $currency';
  }
}

class _CurrencyTotal {
  const _CurrencyTotal({required this.currency, required this.amount});

  final String currency;
  final String amount;
}

class _FixedDecimal {
  const _FixedDecimal({required this.unscaled, required this.scale});

  final BigInt unscaled;
  final int scale;

  factory _FixedDecimal.parse(String value) {
    final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?$').firstMatch(value);
    if (match == null) throw FormatException('Geçersiz ondalık tutar: $value');

    final sign = match.group(1) == '-' ? -1 : 1;
    final whole = match.group(2)!;
    final fraction = match.group(3) ?? '';
    return _FixedDecimal(
      unscaled: BigInt.parse('$whole$fraction') * BigInt.from(sign),
      scale: fraction.length,
    );
  }

  String toPlainString() {
    final negative = unscaled.isNegative;
    final digits = unscaled.abs().toString().padLeft(scale + 1, '0');
    final sign = negative ? '-' : '';
    if (scale == 0) return '$sign$digits';

    final split = digits.length - scale;
    return '$sign${digits.substring(0, split)}.${digits.substring(split)}';
  }
}
