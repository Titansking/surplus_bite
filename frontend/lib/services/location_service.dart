import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  final Geocoding _geocoding = Geocoding();

  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return null;

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  Future<GeoPoint?> getCurrentGeoPoint() async {
    final position = await getCurrentPosition();
    if (position == null) return null;
    return GeoPoint(position.latitude, position.longitude);
  }

  Future<String?> getAddressFromGeoPoint(GeoPoint geoPoint) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        geoPoint.latitude,
        geoPoint.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.country}';
      }
    } catch (_) {}
    return null;
  }

  Future<GeoPoint?> getGeoPointFromAddress(String address) async {
    try {
      final locations = await _geocoding.locationFromAddress(address);
      if (locations.isNotEmpty) {
        return GeoPoint(locations.first.latitude, locations.first.longitude);
      }
    } catch (_) {}
    return null;
  }

  double distanceBetween(GeoPoint point1, GeoPoint point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    ) / 1000; // Convert to km
  }
}

/// Null Island is the classic "unset coordinate" sentinel. Treat it as missing
/// so a listing can never be published at 0,0.
bool isNullIsland(GeoPoint? point) {
  return point == null ||
      (point.latitude.abs() < 0.0001 && point.longitude.abs() < 0.0001);
}
