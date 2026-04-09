import 'package:influxdb_client/api.dart';
import '../../domain/entities/parking_slot.dart';

class InfluxDBDataSource {
  late final InfluxDBClient _client;
  late final WriteService _writeApi;
  final String _org;
  final String _bucket;

  /// Replace these with your actual InfluxDB Cloud details later
  InfluxDBDataSource({
    String url = 'https://eu-central-1-1.aws.cloud2.influxdata.com',
    String token = 'I0MnqDYmHgBWWw00nM1UYRU2FLPOmueFS3WO2F_-8p_WEyLK8e_UxzcQoGKjrPSYJ1pO_LE3DdkZYV_Iw9iW0A==',
    String org = 'Harbr',
    String bucket = 'harbr_analytics',
  })  : _org = org,
        _bucket = bucket {
    _client = InfluxDBClient(
      url: url,
      token: token,
      org: org,
      bucket: bucket,
      debug: false,
    );
    _writeApi = _client.getWriteService(WriteOptions().merge(
      batchSize: 1, // Write immediately since it's an app
    ));
  }

  /// Writes the current slot status to InfluxDB for historical analytics
  Future<void> writeSlotStatus(ParkingSlot slot) async {
    // Measurement: 'slot_occupancy'
    // Tags: slotId
    // Fields: status, isOccupied (boolean for easy charting)
    final record = Point('slot_occupancy')
        .addTag('slotId', slot.id)
        .addField('status', slot.status)
        .addField('isOccupied', slot.isOccupied ? 1 : 0);

    try {
      await _writeApi.write(record);
      // print('InfluxDB: Recorded status ${slot.status} for ${slot.id}');
    } catch (e) {
      // In a real app, you might want to log this to Crashlytics
      // print('InfluxDB Error: $e');
    }
  }

  /// Disconnect client
  void close() {
    _client.close();
  }
}
