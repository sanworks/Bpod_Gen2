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
// The 'T' command starts an experimental trial, by setting the current position to '0' (event thresholds in range +/-1024 = 1 rotation).
// Position data points and corresponding timestamps are logged until a threshold is reached.
// The 'E' command exits a trial, before a threshold is reached.
// The MATLAB interface can then retrieve the last trial's position log, and set new thresholds before starting the next trial.
// MATLAB can also stream the current position to a plot, for diagnostics.

#include "ArCOM.h"
#include <SPI.h>
#include "SdFat.h"
SdFatSdioEX SD;
#define SERIAL_TX_BUFFER_SIZE 256
#define SERIAL_RX_BUFFER_SIZE 256
ArCOM myUSB(SerialUSB); // USB is an ArCOM object. ArCOM wraps Arduino's SerialUSB interface, to
ArCOM StateMachineCOM(Serial3); // UART serial port
ArCOM OutputStreamCOM(Serial2); // UART serial port
// simplify moving data types between Arduino and MATLAB/GNU Octave.
File DataFile; // File on microSD card, to store position data

// Module setup
unsigned long FirmwareVersion = 1;
char moduleName[] = "RotaryEncoder"; // Name of module for manual override UI and state machine assembler
char* eventNames[] = {"L", "R"}; // Left and right threshold crossings (with respect to position at trial start).
byte nEventNames = (sizeof(eventNames)/sizeof(char *));

// Output stream setup
char outputStreamPrefix = 'F'; // Command character to send before each position value when streaming data via output stream jack

// Hardware setup
const byte EncoderPinA = 35;
const byte EncoderPinB = 36;
const byte EncoderPinZ = 37;

// Parameters
const byte nThresholds = 2;
int16_t thresholds[nThresholds] = {0}; // Initialized by client. Position range = -512 : 512 encoder tics, corresponding to -180 : +180 degrees
boolean thresholdActive[nThresholds] = {true}; // Thresholds are inactivated on crossing, until manually reset

// State variables
boolean isStreaming = false; // If currently streaming position and time data to the output-stream port
boolean sendEvents = true; // True if sending threshold crossing events to state machine
boolean isLogging = false; // If currently logging position and time to microSD memory
boolean inTrial = false; // If currently in a trial
boolean moduleStreaming = false; // If streaming position to a separate module via the output stream jack (preconfigured output for DDS module)
int16_t EncoderPos = 0; // Current position of the rotary encoder

// Program variables
byte opCode = 0;
byte opSource = 0;
byte param = 0;
boolean newOp = false;
boolean loggedDataAvailable = 0;
byte terminatingEvent = 0;
boolean EncoderPinAValue = 0;
boolean EncoderPinALastValue = 0;
boolean EncoderPinBValue = 0;
word EncoderPos16Bit =  0;
unsigned long choiceTime = 0;
unsigned long dataPos = 0;
unsigned long dataMax = 4294967295; // Maximim number of positions that can be logged (limited by 32-bit counter)
unsigned long startTime = 0;
unsigned long currentTime = 0;
unsigned long timeFromStart = 0;

// microSD variables
unsigned long nRemainderBytes = 0;
unsigned long nFullBufferReads = 0;
union {
    byte uint8[800];
    uint32_t int32[200];
} sdWriteBuffer;
const uint32_t sdReadBufferSize = 2048; // in bytes
uint8_t sdReadBuffer[sdReadBufferSize] = {0};

// Interrupt and position buffers
const uint32_t positionBufferSize = 1024;
int16_t positionBuffer[positionBufferSize] = {0};
int32_t timeBuffer[positionBufferSize] = {0};
uint32_t iPositionBuffer = 0;
boolean positionBufferFlag = false;

void setup() {
  // put your setup code here, to run once:
  SerialUSB.begin(115200);
  Serial3.begin(1312500);
  Serial2.begin(1312500);
  pinMode(EncoderPinA, INPUT);
  pinMode (EncoderPinB, INPUT);
  pinMode(13, OUTPUT);
  digitalWrite(13, HIGH);
  SPI.begin();
  SD.begin(); // Initialize microSD card
  SD.remove("Data.wfm");
  DataFile = SD.open("Data.wfm", FILE_WRITE);
  attachInterrupt(EncoderPinA, readNewPosition, RISING);
}

