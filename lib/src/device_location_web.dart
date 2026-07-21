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
    return null;
  }
}
