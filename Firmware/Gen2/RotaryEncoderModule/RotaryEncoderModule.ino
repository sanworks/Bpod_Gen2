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

// The rotary encoder module, powered by Teensy 3.5, interfaces Bpod with a 1024-position rotary encoder: Yumo E6B2-CWZ3E
// The serial interface allows the user to set position thresholds, which generate Bpod events when crossed.
// The 'T' command starts a trial, by setting the current position to '512' (of 1024).
// Position data points and corresponding timestamps are logged until a threshold is reached.
// The 'E' command exits a trial, before a threshold is reached.
// The MATLAB interface can then retrieve the last trial's position log, before starting the next trial.
// The MATLAB can also stream the current position to a plot, for diagnostics.
//
// Future versions of this software will log position to Teensy's microSD card (currently logged to sRAM memory).
// With effectively no memory limit, the firmware will allow continuous recording to the card for an entire behavior session.
// The board's exposed I2C pins will be configured to log external events with position data: either incoming I2C messages or TTL pulses.
// The firmware will also be configured to calculate speed online (for treadmill assays), and speed thresholds can trigger events.
// The number of programmable thresholds will be larger than 2, limited by sRAM memory.

#include "ArCOM.h"
#define SERIAL_TX_BUFFER_SIZE 256
#define SERIAL_RX_BUFFER_SIZE 256
ArCOM myUSB(SerialUSB); // USB is an ArCOM object. ArCOM wraps Arduino's SerialUSB interface, to
ArCOM StateMachineCOM(Serial3); // UART serial port
ArCOM InputStreamCOM(Serial2); // UART serial port
// simplify moving data types between Arduino and MATLAB/GNU Octave.

// Module setup
unsigned long FirmwareVersion = 1;
char moduleName[] = "RotaryEncoder"; // Name of module for manual override UI and state machine assembler
char* eventNames[] = {"L", "R"}; // Left and right threshold crossings (with respect to position at trial start).
byte nEventNames = (sizeof(eventNames)/sizeof(char *));

// Hardware setup
const byte EncoderPinA = 35;
const byte EncoderPinB = 36;
const byte EncoderPinZ = 37;

// Parameters
unsigned short leftThreshold = 412; // in range 0-1024, corresponding to 0-360 degrees
unsigned short rightThreshold = 612; // in range 0-1024, corresponding to 0-360 degrees

// State variables
boolean isStreaming = false; // If currently streaming position and time data
boolean isLogging = false; // If currently logging position and time to RAM memory
boolean inTrial = false; // If currently in a trial
int EncoderPos = 0; // Current position of the rotary encoder

// Program variables
byte opCode = 0;
byte param = 0;
boolean trialFinished = 0;
byte terminatingEvent = 0;
boolean EncoderPinAValue = 0;
boolean EncoderPinALastValue = 0;
boolean EncoderPinBValue = 0;
boolean posChange = 0;
word EncoderPos16Bit =  0;
const int dataMax = 10000;
unsigned long timeLog[dataMax] = {0};
unsigned short posLog[dataMax] = {0};
unsigned long choiceTime = 0;
unsigned int dataPos = 0;

unsigned long startTime = 0;
unsigned long currentTime = 0;
unsigned long timeFromStart = 0;

void setup() {
  // put your setup code here, to run once:
  SerialUSB.begin(115200);
  Serial3.begin(1312500);
  Serial2.begin(1312500);
  pinMode(EncoderPinA, INPUT);
  pinMode (EncoderPinB, INPUT);
  pinMode(13, OUTPUT);
  digitalWrite(13, HIGH);
}

void loop() {
  currentTime = millis();
  if (StateMachineCOM.available() > 0) {
    opCode = StateMachineCOM.readByte();
    switch (opCode) {
      case 255: // Return module name and info
        returnModuleInfo();
      break;
      case 'T':
        startTrial();
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
        startTrial();
      break;
      case 'E': // End trial
        inTrial = false;
        isLogging = false;
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
        }
      break;
      case 'A': // Program parameters (all at once)
        leftThreshold = myUSB.readUint16();
        rightThreshold = myUSB.readUint16();
        myUSB.writeByte(1);
      break;
      case 'R': // Return data
        isLogging = false;
        if (trialFinished) {
          trialFinished = false;
          myUSB.writeUint16(dataPos);
          myUSB.writeUint16Array(posLog,dataPos); 
          myUSB.writeUint32Array(timeLog,dataPos); 
          dataPos = 0;
        } else {
          dataPos = 0;
          myUSB.writeUint16(dataPos);
        }
      break;
      case 'Q': // Return current encoder position
        myUSB.writeUint16(EncoderPos);
      break;
      case 'X': // Exit
        isStreaming = false;
        isLogging = false;
        inTrial = false;
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
        StateMachineCOM.writeByte(terminatingEvent);
      }
      if (EncoderPos >= rightThreshold) {
        inTrial = false;
        terminatingEvent = 2;
        StateMachineCOM.writeByte(terminatingEvent);
      }
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
  StateMachineCOM.writeByte(65); // Acknowledge
  StateMachineCOM.writeUint32(FirmwareVersion); // 4-byte firmware version
  StateMachineCOM.writeByte(sizeof(moduleName)-1); // Length of module name
  StateMachineCOM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  StateMachineCOM.writeByte(1); // 1 if more info follows, 0 if not
  StateMachineCOM.writeByte('#'); // Op code for: Number of behavior events this module can generate
  StateMachineCOM.writeByte(2); // 2 thresholds
  StateMachineCOM.writeByte(1); // 1 if more info follows, 0 if not
  StateMachineCOM.writeByte('E'); // Op code for: Behavior event names
  StateMachineCOM.writeByte(nEventNames);
  for (int i = 0; i < nEventNames; i++) { // Once for each event name
    StateMachineCOM.writeByte(strlen(eventNames[i])); // Send event name length
    for (int j = 0; j < strlen(eventNames[i]); j++) { // Once for each character in this event name
      StateMachineCOM.writeByte(*(eventNames[i]+j)); // Send the character
    }
  }
  StateMachineCOM.writeByte(0); // 1 if more info follows, 0 if not
}

void startTrial() {
  EncoderPos = 512;
  dataPos = 0;
  startTime = currentTime;
  inTrial = true;
  isLogging = true;
  timeFromStart = 0;
}

