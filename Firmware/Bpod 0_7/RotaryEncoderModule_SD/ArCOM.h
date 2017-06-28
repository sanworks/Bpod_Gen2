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
#ifndef ArCOM_h
#define ArCOM_h

#include "Arduino.h"

class ArCOM
{
protected:


public:
  // Constructor
  ArCOM(Stream &s);
  // Serial functions
  unsigned int available();
  void flush();
  // Unsigned integers
	void writeByte(byte byte2Write);
  void writeUint8(byte byte2Write);
  void writeChar(char char2Write);
  void writeByteArray(byte numArray[], unsigned int size);
  void writeUint8Array(byte numArray[], unsigned int size);
  void writeCharArray(char charArray[], unsigned int size);
  void writeUint16(uint16_t int2Write);
  void writeUint16Array(unsigned short numArray[], unsigned int size);
  void writeUint32(uint32_t int2Write);
  void writeUint32Array(unsigned long numArray[], unsigned int size);
  byte readByte();
  byte readUint8();
  char readChar();
  void readByteArray(byte numArray[], unsigned int size);
  void readUint8Array(byte numArray[], unsigned int size);
  void readCharArray(char charArray[], unsigned int size);
  uint16_t readUint16();
  void readUint16Array(unsigned short numArray[], unsigned int size);
  uint32_t readUint32();
  void readUint32Array(unsigned long numArray[], unsigned int size);

  // Signed integers
  void writeInt8(int8_t int2Write);
  void writeInt8Array(int8_t numArray[], unsigned int size);
  void writeInt16(int16_t int2Write);
  void writeInt16Array(int16_t numArray[], unsigned int size);
  void writeInt32(int32_t int2Write);
  void writeInt32Array(int32_t numArray[], unsigned int size);
  int8_t readInt8();
  void readInt8Array(int8_t numArray[], unsigned int size);
  int16_t readInt16();
  void readInt16Array(int16_t numArray[], unsigned int size);
  int32_t readInt32();
  void readInt32Array(int32_t numArray[], unsigned int size);

private:
  Stream *ArCOMstream; // Stores the interface (Serial, Serial1, SerialUSB, etc.)
  union {
    byte byteArray[4];
    uint16_t uint16;
    uint32_t uint32;
    int8_t int8;
    int16_t int16;
    int32_t int32;
} typeBuffer;

};
#endif
