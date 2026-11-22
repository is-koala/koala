import 'package:koala/employee/features/settings/models/mrz_key.dart';

class MrzFrameObservation {
  const MrzFrameObservation.valid(MrzKey this.key)
    : guidance = MrzScanGuidance.holdSteady;

  const MrzFrameObservation.invalid(this.guidance) : key = null;

  final MrzKey? key;
  final MrzScanGuidance guidance;
}

enum MrzScanGuidance {
  preparing('Kamera hazırlanıyor'),
  improveLighting('Işığı artır'),
  moveCloser('Kartı kadraja yaklaştır'),
  holdSteady('Telefonu sabit tut'),
  ready('MRZ geçerli, çip okumaya hazır');

  const MrzScanGuidance(this.message);

  final String message;
}

class MrzScanState {
  const MrzScanState({required this.guidance, this.key});

  final MrzScanGuidance guidance;
  final MrzKey? key;

  String get message => guidance.message;
  bool get isReady => key != null;
}

/// Tek doğru kareyi başarı saymak yerine kararlılık arar.
class MrzScanSession {
  MrzScanSession({required this.requiredStableFrames})
    : assert(requiredStableFrames > 0);

  final int requiredStableFrames;

  String? _lastSignature;
  int _stableFrames = 0;

  MrzScanState observe(MrzFrameObservation observation) {
    final key = observation.key;
    if (key == null) {
      _lastSignature = null;
      _stableFrames = 0;
      return MrzScanState(guidance: observation.guidance);
    }

    final signature = _signatureOf(key);
    if (signature == _lastSignature) {
      _stableFrames++;
    } else {
      _lastSignature = signature;
      _stableFrames = 1;
    }

    if (_stableFrames >= requiredStableFrames) {
      return MrzScanState(guidance: MrzScanGuidance.ready, key: key);
    }

    return const MrzScanState(guidance: MrzScanGuidance.holdSteady);
  }

  String _signatureOf(MrzKey key) =>
      key.normalizedTd1 ??
      '${key.documentNumber}|${key.birthDate.toIso8601String()}|'
          '${key.expiryDate.toIso8601String()}|'
          '${key.nationalIdentityNumber ?? ''}';
}
