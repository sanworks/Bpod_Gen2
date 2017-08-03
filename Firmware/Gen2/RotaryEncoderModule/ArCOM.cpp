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
#include <Arduino.h>
#include "ArCOM.h"

ArCOM::ArCOM(Stream &s) {
  ArCOMstream = &s;  // Sets the interface (Serial, Serial1, SerialUSB, etc.)
}
unsigned int ArCOM::available() {
  return ArCOMstream->available();
}
void ArCOM::flush() {
  ArCOMstream->flush();
}
void ArCOM::writeByte(byte byte2Write) {
  ArCOMstream->write(byte2Write);
}
void ArCOM::writeUint8(byte byte2Write) {
  ArCOMstream->write(byte2Write);
}
void ArCOM::writeChar(char char2Write) {
  ArCOMstream->write(char2Write);
}
void ArCOM::writeUint16(unsigned short int2Write) {
   ArCOMstream->write((byte)int2Write);
   ArCOMstream->write((byte)(int2Write >> 8));
}

void ArCOM::writeUint32(unsigned long int2Write) {
    ArCOMstream->write((byte)int2Write);
    ArCOMstream->write((byte)(int2Write >> 8));
    ArCOMstream->write((byte)(int2Write >> 16));
    ArCOMstream->write((byte)(int2Write >> 24));
}
byte ArCOM::readByte(){
  while (ArCOMstream->available() == 0) {}
  return ArCOMstream->read();
}
byte ArCOM::readUint8(){
  while (ArCOMstream->available() == 0) {}
  return ArCOMstream->read();
}
char ArCOM::readChar(){
  while (ArCOMstream->available() == 0) {}
  return ArCOMstream->read();
}
unsigned short ArCOM::readUint16() {
  while (ArCOMstream->available() == 0) {}
  typeBuffer.byteArray[0] = ArCOMstream->read();
  while (ArCOMstream->available() == 0) {}
  typeBuffer.byteArray[1] = ArCOMstream->read();
  return typeBuffer.uint16;
}

unsigned long ArCOM::readUint32() {
  while (ArCOMstream->available() == 0) {}
  typeBuffer.byteArray[0] = ArCOMstream->read();
  while (ArCOMstream->available() == 0) {}
  typeBuffer.byteArray[1] = ArCOMstream->read();
  while (ArCOMstream->available() == 0) {}
  typeBuffer.byteArray[2] = ArCOMstream->read();
  while (ArCOMstream->available() == 0) {}
  typeBuffer.byteArray[3] = ArCOMstream->read();
  return typeBuffer.uint32;
}

void ArCOM::writeInt8(int8_t int2Write) {
  typeBuffer.int8 = int2Write;
  ArCOMstream->write(typeBuffer.byteArray[0]);
}

void ArCOM::writeInt16(int16_t int2Write) {
  typeBuffer.int16 = int2Write;
  ArCOMstream->write(typeBuffer.byteArray[0]);
  ArCOMstream->write(typeBuffer.byteArray[1]);
}

void ArCOM::writeInt32(int32_t int2Write) {
  typeBuffer.int32 = int2Write;
  ArCOMstream->write(typeBuffer.byteArray[0]);
  ArCOMstream->write(typeBuffer.byteArray[1]);
  ArCOMstream->write(typeBuffer.byteArray[2]);
  ArCOMstream->write(typeBuffer.byteArray[3]);
}

