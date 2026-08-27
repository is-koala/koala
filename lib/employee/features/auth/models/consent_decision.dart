/// Kullanıcının bir sözleşme sürümü için verdiği karar.
///
/// `/auth/complete-registration` ve `/legal/consents` gövdelerinde liste
/// hâlinde gidiyor.
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
