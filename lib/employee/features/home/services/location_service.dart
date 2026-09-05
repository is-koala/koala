import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class LocationService with WidgetsBindingObserver {
  final BuildContext context;
  final void Function(Position position) onLocationReceived;

  bool _dialogShown = false; // Dialog tekrar açılmasın
  bool _requestedOnce = false; // Request bir kere atıldı mı?
  bool _disposed = false;

  LocationService(this.context, {required this.onLocationReceived}) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_disposed && state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> init() async {
    await _checkPermission();
  }

  Future<void> _checkPermission() async {
    PermissionStatus status = await Permission.location.status;
    if (_disposed) return;

    if (status.isGranted) {
      // İzin var, doğruluk kontrolü
      final accuracy = await Geolocator.getLocationAccuracy();
      if (_disposed) return;
      if (accuracy == LocationAccuracyStatus.reduced) {
        // Yaklaşık konum verilmiş → request atma, dialog göster
        if (!_dialogShown) {
          _dialogShown = true;
          _showPermissionDialog();
        }
      } else {
        // Tam konum izni verildi - açık dialog varsa kapat
        if (_dialogShown && context.mounted) {
          Navigator.of(
            context,
            rootNavigator: true,
          ).popUntil((route) => route.isFirst);
        }
        _dialogShown = false;
        _requestedOnce = false;
        _getLocation();
      }
    } else if (status.isDenied) {
      // Sadece hiç izin verilmemişse request at
      if (!_requestedOnce) {
        _requestedOnce = true;
        status = await Permission.location.request();
        if (_disposed) return;
      }

      if (status.isGranted) {
        // İzin verildi - açık dialog varsa kapat
        if (_dialogShown && context.mounted) {
          Navigator.of(
            context,
            rootNavigator: true,
          ).popUntil((route) => route.isFirst);
        }
        _dialogShown = false;
        _getLocation();
      } else {
        // Yaklaşık veya reddedilmiş → dialog göster
        if (!_dialogShown) {
          _dialogShown = true;
          _showPermissionDialog();
        }
      }
    } else if (status.isPermanentlyDenied) {
      if (!_dialogShown) {
        _dialogShown = true;
        _showPermissionDialog();
      }
    }
  }

  Future<void> _getLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: defaultTargetPlatform == TargetPlatform.android
            ? AndroidSettings(
                accuracy: LocationAccuracy.best,
                forceLocationManager: false,
              )
            : LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 10,
              ),
      );
      if (!_disposed) onLocationReceived(position);
    } catch (e) {
      debugPrint("Konum alınamadı: $e");
    }
  }

  void _showPermissionDialog() {
    if (_disposed || !context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Tam Konum İzni Gerekli"),
          content: const Text(
            "Uygulamanın çalışabilmesi için tam konum izni vermeniz gerekiyor.",
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                _dialogShown = false; // Ayarlardan dönüldüğünde tekrar kontrol
                await openAppSettings();
              },
              child: const Text("Ayarlar"),
            ),
          ],
        );
      },
    );
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
  }
}