int8_t ArCOM::readInt8() {
  while (ArCOMstream->available() == 0) {}
  typeBuffer.byteArray[0] = ArCOMstream->read();
  return typeBuffer.int8;
}
int16_t ArCOM::readInt16() {
  while (ArCOMstream->available() == 0) {}
  typeBuffer.byteArray[0] = ArCOMstream->read();
  while (ArCOMstream->available() == 0) {}
  typeBuffer.byteArray[1] = ArCOMstream->read();
  return typeBuffer.int16;
}
int32_t ArCOM::readInt32() {
  while (ArCOMstream->available() == 0) {}
  typeBuffer.byteArray[0] = ArCOMstream->read();
  while (ArCOMstream->available() == 0) {}
  typeBuffer.byteArray[1] = ArCOMstream->read();
  while (ArCOMstream->available() == 0) {}
  typeBuffer.byteArray[2] = ArCOMstream->read();
  while (ArCOMstream->available() == 0) {}
  typeBuffer.byteArray[3] = ArCOMstream->read();
  return typeBuffer.int32;
}
void ArCOM::writeByteArray(byte numArray[], unsigned int nValues) {
  for (int i = 0; i < nValues; i++) {
    ArCOMstream->write(numArray[i]);
  }
}
void ArCOM::writeUint8Array(byte numArray[], unsigned int nValues) {
  for (int i = 0; i < nValues; i++) {
    ArCOMstream->write(numArray[i]);
  }
}
void ArCOM::writeCharArray(char charArray[], unsigned int nValues) {
  for (int i = 0; i < nValues; i++) {
    ArCOMstream->write(charArray[i]);
  }
}
void ArCOM::writeInt8Array(int8_t numArray[], unsigned int nValues) {
  for (int i = 0; i < nValues; i++) {
    typeBuffer.int8 = numArray[i];
    ArCOMstream->write(typeBuffer.byteArray[0]);
  }
}
void ArCOM::writeUint16Array(unsigned short numArray[], unsigned int nValues) {
  for (unsigned int i = 0; i < nValues; i++) {
    typeBuffer.uint16 = numArray[i];
    ArCOMstream->write(typeBuffer.byteArray[0]);
    ArCOMstream->write(typeBuffer.byteArray[1]);
  }
}
void ArCOM::writeInt16Array(int16_t numArray[], unsigned int nValues) {
  for (int i = 0; i < nValues; i++) {
    typeBuffer.int16 = numArray[i];
    ArCOMstream->write(typeBuffer.byteArray[0]);
    ArCOMstream->write(typeBuffer.byteArray[1]);
  }
}
void ArCOM::writeUint32Array(unsigned long numArray[], unsigned int nValues) {
  for (unsigned int i = 0; i < nValues; i++) {
    typeBuffer.uint32 = numArray[i];
    ArCOMstream->write(typeBuffer.byteArray[0]);
    ArCOMstream->write(typeBuffer.byteArray[1]);
    ArCOMstream->write(typeBuffer.byteArray[2]);
    ArCOMstream->write(typeBuffer.byteArray[3]);
  }
}
void ArCOM::writeInt32Array(long numArray[], unsigned int nValues) {
  for (unsigned int i = 0; i < nValues; i++) {
    typeBuffer.int32 = numArray[i];
    ArCOMstream->write(typeBuffer.byteArray[0]);
    ArCOMstream->write(typeBuffer.byteArray[1]);
    ArCOMstream->write(typeBuffer.byteArray[2]);
    ArCOMstream->write(typeBuffer.byteArray[3]);
  }
}
void ArCOM::readByteArray(byte numArray[], unsigned int nValues) {
  for (unsigned int i = 0; i < nValues; i++) {
    while (ArCOMstream->available() == 0) {}
    numArray[i] = ArCOMstream->read();
  }
}
void ArCOM::readUint8Array(byte numArray[], unsigned int nValues) {
  for (unsigned int i = 0; i < nValues; i++) {
    while (ArCOMstream->available() == 0) {}
    numArray[i] = ArCOMstream->read();
  }
}
void ArCOM::readCharArray(char charArray[], unsigned int nValues) {
  for (unsigned int i = 0; i < nValues; i++) {
    while (ArCOMstream->available() == 0) {}
    charArray[i] = ArCOMstream->read();
  }
}
void ArCOM::readInt8Array(int8_t numArray[], unsigned int nValues) {
  for (unsigned int i = 0; i < nValues; i++) {
    while (ArCOMstream->available() == 0) {}
    typeBuffer.byteArray[0] = ArCOMstream->read();
    numArray[i] = typeBuffer.int8;
  }
}
void ArCOM::readUint16Array(unsigned short numArray[], unsigned int nValues) {
  for (unsigned int i = 0; i < nValues; i++) {
    while (ArCOMstream->available() == 0) {}
    typeBuffer.byteArray[0] = ArCOMstream->read();
    while (ArCOMstream->available() == 0) {}
    typeBuffer.byteArray[1] = ArCOMstream->read();
    numArray[i] = typeBuffer.uint16;
  }
}
void ArCOM::readInt16Array(short numArray[], unsigned int nValues) {
  for (unsigned int i = 0; i < nValues; i++) {
    while (ArCOMstream->available() == 0) {}
    typeBuffer.byteArray[0] = ArCOMstream->read();
    while (ArCOMstream->available() == 0) {}
    typeBuffer.byteArray[1] = ArCOMstream->read();
    numArray[i] = typeBuffer.int16;
  }
}
void ArCOM::readUint32Array(unsigned long numArray[], unsigned int nValues) {
  for (unsigned int i = 0; i < nValues; i++) {
    while (ArCOMstream->available() == 0) {}
    typeBuffer.byteArray[0] = ArCOMstream->read();
    while (ArCOMstream->available() == 0) {}
    typeBuffer.byteArray[1] = ArCOMstream->read();
    while (ArCOMstream->available() == 0) {}
    typeBuffer.byteArray[2] = ArCOMstream->read();
    while (ArCOMstream->available() == 0) {}
    typeBuffer.byteArray[3] = ArCOMstream->read();
    numArray[i] = typeBuffer.uint32;
  }
}
void ArCOM::readInt32Array(long numArray[], unsigned int nValues) {
  for (unsigned int i = 0; i < nValues; i++) {
    while (ArCOMstream->available() == 0) {}
    typeBuffer.byteArray[0] = ArCOMstream->read();
    while (ArCOMstream->available() == 0) {}
    typeBuffer.byteArray[1] = ArCOMstream->read();
    while (ArCOMstream->available() == 0) {}
    typeBuffer.byteArray[2] = ArCOMstream->read();
    while (ArCOMstream->available() == 0) {}
    typeBuffer.byteArray[3] = ArCOMstream->read();
    numArray[i] = typeBuffer.int32;
  }
}
