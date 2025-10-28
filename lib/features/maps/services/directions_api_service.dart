import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class DirectionsApiService {
  DirectionsApiService({this.apiKey, http.Client? client})
      : _client = client ?? http.Client(),
        _polylinePoints = PolylinePoints();

  final String? apiKey;
  final http.Client _client;
  final PolylinePoints _polylinePoints;

  /// Get directions from origin to destination
  Future<RouteInfo> getDirections({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
  }) async {
    if (apiKey == null) {
      throw Exception('Google Maps API key not configured');
    }

    final uri = _buildDirectionsUrl(origin, destination, waypoints: waypoints);

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to get directions: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['status'] != 'OK') {
      throw Exception('Directions API error: ${data['status']}');
    }

    return _parseDirections(data);
  }

  Uri _buildDirectionsUrl(LatLng origin, LatLng destination,
      {List<LatLng>? waypoints}) {
    final queryParams = {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'key': apiKey!,
    };

    if (waypoints != null && waypoints.isNotEmpty) {
      final waypointString = waypoints
          .map((point) => '${point.latitude},${point.longitude}')
          .join('|');
      queryParams['waypoints'] = waypointString;
    }

    return Uri.parse('https://maps.googleapis.com/maps/api/directions/json')
        .replace(queryParameters: queryParams);
  }

  RouteInfo _parseDirections(Map<String, dynamic> data) {
    final routes = data['routes'] as List<dynamic>;

    if (routes.isEmpty) {
      throw Exception('No routes found');
    }

    final route = routes[0];
    final legs = route['legs'] as List<dynamic>;
    final leg = legs[0];

    // Decode polyline
    final overviewPolyline = route['overview_polyline'] as Map<String, dynamic>;
    final encodedPolyline = overviewPolyline['points'] as String;

    final decodedPoints = _polylinePoints.decodePolyline(encodedPolyline);
    final polylinePoints = decodedPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    // Extract distance and duration
    final distance = leg['distance'] as Map<String, dynamic>;
    final duration = leg['duration'] as Map<String, dynamic>;

    final distanceText = distance['text'] as String;
    final distanceValue = distance['value'] as int; // in meters
    final durationText = duration['text'] as String;
    final durationValue = duration['value'] as int; // in seconds

    // Extract steps
    final steps = leg['steps'] as List<dynamic>;
    final stepList = steps.map((step) {
      final htmlInstructions = step['html_instructions'] as String;
      final stepDistance =
          (step['distance'] as Map<String, dynamic>)['text'] as String;
      final stepDuration =
          (step['duration'] as Map<String, dynamic>)['text'] as String;

      return RouteStep(
        instructions: _stripHtmlTags(htmlInstructions),
        distance: stepDistance,
        duration: stepDuration,
      );
    }).toList();

    return RouteInfo(
      polylinePoints: polylinePoints,
      distance: distanceText,
      distanceMeters: distanceValue,
      duration: durationText,
      durationSeconds: durationValue,
      steps: stepList,
    );
  }

  String _stripHtmlTags(String html) {
    // Remove HTML tags
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}

class RouteInfo {
  RouteInfo({
    required this.polylinePoints,
    required this.distance,
    required this.distanceMeters,
    required this.duration,
    required this.durationSeconds,
    required this.steps,
  });

  final List<LatLng> polylinePoints;
  final String distance;
  final int distanceMeters;
  final String duration;
  final int durationSeconds;
  final List<RouteStep> steps;
}

class RouteStep {
  RouteStep({
    required this.instructions,
    required this.distance,
    required this.duration,
  });

  final String instructions;
  final String distance;
  final String duration;
}
