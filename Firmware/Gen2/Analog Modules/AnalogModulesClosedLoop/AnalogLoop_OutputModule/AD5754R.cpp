/*
----------------------------------------------------------------------------

This file is part of the Sanworks ArCOM repository
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

// Library for programming the AD5754R DAC as installed in the Bpod analog output module
// Josh Sanders, March 2017

#include <Arduino.h>
#include <SPI.h>
#include "AD5754R.h"

AD5754R::AD5754R(byte MySyncPin, byte MyLDACPin, byte MyRefEnablePin) {
  SyncPin = MySyncPin;
  LDACPin = MyLDACPin;
  RefEnablePin = MyRefEnablePin;
  pinMode(RefEnablePin, OUTPUT); // Reference enable pin sets the external reference IC output to 3V (RefEnable=high) or high impedence (RefEnable = low)
  digitalWrite(RefEnablePin, LOW); // Disabling external reference IC allows other voltage ranges with DAC internal reference
  pinMode(SyncPin, OUTPUT); // Configure SPI bus pins as outputs
  pinMode(LDACPin, OUTPUT);
  SPI.begin(); // Initialize SPI interface
  SPI.beginTransaction(SPISettings(30000000, MSBFIRST, SPI_MODE2)); // Set SPI parameters to DAC speed and bit order
  digitalWrite(LDACPin, LOW); // Ensure DAC load pin is at default level (low)
  programDAC(16, 0, 31); // Power up all channels + internal ref) (see AD5754R datasheet for valid arguments)
  programDAC(12, 0, 3); // Set initial output range to +/- 5V (see AD5754R datasheet for valid arguments)
  zeroDAC(); // Set all DAC channels to 0V
}

void AD5754R::setRange(byte rangeIndex) {
  switch(rangeIndex) {
    case 0:
      digitalWrite(RefEnablePin, LOW); // Disable external reference IC
      programDAC(16, 0, 31); // Power up all channels + internal ref)
      programDAC(12, 0, 0); // Set output range to 0-5V
      DACBits_ZeroVolts = 0; // Update 0V bit code
    break;
    case 1:
      digitalWrite(RefEnablePin, LOW); // Disable external reference IC
      programDAC(16, 0, 31); // Power up all channels + internal ref)
      programDAC(12, 0, 1); // Set output range to 0-10V
      DACBits_ZeroVolts = 0; // Update 0V bit code
    break;
    case 2:
      programDAC(16, 0, 15); // Power up all channels without internal reference
      digitalWrite(RefEnablePin, HIGH); // Enable external reference IC
      programDAC(12, 0, 1); // Set output range to 0-10V (using external ref, this setting = 0-12V)
      DACBits_ZeroVolts = 0; // Update 0V bit code
    break;
    case 3:
      digitalWrite(RefEnablePin, LOW); // Disable external reference IC
      programDAC(16, 0, 31); // Power up all channels + internal ref)
      programDAC(12, 0, 3); // Set output range to +/- 5V
      DACBits_ZeroVolts = 32768; // Update 0V bit code
    break;
    case 4:
      digitalWrite(RefEnablePin, LOW); // Disable external reference IC
      programDAC(16, 0, 31); // Power up all channels + internal ref)
      programDAC(12, 0, 4); // Set output range to +/- 10V
      DACBits_ZeroVolts = 32768; // Update 0V bit code
    break;
    case 5:
      programDAC(16, 0, 15); // Power up all channels without internal reference
      digitalWrite(RefEnablePin, HIGH); // Enable external reference IC
      programDAC(12, 0, 4); // Set output range to +/- 10V (using external ref, this setting = +/- 12V)
      DACBits_ZeroVolts = 32768; // Update 0V bit code
    break;
  }
  zeroDAC();
}

void AD5754R::programDAC(byte Data1, byte Data2, byte Data3) {
  digitalWrite(LDACPin,HIGH);
  digitalWrite(SyncPin,LOW);
  SPI.transfer (Data1);
  SPI.transfer (Data2);
  SPI.transfer (Data3);
  digitalWrite(SyncPin,HIGH);
  digitalWrite(LDACPin,LOW);
}

void AD5754R::SetOutput(uint8_t Channel, uint16_t Value) {
  dacValues.uint16[Channel] = Value;
}

void AD5754R::dacWrite() {
  digitalWrite(LDACPin,HIGH);
  digitalWrite(SyncPin,LOW);
  dacBuffer[0] = 3;
  dacBuffer[1] = dacValues.byteArray[1];
  dacBuffer[2] = dacValues.byteArray[0];
  SPI.transfer(dacBuffer,3);
  digitalWrite(SyncPin,HIGH);
  digitalWrite(SyncPin,LOW);
  dacBuffer[0] = 2;
  dacBuffer[1] = dacValues.byteArray[3];
  dacBuffer[2] = dacValues.byteArray[2];
  SPI.transfer(dacBuffer,3);
  digitalWrite(SyncPin,HIGH);
  digitalWrite(SyncPin,LOW);
  dacBuffer[0] = 0;
  dacBuffer[1] = dacValues.byteArray[5];
  dacBuffer[2] = dacValues.byteArray[4];
  SPI.transfer(dacBuffer,3);
  digitalWrite(SyncPin,HIGH);
  digitalWrite(SyncPin,LOW);
  dacBuffer[0] = 1;
  dacBuffer[1] = dacValues.byteArray[7];
  dacBuffer[2] = dacValues.byteArray[6];
  SPI.transfer(dacBuffer,3);
  digitalWrite(SyncPin,HIGH);
  digitalWrite(LDACPin,LOW);
}

void AD5754R::zeroDAC() { // Set DAC to mid-range (0V) on all channels
  for (int i = 0; i < 4; i++) {
    dacValues.uint16[i] = DACBits_ZeroVolts;
  }
  dacWrite(); // Update the DAC
}
