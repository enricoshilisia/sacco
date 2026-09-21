import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// What the SACCO's audit log records about where a request came from:
/// the phone (X-Client-Device) and, if the person allowed it, its
/// approximate location (X-Client-Location). Both are best-effort - a
/// failure here never blocks a request.
class ClientContext {
  ClientContext._();
  static final instance = ClientContext._();

  String device = '';
  String? _location;
  DateTime? _locatedAt;

  Map<String, String> get headers => {
        if (device.isNotEmpty) 'X-Client-Device': Uri.encodeComponent(device),
        'X-Client-Location': ?_location,
      };

  Future<void> init() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final app = 'Inuka West ${package.version}';
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        device = '${_cap(a.manufacturer)} ${a.model} · Android ${a.version.release} · $app';
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        device = '${i.utsname.machine} · iOS ${i.systemVersion} · $app';
      } else {
        device = '${Platform.operatingSystem} · $app';
      }
    } catch (_) {
      device = 'Inuka West app';
    }
  }

  /// Asks for (coarse) location permission if [ask] and we haven't been
  /// refused for good, then reads a fix. Refreshed at most every 20 minutes.
  Future<void> refreshLocation({bool ask = false}) async {
    if (_locatedAt != null && DateTime.now().difference(_locatedAt!) < const Duration(minutes: 20)) return;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && ask) permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) return;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 10)),
      );
      var place = '';
      try {
        final marks = await Geocoding().placemarkFromCoordinates(position.latitude, position.longitude);
        if (marks.isNotEmpty) {
          final m = marks.first;
          place = [m.locality, m.subAdministrativeArea, m.country]
              .whereType<String>()
              .where((p) => p.isNotEmpty)
              .toSet()
              .take(2)
              .join(', ');
        }
      } catch (_) {}
      _location = '${position.latitude.toStringAsFixed(5)},${position.longitude.toStringAsFixed(5)}'
          '${place.isEmpty ? '' : ';${Uri.encodeComponent(place)}'}';
      _locatedAt = DateTime.now();
    } catch (_) {}
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
