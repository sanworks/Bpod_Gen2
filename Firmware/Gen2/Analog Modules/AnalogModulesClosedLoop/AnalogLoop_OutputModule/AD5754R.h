/*
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2017 Sanworks LLC, Sound Beach, New York, USA

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

#ifndef AD5754R_h
#define AD5754R_h
#include "Arduino.h"
#include <SPI.h>

class AD5754R
{
public:
  // Constructor
  AD5754R(byte SyncPin, byte LDACPin, byte RefEnablePin);
  // DAC functions
  void SetOutput(uint8_t Channel, uint16_t Value);
  void setRange(byte rangeIndex);
  void dacWrite();
  void zeroDAC();
private:
  byte dacBuffer[3] = {0}; // Holds bytes to be written to the DAC
  union {
      byte byteArray[8];
      uint16_t uint16[4];
  } dacValues; // 16-Bit code of current sample on DAC output channels. A union type allows instant conversion between bytes and 16-bit ints
  byte SyncPin;
  byte LDACPin;
  byte RefEnablePin;
  byte rangeIndex = 3; // rangeIndex 0 = '0V:5V', 1 = '0V:10V', 2 = '0V:12V', 3 = '-5V:5V', 4 = '-10V:10V', 5 = '-12V:12V'
  uint16_t DACBits_ZeroVolts = 32768;
  void programDAC(byte Data1, byte Data2, byte Data3);
};
#endif
