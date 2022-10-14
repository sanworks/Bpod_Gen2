/*
  ----------------------------------------------------------------------------

  This file is part of the Sanworks Bpod_Gen2 repository
  Copyright (C) 2022 Sanworks LLC, Rochester, New York, USA

  ----------------------------------------------------------------------------

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, version 3.

  This program is distributed  WITHOUT ANY WARRANTY and without even the
  implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/

// Example firmware for Bpod Teensy shield
// Timestamps incoming TTL pulses on ch4-6 and incoming byte codes from the state machine on the same clock.
// This can be used to sync streams that do not stop during state machine dead-time between trials (e.g. a camera frame TTL)
// Data is sent to the PC via USB and can be retrieved with the SyncTTL class in /Bpod_Gen2/Functions/Modules/Teensy Shield/

#include "ArCOM.h" // ArCOM is a serial interface wrapper developed by Sanworks, to streamline transmission of datatypes and arrays over serial
ArCOM myUSB(SerialUSB); // Creates an ArCOM object called myUSB, wrapping SerialUSB
ArCOM myUART(Serial1); // Creates an ArCOM object called myUART, wrapping Serial1

uint32_t FirmwareVersion = 1;
char moduleName[] = "SyncTTL"; 
const byte InputChannels[3] = {4,5,6};
byte opCode = 0; 
byte opSource = 0;
boolean newOp = false;
byte Msg = 0; // Incoming byte from state machine
uint32_t localTime = 0; // local time in microseconds, a 32-bit integer that rolls over every 72 minutes
uint32_t lastLocalTime = 0; // last known local time
uint64_t currentTime = 0; // current time in microseconds corrected for rollover, a 64-bit unsigned integer
uint32_t nMicrosRollovers = 0; // micros() is 32-bit - so every 72 minutes it rolls over. 
byte lineState[3] = {0}; // Current state of the digital input channels
byte lastLineState[3] = {0}; // Last known state of the digital input channels

union {
    byte byteArray[16];
    uint64_t uint64[2];
} msgBuffer;

void setup() {
  for (int i = 0; i < 3; i++) {
    pinMode(InputChannels[i], INPUT_PULLUP);
  }
  Serial1.begin(1312500);
}

void loop() {
  currentTime = getTheTime();
  if (myUSB.available()) {
    Msg = myUSB.readByte();
    if (Msg == 255) {
      myUSB.writeByte(250); // Handshake
      nMicrosRollovers = 0;
    }
  }
  if (myUART.available()) {
    Msg = myUART.readByte();
    if (Msg == 255) {
      returnModuleInfo();
    } else {
      msgBuffer.uint64[0] = currentTime;
      msgBuffer.byteArray[8] = 0;
      msgBuffer.byteArray[9] = Msg;
      myUSB.writeByteArray(msgBuffer.byteArray, 10);
    }
  }
  for (int i = 0; i < 3; i++) {
    lineState[i] = digitalReadFast(InputChannels[i]);
    if (lineState[i] != lastLineState[i]) {
      msgBuffer.uint64[0] = currentTime;
      msgBuffer.byteArray[8] = InputChannels[i];
      msgBuffer.byteArray[9] = lineState[i];
      myUSB.writeByteArray(msgBuffer.byteArray, 10);
      lastLineState[i] = lineState[i];
    }
  }
}

uint64_t getTheTime() {
  localTime = micros();
  if (localTime < lastLocalTime) {
    nMicrosRollovers++;
    lastLocalTime = localTime;
  }
  currentTime = ((uint64_t)localTime + ((uint64_t)nMicrosRollovers*4294967296));
  return currentTime;
}

void returnModuleInfo() { // Return module name and firmware version
  myUART.writeByte(65); // Acknowledge
  myUART.writeUint32(FirmwareVersion); // 4-byte firmware version
  myUART.writeByte(sizeof(moduleName)-1); // Length of module name
  myUART.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  myUART.writeByte(0); // 1 if more info follows, 0 if not
}
