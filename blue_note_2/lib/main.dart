import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/subjects.dart';
import 'package:flutter/cupertino.dart';

import 'dart:convert' as convert;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Background Tasks
import 'dart:isolate';
import 'package:flutter/widgets.dart';
import 'package:android_alarm_manager/android_alarm_manager.dart';


// Notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Streams are created so that app can respond to notification-related events since the plugin is initialised in the `main` function
final BehaviorSubject<ReceivedNotification> didReceiveLocalNotificationSubject =
BehaviorSubject<ReceivedNotification>();

final BehaviorSubject<String> selectNotificationSubject =
BehaviorSubject<String>();

class ReceivedNotification {
  final int id;
  final String title;
  final String body;
  final String payload;

  ReceivedNotification(
      {@required this.id,
        @required this.title,
        @required this.body,
        @required this.payload});
}

// Style
final _biggerFont = const TextStyle(fontSize: 18.0);
final _smallerFont = const TextStyle(fontSize: 12.0);

// BLE
FlutterBlue flutterBlue = FlutterBlue.instance;
final Set<ScanResult>_devices = Set<ScanResult>(); // BLE device list - initialised a set to prevent duplicates
final Set<String> _savedDevices = Set<String>(); // List of beacons to track


// Background Tasks
// Ble Scan
Set<ScanResult> _bleScan(){
  print('Scanning for BLE devices');
  flutterBlue.startScan(timeout: Duration(seconds: 5));
  var sub = flutterBlue.scanResults.listen((scanResults) {
    _devices.addAll(scanResults);
  });
  return _devices;
}

// Save to DB
void _deviceToDB(ScanResult result) async {
  print('Saving Device Data to DB');
  String url = 'https://4ghrbnl4ij.execute-api.eu-west-2.amazonaws.com/default/db_read_write';
  String tableName = '?TableName=ble_devices';

  final device = {
    'id':result.device.id.id,
    'timestamp':DateTime.now().toIso8601String(),
    'rssi':result.rssi.toString(),
    'name':result.device.name,
    'serviceDataKeys':result.advertisementData.serviceData.keys.toList(),
    'serviceDataValues':result.advertisementData.serviceData.values.toList(),
    'localName':result.advertisementData.localName,
    'connectable':result.advertisementData.connectable.toString(),
    'manufacturerDataKeys':result.advertisementData.manufacturerData.keys.toString(),
    'manufacturerDataValues':result.advertisementData.manufacturerData.values.toString(),
    'serviceUuids':result.advertisementData.serviceUuids,
    'txPowerLevel':result.advertisementData.txPowerLevel.toString()
  };

  var response = await http.post(url+tableName, body:convert.jsonEncode(device), headers:{'x-api-key':'dZ5Lnpk0v575D8ynkbLQK3s1BkJWzaat6rOzJmZx'});

  if (response.statusCode == 200){
    print('BLE Device data saved to DB: ${response.statusCode}');
    //print('Response body: ${response.body}');
  }
  else {
    throw Exception("Request failed with status: ${response.statusCode}.\n Response body: ${response.body}");
  }
}


// Read saved devices from memory
void _readSavedDevices() async {
  final prefs = await SharedPreferences.getInstance();
  final key = '_savedDevices';
  final deviceList = prefs.getStringList(key);
  _savedDevices.addAll(deviceList);
  //print(_savedDevices.toList());
}

void bgBleScan() {
  final DateTime now = DateTime.now();
  final int isolateId = Isolate.current.hashCode;
  print("[$now] BLE Scan isolate=$isolateId function='$bgBleScan'");
  var devices = _bleScan();
  for (var device in devices){
    if (_savedDevices.contains(device.device.id)) {
      _deviceToDB(device);
    }
  };

}

// TFL Status
final Set<String> _savedLines =  Set<String>(); // List of lines that will notify upon disruption

void _readSavedLines() async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'savedLines';
  final lineList = prefs.getStringList(key);
  _savedLines.addAll(lineList);
  //print(_savedLines.toList());
}

Future _getLineStatus() async{
  print('Retrieving line status');
  String url = 'https://f8xbxkpbde.execute-api.eu-west-2.amazonaws.com/default/tfl_status_update';
  var response = await http.get(url, headers:{'x-api-key':'ZhNE9EIPJ46qJHUAoYiss3FIMpfMHApz2Q4NwwxF'});
  if (response.statusCode == 200){
    return await convert.jsonDecode(response.body);
  }
  else {
    throw Exception("Request failed with status: ${response.statusCode}.");
  }
}