void loop() {
  currentTime = millis();
  if (myUSB.available() > 0) {
    opCode = myUSB.readByte();
    newOp = true;
    opSource = 0;
  } else if (StateMachineCOM.available() > 0) {
    opCode = StateMachineCOM.readByte();
    newOp = true;
    opSource= 1;
  } else if (OutputStreamCOM.available() > 0) {
    opCode = OutputStreamCOM.readByte();
    newOp = true;
    opSource = 2;
  }
  if (newOp) {
    newOp = false;
    switch(opCode) {
      case 255: // Return module name and info
        if (opSource == 1) { // If requested by state machine
          returnModuleInfo();
        }
      break;
      case 'C': // USB Handshake
        if (opSource == 0) {
          myUSB.writeByte(217);
        }
      break;
      case 'S': // Start USB streaming
        if (opSource == 0) {
          EncoderPos = 0; // Reset position
          isStreaming = true;
          startTime = currentTime;
        }
      break;
      case 'T': // Start trial
        startTrial();
      break;
      case 'E': // End trial
        inTrial = false;
        isLogging = false;
      break;
      case 'O': // Set output stream (on/off)
        moduleStreaming = readByteFromSource(opSource);
        if (opSource == 0) {
          myUSB.writeByte(1);
        }
      break;
      case 'V': // Set event transmission to state machine (on/off)
      if (opSource == 0) {
        sendEvents = myUSB.readByte();
        myUSB.writeByte(1);
      }
      break;
      case 'L': // Start logging
        startLogging();
      break;
      case 'F': // finish logging
        logCurrentPosition();
        isLogging = false;
        if (dataPos > 0) {
          loggedDataAvailable = true;
        }
      break;
      case 'H': // Program threshold
        if (opSource == 0) {
          param = myUSB.readByte(); // Read threshold index to program
          thresholds[param-1] = myUSB.readInt16();
          myUSB.writeByte(1);
        }
      break;
      case ';': // Enable/disable thresholds
        param = readByteFromSource(opSource);
        for (int i = 0; i < nThresholds; i++) {
          thresholdActive[i] = param;
        }
      break;
      case '#': // Zero position and enable thresholds
        EncoderPos = 0;
        for (int i = 0; i < nThresholds; i++) {
          thresholdActive[i] = true;
        }
      break;
      case 'A': // Program parameters (all at once)
        if (opSource == 0) {
          moduleStreaming = myUSB.readByte();
          sendEvents = myUSB.readByte();
          thresholds[0] = myUSB.readInt16();
          thresholds[1] = myUSB.readInt16();
          myUSB.writeByte(1);
        }
      break;
      case 'R': // Return data
        if (opSource == 0) {
          isLogging = false;
          if (loggedDataAvailable) {
            loggedDataAvailable = false;
            DataFile.seek(0);
            if (dataPos*8 > sdReadBufferSize) {
              nFullBufferReads = (unsigned long)(floor(((double)dataPos)*8 / (double)sdReadBufferSize));
            } else {
              nFullBufferReads = 0;
            }
            myUSB.writeUint32(dataPos);     
            for (int i = 0; i < nFullBufferReads; i++) { // Full buffer transfers; skipped if nFullBufferReads = 0
              DataFile.read(sdReadBuffer, sdReadBufferSize);
              myUSB.writeByteArray(sdReadBuffer, sdReadBufferSize);
            }
            nRemainderBytes = (dataPos*8)-(nFullBufferReads*sdReadBufferSize);
            if (nRemainderBytes > 0) {
              DataFile.read(sdReadBuffer, nRemainderBytes);
              myUSB.writeByteArray(sdReadBuffer, nRemainderBytes);     
            }           
            dataPos = 0;
          } else {
            myUSB.writeUint32(0);
          }
        }
      break;
      case 'Q': // Return current encoder position
        if (opSource == 0) {
          myUSB.writeInt16(EncoderPos);
        }
      break;
      case 'Z': // Zero current encoder position
        EncoderPos = 0;
      break;
      case 'X': // Exit
        isStreaming = false;
        isLogging = false;
        inTrial = false;
        dataPos = 0;
        EncoderPos = 0;
      break;
    } // End switch(opCode)
  } // End if (SerialUSB.available())

  if(positionBufferFlag) { // If new data points have been added since last loop
    positionBufferFlag = false;
    if (isStreaming) {
      for (int i = 0; i < iPositionBuffer; i++) {
        myUSB.writeInt16(positionBuffer[i]);
        myUSB.writeUint32(timeBuffer[i]);
      }
      myUSB.flush();
    }
    if (moduleStreaming) {
      for (int i = 0; i < iPositionBuffer; i++) {
        OutputStreamCOM.writeByte(outputStreamPrefix);
        OutputStreamCOM.writeUint32((positionBuffer[i]+512)*1000);
      }
    }
    if (inTrial) {
      int i = 0;
      while ((inTrial) && (i < iPositionBuffer)) {
        for (int j = 0; j < nThresholds; j++) {
           if (thresholds[j] < 0) {
              if (positionBuffer[i] <= thresholds[j]) {
                inTrial = false;
              }
           } else {
              if (positionBuffer[i] >= thresholds[j]) {
                inTrial = false;
              }
           }
           if (inTrial == false) {
              terminatingEvent = j+1;
              if (sendEvents) {
                StateMachineCOM.writeByte(terminatingEvent);
              }
           }
        }
        i++;
      }
      if (!inTrial) {
        startTime = currentTime;
        if (dataPos<dataMax) { // Add final data point
          logCurrentPosition();
        }
        isLogging = false; // Stop logging
        loggedDataAvailable = true;
      }
    } else { // If not in trial
      if (sendEvents) {
        for (int i = 0; i < nThresholds; i++) {
          if (thresholdActive[i]) {
             if (thresholds[i] < 0) {
                for (int j = 0; j < iPositionBuffer; j++) {
                  if (positionBuffer[j] <= thresholds[i]) {
                    thresholdActive[i] = false;
                    StateMachineCOM.writeByte(i+1);
                  }
                }
             } else {
                for (int j = 0; j < iPositionBuffer; j++) {
                  if (positionBuffer[j] >= thresholds[i]) {
                    thresholdActive[i] = false;
                    StateMachineCOM.writeByte(i+1);
                  }
                }
             }
          }
        }
      }
    }
    if (isLogging) {
      if (dataPos<dataMax) {
        logCurrentPosition();
      }
    }
    iPositionBuffer = 0;
  }
}

