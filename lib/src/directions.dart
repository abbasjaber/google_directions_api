// Copyright (c) 2021, the MarchDev Toolkit project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:flinq/flinq.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart'
    as gpl;
import 'package:http/http.dart' as http;

part 'directions.request.dart';
part 'directions.response.dart';

/// This service is used to calculate route between two points
class DirectionsService {
  static const _routesApiUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  static String? _apiKey;

  /// Initializes [DirectionsService] with an API key.
  static void init(String apiKey) => _apiKey = apiKey;

  /// Gets the API key
  static String? get apiKey => _apiKey;

  /// Calculates route between two points.
  Future<void> route(
    DirectionsRequest request,
    void Function(DirectionsResult, DirectionsStatus?) callback,
  ) async {
    if (_apiKey == null) {
      throw Exception('Google Maps API key is not initialized.');
    }

    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey!,
      'X-Goog-FieldMask':
          'routes.legs.steps.startLocation,routes.legs.steps.navigationInstruction'
    };

    final body = jsonEncode({
      'origin': {
        'location': {
          'latLng': {
            'latitude': request.origin.latitude,
            'longitude': request.origin.longitude
          }
        }
      },
      'destination': {
        'location': {
          'latLng': {
            'latitude': request.destination.latitude,
            'longitude': request.destination.longitude
          }
        }
      },
      'travelMode': request.travelMode
          .toString()
          .split('.')
          .last, // Use only the name of the enum
      'computeAlternativeRoutes': false,
      'routeModifiers': {'avoidTolls': false, 'avoidHighways': false},
      'languageCode': 'en-US',
      'units': 'METRIC'
    });

    try {
      final response = await http.post(
        Uri.parse(_routesApiUrl),
        headers: headers,
        body: body,
      );

      print('Request Body: $body');

      if (response.statusCode != 200) {
        throw Exception(
            '${response.statusCode} (${response.reasonPhrase}), uri = $_routesApiUrl');
      }

      final result = DirectionsResult.fromMap(json.decode(response.body));
      print('Request Body: $body');
      callback(result, DirectionsStatus(response.reasonPhrase!));
    } catch (e) {
      print('Error fetching directions: $e');
    }
  }
}

/// A pair of latitude and longitude coordinates, stored as degrees.
class GeoCoord {
  /// Creates a geographical location specified in degrees [latitude] and
  /// [longitude].
  ///
  /// The latitude is clamped to the inclusive interval from -90.0 to +90.0.
  ///
  /// The longitude is normalized to the half-open interval from -180.0
  /// (inclusive) to +180.0 (exclusive)
  const GeoCoord(double latitude, double longitude)
      : latitude =
            (latitude < -90.0 ? -90.0 : (90.0 < latitude ? 90.0 : latitude)),
        longitude = (longitude + 180.0) % 360.0 - 180.0;

  /// The latitude in degrees between -90.0 and 90.0, both inclusive.
  final double latitude;

  /// The longitude in degrees between -180.0 (inclusive) and 180.0 (exclusive).
  final double longitude;

  static GeoCoord _fromList(List<num> list) => GeoCoord(
        list[0] as double,
        list[1] as double,
      );

  @override
  String toString() => '$runtimeType($latitude, $longitude)';

  @override
  bool operator ==(Object other) {
    return other is GeoCoord &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode + longitude.hashCode;
}

/// A latitude/longitude aligned rectangle.
///
/// The rectangle conceptually includes all points (lat, lng) where
/// * lat ∈ [`southwest.latitude`, `northeast.latitude`]
/// * lng ∈ [`southwest.longitude`, `northeast.longitude`],
///   if `southwest.longitude` ≤ `northeast.longitude`,
/// * lng ∈ [-180, `northeast.longitude`] ∪ [`southwest.longitude`, 180],
///   if `northeast.longitude` < `southwest.longitude`
class GeoCoordBounds {
  /// Creates geographical bounding box with the specified corners.
  ///
  /// The latitude of the southwest corner cannot be larger than the
  /// latitude of the northeast corner.
  GeoCoordBounds({required this.southwest, required this.northeast})
      : assert(southwest.latitude <= northeast.latitude);

  /// The southwest corner of the rectangle.
  final GeoCoord southwest;

  /// The northeast corner of the rectangle.
  final GeoCoord northeast;

  /// Returns whether this rectangle contains the given [GeoCoord].
  bool contains(GeoCoord point) {
    return _containsLatitude(point.latitude) &&
        _containsLongitude(point.longitude);
  }

  bool _containsLatitude(double lat) {
    return (southwest.latitude <= lat) && (lat <= northeast.latitude);
  }

  bool _containsLongitude(double lng) {
    if (southwest.longitude <= northeast.longitude) {
      return southwest.longitude <= lng && lng <= northeast.longitude;
    } else {
      return southwest.longitude <= lng || lng <= northeast.longitude;
    }
  }

  @override
  String toString() {
    return '$runtimeType($southwest, $northeast)';
  }

  @override
  bool operator ==(Object other) {
    return other is GeoCoordBounds &&
        other.southwest == southwest &&
        other.northeast == northeast;
  }

  @override
  int get hashCode => southwest.hashCode + northeast.hashCode;
}

/// Represents an enum of various travel modes.
///
/// The valid travel modes that can be specified in a
/// `DirectionsRequest` as well as the travel modes returned
/// in a `DirectionsStep`. Specify these by value, or by using
/// the constant's name.
class TravelMode {
  const TravelMode(this._name);

  final String _name;

  static final values = <TravelMode>[
    bicycling,
    driving,
    transit,
    walking,
    twoWeels
  ];

  /// Specifies a bicycling directions request.
  static const bicycling = TravelMode('BICYCLE');

  /// Specifies a driving directions request.
  static const driving = TravelMode('DRIVE');

  /// Specifies a transit directions request.
  static const transit = TravelMode('TRANSIT');

  /// Specifies a walking directions request.
  static const walking = TravelMode('WALK');

  /// Specifies a twoWeels directions request.
  static const twoWeels = TravelMode('TWO_WHEELER');

  @override
  int get hashCode => _name.hashCode;

  @override
  // ignore: non_nullable_equals_parameter
  bool operator ==(dynamic other) =>
      other is TravelMode && _name == other._name;

  @override
  String toString() => _name;
}
