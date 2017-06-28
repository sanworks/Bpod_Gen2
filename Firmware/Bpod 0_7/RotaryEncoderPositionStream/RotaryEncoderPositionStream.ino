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
// This firmware streams the encoder position from the output stream port.
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
ArCOM OutputStreamCOM(Serial2); // UART serial port
// simplify moving data types between Arduino and MATLAB/GNU Octave.

// Module setup
unsigned long FirmwareVersion = 1;
char moduleName[] = "RotaryEncoder"; // Name of module for manual override UI and state machine assembler

// Hardware setup
const byte EncoderPinA = 35;
const byte EncoderPinB = 36;
const byte EncoderPinZ = 37;

// State variables
boolean isStreaming = true; // If currently streaming position and time data
int EncoderPos = 0; // Current position of the rotary encoder

// Program variables
byte opCode = 0;
byte param = 0;
boolean EncoderPinAValue = 0;
boolean EncoderPinALastValue = 0;
boolean EncoderPinBValue = 0;
boolean posChange = 0;
word EncoderPos16Bit =  0;

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
  if (StateMachineCOM.available() > 0) {
    opCode = StateMachineCOM.readByte();
    switch (opCode) {
      case 255: // Return module name and info
        returnModuleInfo();
      break;
    }
  }
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
      EncoderPos16Bit = (uint16_t)(((double)EncoderPos/1024)*65536);
      OutputStreamCOM.writeByte('R'); // Code to receive 16-bit sample
      for (int i = 0; i < 4; i++) { // Once for each output channel
        OutputStreamCOM.writeUint16(EncoderPos16Bit);
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
  StateMachineCOM.writeByte(0); // 1 if more info follows, 0 if not
}

