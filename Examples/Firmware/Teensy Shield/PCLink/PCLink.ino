// Note: Upload with Arduino.cc v1.8.1+

// This module is a link between the state machine and PC - any bytes arriving from the PC will be forwarded to the state machine and vice versa.
// The only exception is byte 255, which is reserved to request module information.


#include "ArCOM.h"

// Module setup
unsigned long FirmwareVersion = 1;
char moduleName[] = "PCLink"; // Name of module for manual override UI and state machine assembler
ArCOM Serial1COM(Serial1); // UART serial port

byte inByte = 0;
byte nBytes = 0;
byte SerialInputBuffer[256] = {0};
byte SerialOutputBuffer[256] = {0};
byte outputBufferIndex = 0;

void setup() {
  Serial1.begin(1312500);
  pinMode(13, OUTPUT); // Set board LED to illuminate
  digitalWrite(13, HIGH);
}

void loop() {
  if (Serial.available() > 0) { // If a byte arrived from USB
    inByte = Serial.read(); // Read the byte
    Serial1.write(inByte); // Send to state machine
  }
  nBytes = Serial1.available();
  if (nBytes > 0) { // If a byte arrived from the state machine
     Serial1.readBytes(SerialInputBuffer, nBytes);
     outputBufferIndex = 0;
     for (int i = 0; i < nBytes; i++) {
      if (SerialInputBuffer[i] == 255) {
        returnModuleInfo();
      } else {
        SerialOutputBuffer[outputBufferIndex] = SerialInputBuffer[i];
        outputBufferIndex++;
      }
     }
     if (outputBufferIndex > 0) {
      Serial.write(SerialOutputBuffer, outputBufferIndex);
      outputBufferIndex = 0;
     }
  }
}

void returnModuleInfo() {
  Serial1COM.writeByte(65); // Acknowledge
  Serial1COM.writeUint32(FirmwareVersion); // 4-byte firmware version
  Serial1COM.writeByte(sizeof(moduleName)-1); // Length of module name
  Serial1COM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  Serial1COM.writeByte(0); // 1 if more info follows, 0 if not
}
