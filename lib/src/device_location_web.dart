// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

class DeviceLocationSnapshot {
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? city;
  final String? region;
  final String? country;

  const DeviceLocationSnapshot({
    this.latitude,
    this.longitude,
    this.accuracy,
    this.city,
    this.region,
    this.country,
  });

  bool get hasLocation =>
      latitude != null ||
      longitude != null ||
      city != null ||
      region != null ||
      country != null;

  Map<String, dynamic> toMetadata() => {
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (accuracy != null) 'accuracy_meters': accuracy,
    if (city?.isNotEmpty == true) 'city': city,
    if (region?.isNotEmpty == true) 'region': region,
    if (country?.isNotEmpty == true) 'country': country,
  };
}

class DeviceLocationService {
  static Future<DeviceLocationSnapshot?> snapshot() async {
    try {
      final geolocation = html.window.navigator.geolocation;
      final position = await geolocation
          .getCurrentPosition(
            enableHighAccuracy: false,
            timeout: const Duration(milliseconds: 1800),
            maximumAge: const Duration(minutes: 10),
          )
          .timeout(const Duration(milliseconds: 2200));
      final coords = position.coords;
      return DeviceLocationSnapshot(
        latitude: coords?.latitude?.toDouble(),
        longitude: coords?.longitude?.toDouble(),
        accuracy: coords?.accuracy?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
