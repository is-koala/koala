import 'package:connectivity_plus/connectivity_plus.dart';

/// Ağ kullanılabilir göründüğünde yalnızca yeniden denemeyi haber verir.
abstract interface class TimesheetRetryTrigger {
  Stream<void> get onNetworkAvailable;
}

class ConnectivityTimesheetRetryTrigger implements TimesheetRetryTrigger {
  ConnectivityTimesheetRetryTrigger({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<void> get onNetworkAvailable => _connectivity.onConnectivityChanged
      .where(
        (results) => results.any((result) => result != ConnectivityResult.none),
      )
      .map((_) {});
}
