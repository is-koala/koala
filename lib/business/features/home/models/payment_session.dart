class PaymentSession {
  const PaymentSession({required this.paymentPageUrl});

  final Uri paymentPageUrl;

  factory PaymentSession.fromJson(Map<String, dynamic> json) {
    return PaymentSession(
      paymentPageUrl: Uri.parse(json['paymentPageUrl'] as String? ?? ''),
    );
  }
}