Future<void> _notifyDisruption(line, i) async {
  var _lineName = line['name'];
  var _lineStatus = line['lineStatuses'][0]['statusSeverityDescription'];

  var bigTextStyleInformation = BigTextStyleInformation(
      line['lineStatuses'][0]['reason'],
      htmlFormatBigText: true,
      contentTitle: '$_lineName line',
      htmlFormatContentTitle: true,
      summaryText: 'TFL Status',
      htmlFormatSummaryText: true);
  var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'tfl_api_id',
      'Tube Disruptions',
      'notifications related to tfl api',
      style: AndroidNotificationStyle.BigText,
      styleInformation: bigTextStyleInformation);
  var platformChannelSpecifics =
  NotificationDetails(androidPlatformChannelSpecifics, null);


  await flutterLocalNotificationsPlugin.show(
      i, '$_lineName line', '$_lineStatus', platformChannelSpecifics);
}

void bgTflStatus() async {
  final DateTime now = DateTime.now();
  final int isolateId = Isolate.current.hashCode;
  print("[$now] TFL Status isolate=$isolateId function='$bgTflStatus'");
  var lines = await _getLineStatus();
  int i = 0;
  for (var line in lines) {
    if (_savedLines.contains(line['name']) && line['lineStatuses'][0]['statusSeverityDescription'] != 'Good Service')
    _notifyDisruption(line, i);
    i++;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local Notifications
  print('Initialising Local Notification');
  var initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
  var initializationSettingsIOS = IOSInitializationSettings(
      onDidReceiveLocalNotification:
          (int id, String title, String body, String payload) async {
        didReceiveLocalNotificationSubject.add(ReceivedNotification(
            id: id, title: title, body: body, payload: payload));
      });
  var initializationSettings = InitializationSettings(
      initializationSettingsAndroid, initializationSettingsIOS);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: (String payload) async {
        if (payload != null) {
          debugPrint('notification payload: ' + payload);
        }
        selectNotificationSubject.add(payload);
      });


  // Background tasks
  print('Initialising Alarm Manager');
  const int tflStatusID = 1;
  const int bleScanID = 2;
  await AndroidAlarmManager.initialize();
  await AndroidAlarmManager.periodic(const Duration(seconds: 30), tflStatusID, bgTflStatus);
  await AndroidAlarmManager.periodic(const Duration(seconds: 30), bleScanID, bgBleScan);

  runApp(MyApp());
}

class TubeLines extends StatefulWidget {
  @override
  TubeLinesState createState() => TubeLinesState();
}

class BleDevices extends StatefulWidget {
  @override
  BleDevicesState createState() => BleDevicesState();
}

// Main App
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueNote',
      theme: ThemeData(
        primaryColor: Colors.indigoAccent,
        accentColor: Colors.blueAccent,
      ),
      home: TubeLines(),
      initialRoute: '/tube',
      routes: {
        '/tube': (context) => TubeLines(),
        '/ble': (context) => BleDevices(),
      },
    );
  }
}

// Main Page - Tube Lines + Statuses
class TubeLinesState extends State<TubeLines> {
  // Initialise