void readNewPosition() {
  // If this function was called, we already know encoder pin A was just driven high
  EncoderPinBValue = digitalRead(EncoderPinB);
  timeFromStart = currentTime - startTime;
  if (EncoderPinBValue == HIGH) {
    EncoderPos++;
  } else {
    EncoderPos--;
  }
  if (EncoderPos == -513) {
    EncoderPos = 512;
  } else if (EncoderPos == 513) {
    EncoderPos = -512;
  }
  positionBuffer[iPositionBuffer] = EncoderPos;
  timeBuffer[iPositionBuffer] = timeFromStart;
  iPositionBuffer++;
  positionBufferFlag = true;
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
  DataFile.seek(0);
  EncoderPos = 0;
  dataPos = 0;
  startTime = currentTime;
  inTrial = true;
  isLogging = true;
  timeFromStart = 0;
  iPositionBuffer = 0;
}

void startLogging() {
  DataFile.seek(0);
  dataPos = 0;
  startTime = currentTime;
  isLogging = true;
  timeFromStart = 0;
  iPositionBuffer = 0;
}

void logCurrentPosition() {
  if (iPositionBuffer > 0) {
    uint32_t bufPos = 0;
    for (int i = 0; i < iPositionBuffer; i++) {
      sdWriteBuffer.int32[bufPos] = positionBuffer[i];
      sdWriteBuffer.int32[bufPos+1] = timeBuffer[i];
      bufPos+=2;
    }
    DataFile.write(sdWriteBuffer.uint8, 8*iPositionBuffer);
    dataPos+=iPositionBuffer;
    iPositionBuffer = 0;
  }
}

byte readByteFromSource(byte opSource) {
  switch (opSource) {
    case 0:
      return myUSB.readByte();
    break;
    case 1:
      return StateMachineCOM.readByte();
    break;
    case 2:
      return OutputStreamCOM.readByte();
    break;
  }
}
