import 'dart:async';
import 'dart:io';

import 'package:geocoder_offline/geocoder_offline.dart';

const kFrameRate = Duration(milliseconds: 1000 ~/ 60);

Future<void> main(List<String> args) async {
  int countTick = 0;
  final uiTimerSimulator = Timer.periodic(kFrameRate, (timer) {
    print('Tick: ${countTick++}');
  });
  var start = DateTime.now();
  var geocoder = GeocodeData(File(Directory.current.path + '/cities15000.txt').readAsStringSync(),
      'name', 'country code', 'latitude', 'longitude',
      fieldDelimiter: '\t', eol: '\n');
  await geocoder.load();
  print('Time to load: ${DateTime.now().difference(start).inMilliseconds}ms');

  var result = geocoder.search(41.881832, -87.623177);
  print(result.first.gnisFormat);

  start = DateTime.now();
  geocoder = GeocodeData.linesStream(
      File(Directory.current.path + '/NationalFedCodes_20191101.csv').openRead,
      'FEATURE_NAME',
      'STATE_ALPHA',
      'PRIMARY_LATITUDE',
      'PRIMARY_LONGITUDE',
      fieldDelimiter: ',',
      eol: '\n');
  await geocoder.load();
  print('Time to load: ${DateTime.now().difference(start).inMilliseconds}ms');

  start = DateTime.now();
  geocoder = GeocodeData.linesStream(
    File(Directory.current.path + '/NationalFedCodes_20191101.csv').openRead,
    'FEATURE_NAME',
    'STATE_ALPHA',
    'PRIMARY_LATITUDE',
    'PRIMARY_LONGITUDE',
    fieldDelimiter: ',',
    isolateRun: <R>(FutureOr<R> Function() computation) async {
      return computation();
    },
    eol: '\n',
  );
  await geocoder.load();
  print('Time to load without isolate: ${DateTime.now().difference(start).inMilliseconds}ms');

  result = geocoder.search(41.881832, -87.623177);
  print(result.first.gnisFormat);
  uiTimerSimulator.cancel();
}
