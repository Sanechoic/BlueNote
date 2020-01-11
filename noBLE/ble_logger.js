var noble = require('noble');

noble.on('stateChange', function(state) {
  if (state === 'poweredOn') {
    //noble.startScanning(undefined, true);
    noble.startScanning()
  } else {
    noble.stopScanning();
  }
});

known_beacons = {
  '30:ae:a4:dd:a1:0e':'CHG_ESP32'
}


scan_interval = 2000;
let i = 0;

setInterval( function() {ble_stop(i++);}, scan_interval*2);

function ble_stop (i){
  console.log('Scanning, N=' + i)
  noble.stopScanning();
  setTimeout(ble_start, scan_interval)
};

function ble_start (){
  noble.startScanning()
}



noble.on('discover', function(peripheral) {

  if (peripheral.address in known_beacons){
    beacon = {
      'id':peripheral.id,
      'address':peripheral.address,
      'addressType':peripheral.addressType,
      'connectable':peripheral.connectable,
      'rssi':peripheral.rssi,
      'localName':peripheral.advertisement.localName,
      'serviceUuids':JSON.stringify(peripheral.advertisement.serviceUuids),
      'services':[],
      'characteristics':[],
      'serviceData':[],
      'txPowerLevel':null,
      'manufacturerData':null,
      'timestamp':new Date()
    }

    var serviceData = peripheral.advertisement.serviceData;
    if (serviceData && serviceData.length) {
      for (var i in serviceData) {
        sdUuid = JSON.stringify(serviceData[i].uuid);
        sdData = JSON.stringify(serviceData[i].data.toString('hex'));
        sD = {sdUuid:sdData};
        beacon['serviceData'].push(sD)
      }
    }
    if (peripheral.advertisement.manufacturerData) {
      beacon['manufacturerData'].push(JSON.stringify(peripheral.advertisement.manufacturerData.toString('hex')))
    }

    if (peripheral.advertisement.txPowerLevel !== undefined) {
      beacon['txPowerLevel'] = peripheral.advertisement.txPowerLevel
    }

    console.log(beacon);

    // Connect to Beacon
    /*
    peripheral.connect(function(error) {
      console.log('connected to peripheral: ' + peripheral.uuid);
      peripheral.discoverAllServicesAndCharacteristics(null, function(error, services, characteristics) {
        console.log('discovered the following services:');
        for (var i in services) {
          beacon['services'].push(services[i].uuid)
          console.log('  ' + i + ' uuid: ' + services[i].uuid);
          }
        console.log('discovered the following characteristics:');
        for (var i in characteristics) {
          beacon['characteristics'].push(characteristics[i].uuid)
          console.log('  ' + i + ' uuid: ' + characteristics[i].uuid);
          }
      });
    });
    */
  }
});
