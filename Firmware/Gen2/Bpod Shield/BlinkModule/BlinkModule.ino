// BlinkModule blinks the LED on Pin13, to indicate the values of bytes that arrive 
// (i.e. byte 3 = 3 blinks, byte 105 = 105 blinks; better be patient)

#include "ArCOM.h" // Import serial communication wrapper

// Module setup
unsigned long FirmwareVersion = 1;
char moduleName[] = "BlinkModule"; // Name of module for manual override UI and state machine assembler
ArCOM Serial1COM(Serial1); // Wrap Serial5 (equivalent to Serial on Arduino Leonardo and Serial1 on Arduino Due)

// Variables
byte opCode = 0;

void setup()
{
  Serial1.begin(1312500);
  pinMode(13, OUTPUT); 
  digitalWrite(13, LOW);
}

void loop()
{
  if (Serial1COM.available()) {
    opCode = Serial1COM.readByte();
    switch(opCode) {
      case 255: // Return module name and info
        returnModuleInfo();
      break;
      default:
        for (int i = 0; i < opCode; i++) {
          digitalWrite(13, HIGH); delay(100);
          digitalWrite(13, LOW);  delay(100);
        }
      break;
    }  
  }
}

void returnModuleInfo() {
  Serial1COM.writeByte(65); // Acknowledge
  Serial1COM.writeUint32(FirmwareVersion); // 4-byte firmware version
  Serial1COM.writeByte(sizeof(moduleName)-1); // Length of module name
  Serial1COM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  Serial1COM.writeByte(0); // 1 if more info follows, 0 if not
}

