// SNES module interfaces the buttons of the SuperNintendo controller with Bpod.
// Each button press generates a behavior event with the following byte scheme:
// A = 1; B = 2; Up = 3; Down = 4; Left = 5; Right = 6; Start = 7;
// Bytes 8-14 = Each Button above, released.
// To use this library, connect the SNES controller to the Bpod Arduino shield as follows:
// Pin1 (flat end of connector) --> 3.3V, Pin2 --> Pin2, Pin3 --> Pin3, Pin4 --> Pin4, Pins 5-6: N/C, Pin7: GND 
// Note: The controller's native bit scheme is a 12-bit register. Bpod events (above) are rearranged for parsimony. The register reads: 
// 0=B; 1=Y; 2=Select; 3=Start; 4=Up; 5=Down; 6=Left; 7=Right; 8=A; 9=X; 10=Left (index finger trigger); 11=Right (index finger trigger).
#include "ArCOM.h" // Import serial communication wrapper

// Module setup
unsigned long FirmwareVersion = 1;
char moduleName[] = "SNES"; // Name of module for manual override UI and state machine assembler
char* eventNames[] = {"A", "B", "X", "Y", "U", "D", "L", "R", "Ltrg", "Rtrg", "Strt", "Slct", "A0", "B0", "X0", "Y0", "U0", "D0", "L0", "R0", "Ltrg0", "Rtrg0", "Strt0", "Slct0"};
byte nEventNames = (sizeof(eventNames)/sizeof(char *));
const byte buttonMap[] = {8, 0, 9, 1, 4, 5, 6, 7, 10, 11, 3, 2}; // Remapped codes from the SNES controller's native bit scheme (see comment above)
ArCOM Serial1COM(Serial1); // Wrap Serial5 (equivalent to Serial on Arduino Leonardo and Serial1 on Arduino Due)
const byte clockPin = 10;
const byte latchPin = 11;
const byte dataPin = 12;
const byte ledPin = 13;
unsigned long debounceTimer = 20; // Debounce timer - inactivates button briefly after a press or release (Milliseconds)

// Variables
byte opCode = 0;
const byte nButtons = sizeof(buttonMap); // Total number of buttons
boolean buttonState[12] = {true}; // State of each button on the controller (pressed or not). Fixed at size 12 by requirements of controller.
boolean lastButtonState[12] = {true}; // State of each button before the current read
byte events[nButtons*2] = {0}; // List of press or release events captured in the current cycle
unsigned long debounceStartTime[nButtons] = {0};
boolean inDebounce[nButtons] = {false};
byte nEvents = 0; // Number of events captured in the current cycle
byte currentButton = 0; // Current button
unsigned long currentTime = 0;

void setup()
{
  Serial1.begin(1312500);
  pinMode(clockPin, OUTPUT);
  pinMode(latchPin, OUTPUT);  
  pinMode(ledPin, OUTPUT);
  pinMode(dataPin, INPUT); 
  digitalWrite(clockPin, LOW);
  digitalWrite(latchPin, LOW);
}

void loop()
{
  currentTime = millis();
  if (Serial1COM.available()) {
    opCode = Serial1COM.readByte();
    switch(opCode) {
      case 255: // Return module name and info
        returnModuleInfo();
      break;
    }  
  }
  refreshController();
  nEvents = 0;
  for (int i = 0; i < nButtons; i++) {
    currentButton = buttonMap[i];
    if (!inDebounce[i]) {
      if (buttonState[currentButton] == false) {
        if (lastButtonState[currentButton] == true) {
          events[nEvents] = i+1; // Convert to MATLAB index 1
          Serial1.write(events[nEvents]);
          //SerialUSB.println(events[nEvents]);
          nEvents += 1;
          inDebounce[i] = true;
          debounceStartTime[i] = currentTime;
          digitalWriteDirect(ledPin, HIGH);
        }
      } else {
        if (lastButtonState[currentButton] == false) {
          events[nEvents] = i+nButtons+1;
          Serial1.write(events[nEvents]);
          //SerialUSB.println(events[nEvents]);
          nEvents += 1;
          inDebounce[i] = true;
          debounceStartTime[i] = currentTime;
          digitalWriteDirect(ledPin, LOW);
        }
      }
      lastButtonState[currentButton] = buttonState[currentButton];
    } else {
      if ((currentTime-debounceStartTime[i]) > debounceTimer) {
        inDebounce[i] = false;
      }
    }
  }
}

void refreshController() {
  digitalWriteDirect(latchPin, HIGH); // Updates register with button state
  digitalWriteDirect(latchPin, LOW);
  for (int i = 0; i < 12; i++) {
    buttonState[i] = digitalRead(dataPin);
    digitalWriteDirect(clockPin, HIGH); // Send a clock pulse to shift out the next bit
    digitalWriteDirect(clockPin, LOW);
  }
}

void returnModuleInfo() {
  Serial1COM.writeByte(65); // Acknowledge
  Serial1COM.writeUint32(FirmwareVersion); // 4-byte firmware version
  Serial1COM.writeByte(sizeof(moduleName)-1);
  Serial1COM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  Serial1COM.writeByte(1); // 1 if more info follows, 0 if not
  Serial1COM.writeByte('#'); // Op code for: Number of behavior events this module can generate
  Serial1COM.writeByte(24); // 12 buttons, 2 states each
  Serial1COM.writeByte(1); // 1 if more info follows, 0 if not
  Serial1COM.writeByte('E'); // Op code for: Behavior event names
  Serial1COM.writeByte(nEventNames);
  for (int i = 0; i < nEventNames; i++) { // Once for each event name
    Serial1COM.writeByte(strlen(eventNames[i])); // Send event name length
    for (int j = 0; j < strlen(eventNames[i]); j++) { // Once for each character in this event name
      Serial1COM.writeByte(*(eventNames[i]+j)); // Send the character
    }
  }
  Serial1COM.writeByte(0); // 1 if more info follows, 0 if not
}

void digitalWriteDirect(int PIN, boolean val){
  if(val)  PORT->Group[g_APinDescription[PIN].ulPort].OUTSET.reg = (1ul << g_APinDescription[PIN].ulPin);
  else     PORT->Group[g_APinDescription[PIN].ulPort].OUTCLR.reg = (1ul << g_APinDescription[PIN].ulPin);
}