  Future _lines;
  @override
  void initState() {
    super.initState();
    _lines = _getLineStatus();
    didReceiveLocalNotificationSubject.stream
        .listen((ReceivedNotification receivedNotification) async {
      await showDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: receivedNotification.title != null
              ? Text(receivedNotification.title)
              : null,
          content: receivedNotification.body != null
              ? Text(receivedNotification.body)
              : null,
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: Text('Ok'),
              onPressed: () async {
                Navigator.of(context, rootNavigator: true).pop();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TubeLines(),
                  ),
                );
              },
            )
          ],
        ),
      );
    });
    selectNotificationSubject.stream.listen((String payload) async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => TubeLines()),
      );
    });
  }


  void _saveSavedLines () async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'savedLines';
    prefs.setStringList(key, _savedLines.toList());
    //print(_savedLines.toList());
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BlueNote'),
        actions: <Widget>[
          IconButton(icon: Icon(Icons.bluetooth), onPressed: _pushBleDevices),
        ],
      ),
      body: _buildLines(),
    );
  }

  // Build main page
  // ToDo: solve building before http
  Widget _buildLines(){
    print('building tube line page');
    _readSavedLines();
    return FutureBuilder(
      future: _lines,
      builder: (context, lines) {
        switch (lines.connectionState) {
          case ConnectionState.waiting: return new Text('Loading...');
          default:
            if (lines.hasError)
              return new Text('Error: ${lines.error}');
            else
              return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: lines.data.length * 2,
                  itemBuilder: (context, i) {
                    if (i.isOdd) return Divider();
                    final index = i ~/ 2;
                    return _buildRow(lines.data[index], index);
                  }
              );
        };
      },
    );
  }

  // Build Line List tiles
  Widget _buildRow(Map line, int i) {
    final _lineName = line['name'];
    final _lineStatus = line['lineStatuses'][0]['statusSeverityDescription'];
    final bool selectedNotify = _savedLines.contains(_lineName);
    final bool disruption = _lineStatus != 'Good Service';
    if (selectedNotify && disruption) {
      _notifyDisruption(line, i);
    };
    return Container(
      color: disruption ? Colors.redAccent : null,
      child: ListTile(
        title: Text(
          _lineName,
          style: _biggerFont,
        ),
        subtitle: Text(
          _lineStatus,
          style: _smallerFont,
        ),
        trailing: Icon(
          selectedNotify ? Icons.check_box : Icons.check_box_outline_blank,
          color: selectedNotify ? Colors.indigoAccent : null,
        ),
        onTap: () {
          setState(() {
            if (selectedNotify) {
              _savedLines.remove(_lineName);
              print('removing $_lineName from notify list');
            } else {
              _savedLines.add(_lineName);
              print('adding $_lineName to notify list');
            }
            _saveSavedLines();
          });
        },
      ),
    );
  }

  void refreshTubeLineList(){
    setState(() {
      _lines = _getLineStatus();
    });
  }

  // Navigate to BLE scanning screen
  void _pushBleDevices() {
    print('Navigating to BLE screen');
    Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => BleDevices ())
    );
  }
}

// ----- BLE Devices Page ----- //
// ToDo cache saved devices
class BleDevicesState extends State<BleDevices> {
  @override
  void initState() {
    super.initState();
    _bleScan();
    _readSavedDevices(); // Retrieve saved device list
  }


  // Save devices to memory
  void _saveSavedDevices () async {
    final prefs = await SharedPreferences.getInstance();
    final key = '_savedDevices';
    prefs.setStringList(key, _savedDevices.toList());
    //print(_savedDevices.toList());
  }

  // Build the ble device page
  @override
  Widget build(BuildContext context) {
    print('Building BLE screen');

    setState(() {
      _bleScan();
    });

    // Create list of tile
    final Iterable<ListTile> tiles = _devices.map((ScanResult result) {
      final _id = result.device.id.toString();
      final bool selectedBeacon = _savedDevices.contains(_id);
      return _deviceTile(result, _id, selectedBeacon);
      },
    );

    final List<Widget> divided = ListTile
        .divideTiles(
      context: context,
      tiles: tiles,
    )
        .toList();


    return Scaffold(
      appBar: AppBar(
        title: Text('BLE devices'),
      ),
      body: ListView(children: divided),
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.bluetooth_searching),
          onPressed: () {
            setState(() {
              _refreshBleDevices();
            });
          }
      ),
    );
  }

  // Build device tile
  ListTile _deviceTile(ScanResult result, String _id, bool selectedBeacon){
    if (selectedBeacon){
      _deviceToDB(result);
    }
    return ListTile(
      title: Text(
        result.device.name ?? 'No Name',
        style: _biggerFont,
      ),
      subtitle: Text(
        _id,
        style: _smallerFont,
      ),
      leading: Text(
        result.rssi.toString(),
        style: _biggerFont,
      ),
      trailing: FlatButton.icon(
          color: selectedBeacon ? Colors.blueAccent : null,
          icon: Icon(
              selectedBeacon ? Icons.bluetooth_connected : Icons.bluetooth),
          label: Text(selectedBeacon ? 'Connected' : 'Connect'),
          onPressed: () {
            setState(() {
              if (selectedBeacon) {
                _savedDevices.remove(_id);
                result.device.disconnect();
                print('removing $_id from connected list');
              } else {
                _savedDevices.add(_id);
                result.device.connect(autoConnect:true);
                print('adding $_id to connected list');
              }
              _saveSavedDevices();
            });
          }
      ),
      onTap: () {
        setState(() {
          // More detail on BLE device
        });
      }
    );

  }


  void _refreshBleDevices() async {
    print('Refreshing BLE devices');
    _devices.clear();
    //flutterBlue.stopScan();
    _bleScan();
  }

  // check for scanning
  Future scanning() async {
    bool scanning = await flutterBlue.isScanning.last;
    return scanning;
  }

  Future _readConnectedDevices() async {
    final connectedDevices = await flutterBlue.connectedDevices;
    return connectedDevices;
  }

}
