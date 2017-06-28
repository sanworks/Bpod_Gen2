/*{
----------------------------------------------------------------------------

This file is part of the Bpod Project
Copyright (C) 2014 Joshua I. Sanders, Cold Spring Harbor Laboratory, NY, USA

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
#include <SPI.h>
#include <Ethernet.h>
EthernetClient client;
byte mac[] = {0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED};
int port = 0; // Actual port will be received later
byte commandByte = 0; 
byte inByteLow = 0; byte inByteHigh = 0;
byte IP1 = 0; byte IP2 = 0; byte IP3 = 0; byte IP4 = 0;
byte StringNum = 0;
byte StringLength = 0;
byte MessageMode = 0; // set to 1 to connect, send and disconnect with each message. Set to 0 to only send.
String String1 = "";
String String2 = "";
String String3 = "";
String String4 = "";
String String5 = "";
String String6 = "";
String String7 = "";
String String8 = "";
String String9 = "";
String String10 = "";
String String11 = "";
String String12 = "";
String String13 = "";
String String14 = "";
String String15 = "";
String String16 = "";
String String17 = "";
String String18 = "";
String String19 = "";
String String20 = "";
String String21 = "";
String String22 = "";
String String23 = "";
String String24 = "";
String String25 = "";
String String26 = "";
String String27 = "";
String String28 = "";
String String29 = "";
String String30 = "";
String String31 = "";
String String32 = "";
IPAddress serverIP(0,0,0,0);

void setup()  
{
  Serial.begin(115200);
  Serial1.begin(115200);
  pinMode(18, OUTPUT);
}

void loop() {
  if (Serial.available()){
    commandByte = Serial.read();
    switch(commandByte) {
      case 'I': // Read a new ip and bring up the network
        Ethernet.begin(mac);
        Serial.write(1);
        break;
      case 'C': // Read server ip + port and connect
        while (Serial.available() == 0) {}
        IP1 = Serial.read();
        while (Serial.available() == 0) {}
        IP2 = Serial.read();
        while (Serial.available() == 0) {}
        IP3 = Serial.read();
        while (Serial.available() == 0) {}
        IP4 = Serial.read();
        serverIP[0] = IP1; serverIP[1] = IP2;  serverIP[2] = IP3;  serverIP[3] = IP4; 
        while (Serial.available() == 0) {}
        inByteLow = Serial.read();
        while (Serial.available() == 0) {}
        inByteHigh = Serial.read();
        port = word(inByteHigh, inByteLow);
        if (client.connect(serverIP, port)) {
          Serial.write(1);
        }
        break;
      case 'L': // Load a string into a slot
        while (Serial.available() == 0) {}
        StringNum = Serial.read();
        while (Serial.available() == 0) {}
        StringLength = Serial.read();
        switch (StringNum) {
          case 1: String1 = ""; break;
          case 2: String2 = ""; break;
          case 3: String3 = ""; break;
          case 4: String4 = ""; break;
          case 5: String5 = ""; break;
          case 6: String6 = ""; break;
          case 7: String7 = ""; break;
          case 8: String8 = ""; break;
          case 9: String9 = ""; break;
          case 10: String10 = ""; break;
          case 11: String11 = ""; break;
          case 12: String12 = ""; break;
          case 13: String13 = ""; break;
          case 14: String14 = ""; break;
          case 15: String15 = ""; break;
          case 16: String16 = ""; break;
          case 17: String17 = ""; break;
          case 18: String18 = ""; break;
          case 19: String19 = ""; break;
          case 20: String20 = ""; break;
          case 21: String21 = ""; break;
          case 22: String22 = ""; break;
          case 23: String23 = ""; break;
          case 24: String24 = ""; break;
          case 25: String25 = ""; break;
          case 26: String26 = ""; break;
          case 27: String27 = ""; break;
          case 28: String28 = ""; break;
          case 29: String29 = ""; break;
          case 30: String30 = ""; break;
          case 31: String31 = ""; break;
          case 32: String32 = ""; break;
        }
        for (int i = 0; i < StringLength; i++) {
          while (Serial.available() == 0) {}
          inByteLow = Serial.read();
          switch (StringNum) {
            case 1: String1 = String1 + char(inByteLow); break;
            case 2: String2 = String2 + char(inByteLow); break;
            case 3: String3 = String3 + char(inByteLow); break;
            case 4: String4 = String4 + char(inByteLow); break;
            case 5: String5 = String5 + char(inByteLow); break;
            case 6: String6 = String6 + char(inByteLow); break;
            case 7: String7 = String7 + char(inByteLow); break;
            case 8: String8 = String8 + char(inByteLow); break;
            case 9: String9 = String9 + char(inByteLow); break;
            case 10: String10 = String10 + char(inByteLow); break;
            case 11: String11 = String11 + char(inByteLow); break;
            case 12: String12 = String12 + char(inByteLow); break;
            case 13: String13 = String13 + char(inByteLow); break;
            case 14: String14 = String14 + char(inByteLow); break;
            case 15: String15 = String15 + char(inByteLow); break;
            case 16: String16 = String16 + char(inByteLow); break;
            case 17: String17 = String17 + char(inByteLow); break;
            case 18: String18 = String18 + char(inByteLow); break;
            case 19: String19 = String19 + char(inByteLow); break;
            case 20: String20 = String20 + char(inByteLow); break;
            case 21: String21 = String21 + char(inByteLow); break;
            case 22: String22 = String22 + char(inByteLow); break;
            case 23: String23 = String23 + char(inByteLow); break;
            case 24: String24 = String24 + char(inByteLow); break;
            case 25: String25 = String25 + char(inByteLow); break;
            case 26: String26 = String26 + char(inByteLow); break;
            case 27: String27 = String27 + char(inByteLow); break;
            case 28: String28 = String28 + char(inByteLow); break;
            case 29: String29 = String29 + char(inByteLow); break;
            case 30: String30 = String30 + char(inByteLow); break;
            case 31: String31 = String31 + char(inByteLow); break;
            case 32: String32 = String32 + char(inByteLow); break;
          }    
        }
        break;
      case 'T': // Trigger a string from USB
        while (Serial.available() == 0) {}
        StringNum = Serial.read();
        TriggerString(StringNum);
        break;
      case 'M': // Set message mode
        while (Serial.available() == 0) {}
        MessageMode = Serial.read();
      break;
      case 'X': // Disconnect
        client.stop();
      break;
    } 
  }
  if (Serial1.available()) {
    StringNum = Serial1.read();
    TriggerString(StringNum);
  }
}

void TriggerString(byte StringNum) {
  switch (StringNum) {
        case 1: client.println(String1); break;
        case 2: client.println(String2); break;
        case 3: client.println(String3); break;
        case 4: client.println(String4); break;
        case 5: client.println(String5); break;
        case 6: client.println(String6); break;
        case 7: client.println(String7); break;
        case 8: client.println(String8); break;
        case 9: client.println(String9); break;
        case 10: client.println(String10); break;
        case 11: client.println(String11); break;
        case 12: client.println(String12); break;
        case 13: client.println(String13); break;
        case 14: client.println(String14); break;
        case 15: client.println(String15); break;
        case 16: client.println(String16); break;
        case 17: client.println(String17); break;
        case 18: client.println(String18); break;
        case 19: client.println(String19); break;
        case 20: client.println(String20); break;
        case 21: client.println(String21); break;
        case 22: client.println(String22); break;
        case 23: client.println(String23); break;
        case 24: client.println(String24); break;
        case 25: client.println(String25); break;
        case 26: client.println(String26); break;
        case 27: client.println(String27); break;
        case 28: client.println(String28); break;
        case 29: client.println(String29); break;
        case 30: client.println(String30); break;
        case 31: client.println(String31); break;
        case 32: client.println(String32); break;
   }
   if (MessageMode == 1) {
      client.stop();
      client.connect(serverIP, port);
    }
}
