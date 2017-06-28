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

// Library for programming the AD7327 DAC as installed in the Bpod analog output module

#ifndef AD7327_h
#define AD7327_h
#include "Arduino.h"
#include <SPI.h>

class AD7327
{
public:
  // Constructor
  AD7327(byte ChipSelect);
  void readADC();
  void setRange(byte channel, byte newRangeIndex);
  void setNchannels(byte nChannels);
  union {
    byte uint8[16];
    uint16_t uint16[8];
  } analogData;
private:
  byte nChannelsToRead = 8;
  byte ChipSelect;
  uint16_t registerBuffer = 0;
  byte nChannels = 8;
  void writeRegisterBuffer();
  void setControlRegister();
  byte ADChannelMap[8] = {0, 1, 7, 6, 2, 3, 5, 4}; // ADC Channels as physically presented on the wire terminal connectors
  byte rangeIndexes[8] = {0};
};
#endif
