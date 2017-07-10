/*
  ----------------------------------------------------------------------------

  This file is part of the Sanworks Bpod repository
  Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

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
// Intended to run on Arduino Due
// Rotary Encoder Connections:
// Brown -> 3.3V
// Thick black / Shield -> GND
// Blue -> GND
// Black -> A0
// White -> A1
// Orange -> A2

#include "ArCOM.h"
#define SERIAL_TX_BUFFER_SIZE 256
#define SERIAL_RX_BUFFER_SIZE 256
ArCOM myUSB(SerialUSB); // USB is an ArCOM object. ArCOM wraps Arduino's SerialUSB interface, to
ArCOM Serial1COM(Serial); // UART serial port
// simplify moving data types between Arduino and MATLAB/GNU Octave.

// Module setup
unsigned long FirmwareVersion = 1;
char moduleName[] = "ChoiceWheel"; // Name of module for manual override UI and state machine assembler

// Hardware setup
byte EncoderPinA = A0;
byte EncoderPinB = A1;

// Parameters
unsigned short leftThreshold = 412; // in range 0-1024, corresponding to 0-360 degrees
unsigned short rightThreshold = 612; // in range 0-1024, corresponding to 0-360 degrees
unsigned long timeout = 5000; // in ms
unsigned long preTrialIdleTime = 1000; // Time the ball must be idle to start a trial in ms
unsigned long preTrialDuration = 0; // Actual time animal spent moving ball before a trial could start
unsigned short idleTimeMotionGrace = 10; // During pre-trial idle, moving this distance in either direction resets the idle timer

// State variables
boolean isStreaming = 0; // If currently streaming position and time data
boolean isLogging = 0; // If currently logging position and time to RAM memory
boolean inPreTrial = 0; // If currently waiting for ball to idle for idleTime2Start ms before trial start
boolean inTrial = 0; // If currently in a behavior trial
boolean trialFinished = 0; // If trial end criteria were met
int EncoderPos = 0; // Current position of the rotary encoder

// Program variables
byte opCode = 0;
byte param = 0;
boolean EncoderPinAValue = 0;
boolean EncoderPinALastValue = 0;
boolean EncoderPinBValue = 0;
boolean posChange = 0;
word EncoderPos16Bit =  0;
unsigned long timeLog[5000] = {0};
unsigned short posLog[5000] = {0};
unsigned long choiceTime = 0;
unsigned int dataPos = 0;
word dataMax = 10000;
unsigned long startTime = 0;
unsigned long currentTime = 0;
unsigned long timeFromStart = 0;
byte terminatingEvent = 0;
unsigned short idleTimeMotionGraceLow = 512-idleTimeMotionGrace;
unsigned short idleTimeMotionGraceHigh = 512+idleTimeMotionGrace;

void setup() {
  // put your setup code here, to run once:
  SerialUSB.begin(115200);
  Serial.begin(1312500);
  pinMode(EncoderPinA, INPUT);
  pinMode (EncoderPinB, INPUT);
}

void loop() {
  currentTime = millis();
  if (Serial1COM.available() > 0) {
    opCode = Serial1COM.readByte();
    switch (opCode) {
      case 255: // Return module name and info
        returnModuleInfo();
      break;
      case 'T':
        inPreTrial = true;
        EncoderPos = 512;
        dataPos = 0;
        preTrialDuration = 0;
        startTime = currentTime;
      break;
    }
  }
  if (SerialUSB.available() > 0) {
    opCode = myUSB.readByte();
    switch(opCode) {
      case 'C': // Handshake
        myUSB.writeByte(217);
      break;
      case 'S': // Start streaming
        EncoderPos = 512; // Set to mid-range
        isStreaming = true;
        startTime = currentTime;
      break;
      case 'T': // Start trial
        inPreTrial = true;
        EncoderPos = 512;
        dataPos = 0;
        preTrialDuration = 0;
        startTime = currentTime;
      break;
      case 'P': // Program parameters (1 at a time)
        param = myUSB.readByte();
        switch(param) {
          case 'L':
            leftThreshold = myUSB.readUint16();
          break;
          case 'R':  
            rightThreshold = myUSB.readUint16();
          break;
          case 'I':
            preTrialIdleTime = myUSB.readUint32();
          break;
          case 'G':
            idleTimeMotionGrace = myUSB.readUint16();
            idleTimeMotionGraceLow = 512-idleTimeMotionGrace;
            idleTimeMotionGraceHigh = 512+idleTimeMotionGrace;
          break;
          case 'T':
            timeout = myUSB.readUint32();
          break;
        }
      break;
      case 'A': // Program parameters (all at once)
        idleTimeMotionGrace = myUSB.readUint16();
        leftThreshold = myUSB.readUint16();
        rightThreshold = myUSB.readUint16();
        preTrialIdleTime = myUSB.readUint32();
        timeout = myUSB.readUint32();
        myUSB.writeByte(1);
        idleTimeMotionGraceLow = 512-idleTimeMotionGrace;
        idleTimeMotionGraceHigh = 512+idleTimeMotionGrace;
      break;
      case 'R': // Return data
        isLogging = false;
        myUSB.writeUint16(dataPos);
        myUSB.writeUint16Array(posLog,dataPos); 
        myUSB.writeUint32Array(timeLog,dataPos); 
        dataPos = 0;
      break;
      case 'Q': // Return current encoder position
        myUSB.writeUint16(EncoderPos);
      break;
      case 'X': // Exit
        isStreaming = false;
        isLogging = false;
        inTrial = false;
        inPreTrial = false;
        dataPos = 0;
        EncoderPos = 512;
      break;
    } // End switch(opCode)
  } // End if (SerialUSB.available())
  timeFromStart = currentTime - startTime;
  EncoderPinAValue = digitalRead(EncoderPinA);
  if (EncoderPinAValue == HIGH && EncoderPinALastValue == LOW) {
    EncoderPinBValue = digitalRead(EncoderPinB);
    if (EncoderPinBValue == HIGH) {
      EncoderPos++; posChange = true;
    } else {
      EncoderPos--; posChange = true;
    }
    if (EncoderPos == 1024) {
      EncoderPos = 0;
    } else if (EncoderPos == -1) {
      EncoderPos = 1023;
    }
    if (isStreaming) {
      EncoderPos16Bit = (word)EncoderPos;
      myUSB.writeUint16(EncoderPos16Bit);
      myUSB.writeUint32(timeFromStart);
    }
  }
  if (inTrial) {
    if (posChange) { // If the position changed since previous loop
      if (EncoderPos <= leftThreshold) {
        inTrial = false;
        terminatingEvent = 1;
        Serial1COM.writeByte(terminatingEvent);
      }
      if (EncoderPos >= rightThreshold) {
        inTrial = false;
        terminatingEvent = 2;
        Serial1COM.writeByte(terminatingEvent);
      }
    }
    if (timeFromStart >= timeout) {
      inTrial = false;
      terminatingEvent = 3;
      Serial1COM.writeByte(terminatingEvent);
    }
    if (!inTrial) {
      startTime = currentTime;
      if (dataPos<dataMax) { // Add final data point
        posLog[dataPos] = EncoderPos;
        timeLog[dataPos] = timeFromStart;
        dataPos++;
      }
      trialFinished = true;
      isLogging = false; // Stop logging
    }
  } else if (trialFinished) {
      trialFinished = false;
      myUSB.writeUint16(dataPos); 
      myUSB.writeByte(terminatingEvent); 
      myUSB.writeUint32(preTrialDuration); // Return data
      myUSB.writeUint16Array(posLog,dataPos); 
      myUSB.writeUint32Array(timeLog,dataPos);
      dataPos = 0;

  } else if (inPreTrial) {
    if (EncoderPos <= idleTimeMotionGraceLow) {
      preTrialDuration += timeFromStart;
      startTime = currentTime;
      EncoderPos = 512;
    }
    if (EncoderPos >= idleTimeMotionGraceHigh) {
      preTrialDuration += timeFromStart;
      startTime = currentTime;
      EncoderPos = 512;
    }
    if (timeFromStart >= preTrialIdleTime) {
      inTrial = true;
      isLogging = true;
      inPreTrial = false;
      startTime = currentTime;
      preTrialDuration += timeFromStart;
      timeFromStart = 0;
      Serial1COM.writeByte(4);
    }
  }
  if (isLogging) {
    if (posChange) { // If the position changed since previous loop
      posChange = false;
      if (dataPos<dataMax) {
        posLog[dataPos] = EncoderPos;
        timeLog[dataPos] = timeFromStart;
        dataPos++;
      }
    }
  }
  EncoderPinALastValue = EncoderPinAValue;
}

void returnModuleInfo() {
  Serial1COM.writeByte(65); // Acknowledge
  Serial1COM.writeUint32(FirmwareVersion); // 4-byte firmware version
  Serial1COM.writeByte(sizeof(moduleName)-1); // Length of module name
  Serial1COM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  Serial1COM.writeByte(0); // 1 if more info follows, 0 if not
}
