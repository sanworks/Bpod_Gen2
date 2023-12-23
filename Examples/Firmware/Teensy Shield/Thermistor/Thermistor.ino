/*
  ----------------------------------------------------------------------------

  This file is part of the Sanworks Bpod_Gen2 repository
  Copyright (C) Sanworks LLC, Rochester, New York, USA

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

#include "ArCOM.h" // Import serial communication wrapper

// Module setup
ArCOM Serial1COM(Serial1); // Wrap Serial1 (UART on Arduino M0, Due + Teensy 3.X)
char moduleName[] = "Thermo"; // Name of module for manual override UI and state machine assembler
#define FirmwareVersion 1

// Variables
byte opCode = 0;
uint16_t thresholdLow = 800;
uint16_t thresholdHigh = 830;
boolean isActive = true;
uint16_t sensorValue = 0; // Thermistor analog value

void setup()
{
  Serial1.begin(1312500);
  
}

void loop()
{
  sensorValue = analogRead(A9);
  if (Serial1COM.available()) {
    opCode = Serial1COM.readByte();
    if (opCode == 255) {
      returnModuleInfo();
    }
  }
  if ((sensorValue < thresholdLow) && isActive) {
    Serial1COM.writeByte(1);
    isActive = false;
  }
  if (sensorValue > thresholdHigh) {
    isActive = true;
  }

}

void returnModuleInfo() {
  Serial1COM.writeByte(65); // Acknowledge
  Serial1COM.writeUint32(FirmwareVersion); // 4-byte firmware version
  Serial1COM.writeByte(sizeof(moduleName)-1);
  Serial1COM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  Serial1COM.writeByte(0); // 1 if more info follows, 0 if not
}
