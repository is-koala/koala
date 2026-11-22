/// Bir sözleşme sürümü için verilen karar.
class ConsentDecision {
  const ConsentDecision({
    required this.agreementVersionId,
    required this.granted,
  });

  final String agreementVersionId;

  final bool granted;

  Map<String, dynamic> toJson() {
    return {'agreementVersionId': agreementVersionId, 'granted': granted};
  }
}
