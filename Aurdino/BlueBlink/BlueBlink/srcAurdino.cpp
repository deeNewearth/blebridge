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

#define BLE_BUFF_SIZE 200
byte _belInputBuff[BLE_BUFF_SIZE] ;


// the setup routine runs once when you press reset:
void setup() {
	
	// Init. and start BLE library.
	ble_begin();
	
	// Enable serial debug
	Serial.begin(115200);
	// initialize the digital pin as an output.
	pinMode(led, OUTPUT);
	
	memset(_belInputBuff,0,sizeof(_belInputBuff));
	
	Serial.println(F("Device started"));
}

bool bleconnected = false;
// the loop routine runs over and over again forever:

size_t CurrentInputIndex =0;
const byte MAGIC_BYTES[] = { 0x45, 0xFF, 0x7E, 0xF0};

byte datatosend[]={0,0,0,0,2,0,0x5a,0};
uint8_t repeatcount =1;

void ProcessBLEcommand()
{
	if(CurrentInputIndex < (sizeof(MAGIC_BYTES) + sizeof(uint16_t)))
		return;
		
	Serial.print("current buffer len :");Serial.println(CurrentInputIndex);
		
	for(size_t i=0;i<sizeof(MAGIC_BYTES);i++)
	{
		if(_belInputBuff[i]!=MAGIC_BYTES[i])
		{
			Serial.println("Not magic bytes");
			
			//we might be handling junk from last calls so just eat and ignore
			CurrentInputIndex =0;
			return;		
		}

	}
	
	//get the length
	uint16_t dataLen =0;
	memcpy(&dataLen,_belInputBuff+sizeof(MAGIC_BYTES),2);
	
	Serial.print("dataLen :");Serial.println(dataLen);
	
	if(CurrentInputIndex<sizeof(MAGIC_BYTES)+sizeof(uint16_t)+(size_t)dataLen)
	{
		Serial.println("We don't have the complete command yet");
		return;
	}
	
	byte* completeData = _belInputBuff +sizeof(MAGIC_BYTES)+sizeof(uint16_t);
	
	//process data here
	Serial.print("Data is : ");
	for(uint16_t i=0;i<dataLen;i++)
	{
		Serial.print(completeData[i],HEX);
	}
	Serial.println("");
	
	//send success
	memcpy(datatosend,MAGIC_BYTES,sizeof(MAGIC_BYTES));
	
	datatosend[sizeof(datatosend)-1] =repeatcount++;
	ble_write_bytes(datatosend,sizeof(datatosend));
	
	CurrentInputIndex=0;
	
}
	
void loop() {
//	digitalWrite(led, HIGH);   // turn the LED on (HIGH is the voltage level)
	
	bool gotBledata = ble_available();
	while(ble_available())
	{
		if(CurrentInputIndex>=sizeof(_belInputBuff))
		{
			Serial.println("more input then we can handle");
			CurrentInputIndex =0;		
		}
		
		_belInputBuff[CurrentInputIndex++] = ble_read();
		
	}
	
	if(CurrentInputIndex>0 && gotBledata)
		ProcessBLEcommand();
	
	
	
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

	
