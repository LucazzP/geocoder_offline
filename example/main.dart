import 'dart:io';

import 'package:geocoder_offline/geocoder_offline.dart';

Future<void> main(List<String> args) async {
  var start = DateTime.now();
  var geocoder = GeocodeData(
      File(Directory.current.path + '/example/cities15000.txt')
          .readAsStringSync(),
      'name',
      'country code',
      'latitude',
      'longitude',
      fieldDelimiter: '\t',
      eol: '\n');
  await geocoder.load();
  print('Time to load: ${DateTime.now().difference(start).inMilliseconds}ms');

  var result = geocoder.search(41.881832, -87.623177);
  print(result.first.gnisFormat);

  start = DateTime.now();
  geocoder = GeocodeData.linesStream(
      File(Directory.current.path + '/example/NationalFedCodes_20191101.csv').openRead,
      'FEATURE_NAME',
      'STATE_ALPHA',
      'PRIMARY_LATITUDE',
      'PRIMARY_LONGITUDE',
      fieldDelimiter: ',',
      eol: '\n');
  await geocoder.load();
  print('Time to load: ${DateTime.now().difference(start).inMilliseconds}ms');

  result = geocoder.search(41.881832, -87.623177);
  print(result.first.gnisFormat);
}
