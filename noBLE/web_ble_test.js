var known_service = "eb3334c405ed4895859fcf2fe5bf260c";
return navigator.bluetooth.requestDevice({
  filters: [{services: [known_service]}]
}).then(device => {
  device.watchAdvertisements();
  device.addEventListener('advertisementreceived', interpretIBeacon);
});

function interpretIBeacon(event) {
  var rssi = event.rssi;
  var appleData = event.manufacturerData.get(0x004C);
  if (appleData.byteLength != 23 ||
    appleData.getUint16(0, false) !== 0x0215) {
    console.log({isBeacon: false});
  }
  var uuidArray = new Uint8Array(appleData.buffer, 2, 16);
  var major = appleData.getUint16(18, false);
  var minor = appleData.getUint16(20, false);
  var txPowerAt1m = -appleData.getInt8(22);
  console.log({
      isBeacon: true,
      uuidArray,
      major,
      minor,
      pathLossVs1m: txPowerAt1m - rssi});
};
