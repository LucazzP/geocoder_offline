// ignore_for_file: omit_local_variable_types

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:csv/csv.dart';
import 'package:geocoder_offline/geocoder_offline.dart';
import 'package:geocoder_offline/src/search_data.dart';
import 'package:kdtree/kdtree.dart';

class GeocodeData {
  /// List of possible bearings
  final List<String> bearings = <String>[
    'N',
    'NNE',
    'NE',
    'ENE',
    'E',
    'ESE',
    'SE',
    'SSE',
    'S',
    'SSW',
    'SW',
    'WSW',
    'W',
    'WNW',
    'NW',
    'NNW',
    'N'
  ];

  /// Angle that every possible bearings covers
  final double DIRECTION_RANGE = 22.5;

  /// String that contains all possible Location
  final String? inputString;
  final Stream<List<int>> Function()? inputLinesStream;

  /// Field Delimiter in inputString
  final String fieldDelimiter;

  /// Text Delimiter in inputString
  final String textDelimiter;

  /// End of line character in inputString
  final String eol;

  /// Name of column that contains Location name
  final String featureNameHeader;

  /// Name of column that contains Location state
  final String stateHeader;

  /// Name of column that contains Location country
  final String? countryHeader;

  /// Name of column that contains Location latitude
  final String latitudeHeader;

  /// Name of column that contains Location longitude
  final String longitudeHeader;

  /// Number of nearest result
  final int numMarkers;

  late KDTree _kdTree;
  var _featureNameHeaderSN = -1;
  var _stateHeaderSN = -1;
  var _countryHeaderSN = -1;
  var _latitudeHeaderSN = -1;
  var _longitudeHeaderSN = -1;
  bool loaded = false;

  /// prefer using the [GeocodeData.linesStream] constructor to load the file on demand,
  /// preventing the use of a lot of memory
  GeocodeData(
    this.inputString,
    this.featureNameHeader,
    this.stateHeader,
    this.latitudeHeader,
    this.longitudeHeader, {
    this.numMarkers = 1,
    this.fieldDelimiter = defaultFieldDelimiter,
    this.textDelimiter = defaultTextDelimiter,
    this.eol = defaultEol,
    this.countryHeader,
  }) : inputLinesStream = null;

  /// prefer use this constructor to load the file on demand,
  /// this will prevent to use a lot of memory
  GeocodeData.linesStream(
    this.inputLinesStream,
    this.featureNameHeader,
    this.stateHeader,
    this.latitudeHeader,
    this.longitudeHeader, {
    this.numMarkers = 1,
    this.fieldDelimiter = defaultFieldDelimiter,
    this.textDelimiter = defaultTextDelimiter,
    this.eol = defaultEol,
    this.countryHeader,
  }) : inputString = null;

  Future<void> load() async {
    _kdTree = await Isolate.run(() async {
      final csvConverter = CsvToListConverter(
        fieldDelimiter: fieldDelimiter,
        textDelimiter: textDelimiter,
        eol: eol,
        shouldParseNumbers: false,
      );
      _kdTree = KDTree([], _distance, ['latitude', 'longitude']);
      int loadedLine = 0;

      if (inputString != null) {
        for (var line in inputString!.split(eol)) {
          final convertedLine = csvConverter.convert(line);
          if (convertedLine.isNotEmpty) {
            loadRow(convertedLine[0], loadedLine);
          }
          loadedLine++;
        }
      } else if (inputLinesStream != null) {
        final rowsOutput = StreamController<List>();
        final inputSink = csvConverter.startChunkedConversion(rowsOutput.sink);

        rowsOutput.stream.listen((row) {
          loadRow(row, loadedLine);
          loadedLine++;
        });

        inputLinesStream!().listen((data) {
          inputSink.add(utf8.decode(data));
        }, onDone: () {
          rowsOutput.close();
        });
        await rowsOutput.done;
      }

      print('Loaded $loadedLine locations');

      return _kdTree;
    });
    loaded = true;
  }

  void loadRow(List row, int index) {
    if (index == 0) {
      _featureNameHeaderSN = row.indexWhere((x) => x == featureNameHeader);
      _stateHeaderSN = row.indexWhere((x) => x == stateHeader);
      _latitudeHeaderSN = row.indexWhere((x) => x == latitudeHeader);
      _longitudeHeaderSN = row.indexWhere((x) => x == longitudeHeader);
      if (countryHeader != null) {
        _countryHeaderSN = row.indexWhere((x) => x == countryHeader);
      }

      if (_featureNameHeaderSN == -1 ||
          _stateHeaderSN == -1 ||
          _latitudeHeaderSN == -1 ||
          _longitudeHeaderSN == -1 ||
          (countryHeader != null && _countryHeaderSN == -1)) {
        throw Exception('Some of header is not find in file');
      }
    } else {
      _kdTree.insert({
        'featureName': row[_featureNameHeaderSN],
        'state': row[_stateHeaderSN],
        'country': countryHeader != null ? row[_countryHeaderSN] : null,
        'latitude': double.tryParse(row[_latitudeHeaderSN].toString()) ?? -1,
        'longitude': double.tryParse(row[_longitudeHeaderSN].toString()) ?? -1
      });
    }
  }

  double _distance(location1, location2) {
    var lat1 = location1['latitude'],
        lon1 = location1['longitude'],
        lat2 = location2['latitude'],
        lon2 = location2['longitude'];

    return calculateDistance(lat1, lon1, lat2, lon2);
  }

  double _deg2rad(deg) {
    return deg * (pi / 180);
  }

  double _rad2deg(rad) {
    return rad * (180 / pi);
  }

  String? _calculateBearing(double? lat1, double? lon1, double? lat2, double? lon2) {
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return null;
    }

    var latitude1 = _deg2rad(lat1);
    var latitude2 = _deg2rad(lat2);
    var longDiff = _deg2rad(lon2 - lon1);
    var y = sin(longDiff) * cos(latitude2);
    var x = cos(latitude1) * sin(latitude2) - sin(latitude1) * cos(latitude2) * cos(longDiff);

    var degrees = ((_rad2deg(atan2(y, x)) + 360) % 360) - 11.25;

    var index = (degrees ~/ DIRECTION_RANGE);

    return bearings[index];
  }

  List<LocationResult> search(double latitute, double longitude) {
    assert(loaded, 'call load() function before searching');
    var result = <LocationResult>[];
    var point = {'latitude': latitute, 'longitude': longitude};
    var nearest = _kdTree.nearest(point, numMarkers);
    var searchData = SearchData(latitute, longitude);

    nearest.forEach((x) {
      var location = LocationData.fromJson(x[0]);
      double distance = x[1];
      var bearing = _calculateBearing(location.latitude, location.longitude, latitute, longitude);
      result.add(LocationResult(location, distance, bearing, searchData));
    });

    return result;
  }

  double calculateDistance(double latStart, double lonStart, double latEnd, double lonEnd) {
    var R = 3958.8; // Radius of the earth in miles
    var dLat = _deg2rad(latEnd - latStart); // deg2rad below
    var dLon = _deg2rad(lonEnd - lonStart);
    var a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(latStart)) * cos(_deg2rad(latEnd)) * sin(dLon / 2) * sin(dLon / 2);
    var c = 2 * atan2(sqrt(a), sqrt(1 - a));
    var d = R * c; // Distance in miles
    return d;
  }
}
