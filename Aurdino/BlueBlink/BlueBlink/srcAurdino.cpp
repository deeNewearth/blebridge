/*
 * ArdinoProjectTemplateSrc.cpp
 *
 * Created: 1/5/2014 1:07:47 PM
 *  Author: deepayan
 */ 


#include <avr/io.h>

#include "Arduino.h"
#include "ble_shield.h"

void setup();
void loop();

int led = 13;


// the setup routine runs once when you press reset:
void setup() {
	
	// Init. and start BLE library.
	ble_begin();
	
	// Enable serial debug
	Serial.begin(115200);
	// initialize the digital pin as an output.
	pinMode(led, OUTPUT);
	
	Serial.println(F("Device started"));
}

bool bleconnected = false;
// the loop routine runs over and over again forever:
void loop() {
//	digitalWrite(led, HIGH);   // turn the LED on (HIGH is the voltage level)
	
	while(ble_available())
	{
		// read out command and data
		byte data0 = ble_read();
		Serial.print(F("Got BLE BYTE : "));
		Serial.println(data0);
	}
	
	if (!ble_connected())
	{
		if(bleconnected)
			Serial.print(F("BLE disconnected"));
			
		bleconnected = false;
	}
	else
	{
		if(!bleconnected)
			Serial.print(F("BLE connected"));
		
		bleconnected = true;
		//working
	}
	
	// Allow BLE Shield to send/receive data
	ble_do_events();
	
}

	
