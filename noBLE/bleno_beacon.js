var bleno = require('bleno');
var os = require("os");

var name = 'CHG_PI';

var serviceUuids = ['b0156be473244491826386ee36d43433']

var major = 0; // 0x0000 - 0xffff
var minor = 0; // 0x0000 - 0xffff

var measuredPower = 0;


bleno.on('stateChange', function(state) {
  if (state === 'poweredOn') {
    console.log('Advertising start')
    bleno.startAdvertising(name, serviceUuids);
  } else {
    bleno.stopAdvertising();
  }
});

bleno.on('accept', function(clientAddress){
  console.log('Connected to: '+clientAddress)
});


/*
bleno.on('advertisingStart', function(error){
});
*/
