class BPaymentSession {
  const BPaymentSession({required this.paymentPageUrl});

  final Uri paymentPageUrl;

  factory BPaymentSession.fromJson(Map<String, dynamic> json) {
    return BPaymentSession(
      paymentPageUrl: Uri.parse(json['paymentPageUrl'] as String? ?? ''),
    );
  }
}
