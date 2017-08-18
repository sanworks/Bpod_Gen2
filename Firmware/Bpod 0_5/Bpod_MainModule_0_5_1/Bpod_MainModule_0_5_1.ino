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
// Bpod Finite State Machine v 0.5
// Requires the DueTimer library from:
// https://github.com/ivanseidel/DueTimer
#include <DueTimer.h>
#include <SPI.h>
byte FirmwareBuildVersion = 6;
//////////////////////////////
// Hardware mapping:         /
//////////////////////////////

//     8 Sensor/Valve/LED Ports
byte PortDigitalInputLines[8] = {28, 30, 32, 34, 36, 38, 40, 42};
byte PortPWMOutputLines[8] = {9, 8, 7, 6, 5, 4, 3, 2};
byte PortAnalogInputLines[8] = {0, 1, 2, 3, 4, 5, 6, 7};

//     wire
byte WireDigitalInputLines[4] = {35, 33, 31, 29};
byte WireDigitalOutputLines[4] = {43, 41, 39, 37};

//     SPI device latch pins
byte ValveRegisterLatch = 22;
byte SyncRegisterLatch = 23;

//      Bnc
byte BncOutputLines[2] = {25, 24};
byte BncInputLines[2] = {11, 10};

//      Indicator
byte RedLEDPin = 13;
byte GreenLEDPin = 14;
byte BlueLEDPin = 12;


//////////////////////////////////
// Initialize system state vars: /
//////////////////////////////////

byte PortPWMOutputState[8] = {0}; // State of all 8 output lines (As 8-bit PWM value from 0-255 representing duty cycle. PWM cycles at 1KHZ)
byte PortValveOutputState = 0;   // State of all 8 valves
byte PortInputsEnabled[8] = {0}; // Enabled or disabled input reads of port IR lines
byte WireInputsEnabled[4] = {0}; // Enabled or disabled input reads of wire lines
boolean PortInputLineValue[8] = {0}; // Direct reads of digital values of IR beams
boolean PortInputLineOverride[8] = {0}; // set to 1 if user created a virtual input, to prevent hardware reads until user returns it to low
boolean PortInputLineLastKnownStatus[8] = {0}; // Last known status of IR beams
boolean BNCInputLineValue[2] = {0}; // Direct reads of BNC input lines
boolean BNCInputLineOverride[2] = {0}; // Set to 1 if user created a virtual BNC high event, to prevent hardware reads until user returns low
boolean BNCInputLineLastKnownStatus[2] = {0}; // Last known status of BNC input lines 
boolean WireInputLineValue[4] = {0}; // Direct reads of Wire terminal input lines
boolean WireInputLineOverride[2] = {0}; // Set to 1 if user created a virtual wire high event, to prevent hardware reads until user returns low
boolean WireInputLineLastKnownStatus[4] = {0}; // Last known status of Wire terminal input lines 
boolean MatrixFinished = false; // Has the system exited the matrix (final state)?
boolean MatrixAborted = false; // Has the user aborted the matrix before the final state?
boolean MeaningfulStateTimer = false; // Does this state's timer get us to another state when it expires?
int CurrentState = 1; // What state is the state machine currently in? (State 0 is the final state)
int NewState = 1;
byte CurrentEvent[10] = {0}; // What event code just happened and needs to be handled. Up to 10 can be acquired per 30us loop.
byte nCurrentEvents = 0; // Index of current event
byte SoftEvent = 0; // What soft event code just happened


//////////////////////////////////
// Initialize general use vars:  /
//////////////////////////////////

byte CommandByte = 0;  // Op code to specify handling of an incoming USB serial message
byte VirtualEventTarget = 0; // Op code to specify which virtual event type (Port, BNC, etc)
byte VirtualEventData = 0; // State of target
int nWaves = 0; // number of scheduled waves registered
byte CurrentWave = 0; // Scheduled wave currently in use
byte LowByte = 0; // LowByte through FourthByte are used for reading bytes that will be combined to 16 and 32 bit integers
byte SecondByte = 0; byte ThirdByte = 0; byte FourthByte = 0;
byte Byte1 = 0; byte Byte2 = 0; byte Byte3 = 0; byte Byte4 = 0; // Temporary storage of command and param values read from serial port
unsigned long LongInt = 0;
int nStates = 0;
int nEvents = 0;
int LEDBrightnessAdjustInterval = 5;
byte LEDBrightnessAdjustDirection = 1;
byte LEDBrightness = 0;
byte InputStateMatrix[128][40] = {0}; // Matrix containing all of Bpod's inputs and corresponding state transitions
// Cols: 0-15 = IR beam in...out... 16-19 = BNC1 high...low 20-27 = wire1high...low 28-37=SoftEvents 38=Unused  39=Tup  

byte OutputStateMatrix[128][17] = {0}; // Matrix containing all of Bpod's output actions for each Input state
// Cols: 0=Valves 1=BNC 2=Wire 3=Hardware serial 1 (UART) 4=Hardware Serial 2 (UART) 5 = SoftCode 5=GlobalTimerTrig 6=GlobalTimerCancel 
// 7 = GlobalCounterReset 8-15=PWM values (LED channel on port interface board)

byte GlobalTimerMatrix[128][5] = {0}; // Matrix contatining state transitions for global timer elapse events
byte GlobalCounterMatrix[128][5] = {0}; // Matrix contatining state transitions for global counter threshold events
boolean GlobalTimersActive[5] = {0}; // 0 if timer x is inactive, 1 if it's active.
unsigned long GlobalTimerEnd[5] = {0}; // Future Times when active global timers will elapse
unsigned long GlobalTimers[5] = {0}; // Timers independent of states
unsigned long GlobalCounterCounts[5] = {0}; // Event counters 
byte GlobalCounterAttachedEvents[5] = {254}; // Event each event counter is attached to 
unsigned long GlobalCounterThresholds[5] = {0}; // Event counter thresholds (trigger events if crossed)
unsigned long TimeStamps[10000] = {0}; // TimeStamps for events on this trial
int MaxTimestamps = 10000; // Maximum number of timestamps (to check when to start event-dropping)
int CurrentColumn = 0; // Used when re-mapping event codes to columns of global timer and counter matrices
unsigned long StateTimers[128] = {0}; // Timers for each state
unsigned long StartTime = 0; // System Start Time
unsigned long MatrixStartTime = 0; // Trial Start Time
unsigned long MatrixStartTimeMillis = 0; // Used for 32-bit timer wrap-over correction in client
unsigned long StateStartTime = 0; // Session Start Time
unsigned long NextLEDBrightnessAdjustTime = 0;
byte ConnectedToClient = 0;
unsigned long CurrentTime = 0; // Current time (units = timer cycles since start; used to control state transitions)
unsigned long TimeFromStart = 0;
unsigned long Num2Break = 0; // For conversion from int32 to bytes
unsigned long SessionStartTime = 0;
byte connectionState = 0; // 1 if connected to MATLAB
byte RunningStateMatrix = 0; // 1 if state matrix is running

void setup() {
  for (int x = 0; x < 8; x++) {
     pinMode(PortDigitalInputLines[x], INPUT_PULLUP);
     pinMode(PortPWMOutputLines[x], OUTPUT);
     analogWrite(PortPWMOutputLines[x], 0);
   }
   for (int x = 0; x < 4; x++) {
     pinMode(WireDigitalInputLines[x], INPUT_PULLUP);
     pinMode(WireDigitalOutputLines[x], OUTPUT);
   }
   for (int x = 0; x < 2; x++) {
     pinMode(BncInputLines[x], INPUT);
     pinMode(BncOutputLines[x], OUTPUT);
   }
   pinMode(ValveRegisterLatch, OUTPUT);
   pinMode(SyncRegisterLatch, OUTPUT);
   pinMode(RedLEDPin, OUTPUT);
   pinMode(GreenLEDPin, OUTPUT);
   pinMode(BlueLEDPin, OUTPUT);
   SerialUSB.begin(115200);
   Serial1.begin(115200);
   Serial2.begin(115200);
   SPI.begin();
   SetWireOutputLines(0);
   SetBNCOutputLines(0);
   updateStatusLED(0);
   ValveRegWrite(0);
   Timer3.attachInterrupt(handler);
  Timer3.start(100); // Runs every 100us
}

void loop() {
  
}

void handler() {
  if (connectionState == 0) {
    updateStatusLED(1);
  }
  if (SerialUSB.available() > 0) {
  CommandByte = SerialUSB.read();  // P for Program, R for Run, O for Override, 6 for Device ID
  switch (CommandByte) {
    case '6':  // Initialization handshake
      connectionState = 1;
      updateStatusLED(2);
      SerialUSB.print(5);
      delayMicroseconds(100000);
      SerialUSB.flush();
      SessionStartTime = millis();
      break;
    case 'F':  // Return firmware build number
      SerialUSB.write(FirmwareBuildVersion);
      ConnectedToClient = 1;
      break;
    case 'O':  // Override hardware state
      manualOverrideOutputs();
      break;
    case 'I': // Read and return digital input line states
        Byte1 = SerialReadByte();
        Byte2 = SerialReadByte();
        switch (Byte1) {
          case 'B': // Read BNC input line
            Byte3 = digitalReadDirect(BncInputLines[Byte2]);
          break;
          case 'P': // Read port digital input line
            Byte3 = digitalReadDirect(PortDigitalInputLines[Byte2]);
          break;
          case 'W': // Read wire digital input line
            Byte3 = digitalReadDirect(WireDigitalInputLines[Byte2]);
          break;
        }
        SerialUSB.write(Byte3);
        break;
    case 'Z':  // Bpod governing machine has closed the client program
      ConnectedToClient = 0;
      connectionState = 0;
      SerialUSB.write('1');
      updateStatusLED(0);
      break;
    case 'S': // Soft code. 
        VirtualEventTarget = SerialReadByte();
        VirtualEventData = SerialReadByte();
      break;
    case 'H': // Recieve byte from USB and send to serial module 1 or 2
        Byte1 = SerialReadByte();
        Byte2 = SerialReadByte();
        if (Byte1 == 1) {
            Serial1.write(Byte2);
        } else if (Byte1 == 2) {
            Serial2.write(Byte2);
        }
     break;
    case 'V': // Manual override: execute virtual event
    VirtualEventTarget = SerialReadByte();
    VirtualEventData = SerialReadByte();
    if (RunningStateMatrix) { 
        switch (VirtualEventTarget) {
          case 'P': // Virtual poke PortInputLineLastKnownStatus
            if (PortInputLineLastKnownStatus[VirtualEventData] == LOW) {
              PortInputLineValue[VirtualEventData] = HIGH;
              PortInputLineOverride[VirtualEventData] = true;
            } else {
              PortInputLineValue[VirtualEventData] = LOW;
              PortInputLineOverride[VirtualEventData] = false;
            }
            break;
            case 'B': // Virtual BNC input
              if (BNCInputLineLastKnownStatus[VirtualEventData] == LOW) {
                BNCInputLineValue[VirtualEventData] = HIGH;
                BNCInputLineOverride[VirtualEventData] = true;
              } else {
                BNCInputLineValue[VirtualEventData] = LOW;
                BNCInputLineOverride[VirtualEventData] = false;
              }
              break;
            case 'W': // Virtual Wire input
              if (WireInputLineLastKnownStatus[VirtualEventData] == LOW) {
                  WireInputLineValue[VirtualEventData] = HIGH;
                  WireInputLineOverride[VirtualEventData] = true;
                } else {
                  WireInputLineValue[VirtualEventData] = LOW;
                  WireInputLineOverride[VirtualEventData] = false;
                }
            break;
            case 'S':  // Soft event
                  SoftEvent = VirtualEventData;
            break;
          }
    } break;
    case 'P':  // Get new state matrix from client
      nStates = SerialReadByte();
      // Get Input state matrix
      for (int x = 0; x < nStates; x++) {
        for (int y = 0; y < 40; y++) {
          InputStateMatrix[x][y] = SerialReadByte();
        }
      }
      // Get Output state matrix
      for (int x = 0; x < nStates; x++) {
        for (int y = 0; y < 17; y++) {
          OutputStateMatrix[x][y] = SerialReadByte();
        }
      }
      // Get global timer matrix
      for (int x = 0; x < nStates; x++) {
        for (int y = 0; y < 5; y++) {
          GlobalTimerMatrix[x][y] = SerialReadByte();
        }
      }
      // Get global counter matrix
      for (int x = 0; x < nStates; x++) {
        for (int y = 0; y < 5; y++) {
          GlobalCounterMatrix[x][y] = SerialReadByte();
        }
      }
      // Get global counter attached events
      for (int x = 0; x < 5; x++) {
          GlobalCounterAttachedEvents[x] = SerialReadByte();
      }
      // Get input channel configurtaion
      for (int x = 0; x < 8; x++) {
          PortInputsEnabled[x] = SerialReadByte();
      }
      for (int x = 0; x < 4; x++) {
          WireInputsEnabled[x] = SerialReadByte();
      }
      
      // Get state timers
      for (int x = 0; x < nStates; x++) {
              StateTimers[x] = SerialReadLong();
      }
      // Get global timers
      for (int x = 0; x < 5; x++) {
              GlobalTimers[x] = SerialReadLong();
      }
      // Get global counter event count thresholds
      for (int x = 0; x < 5; x++) {
          GlobalCounterThresholds[x] = SerialReadLong();
      }
      SerialUSB.write(1);
      break;
      case 'R':  // Run State Matrix
      updateStatusLED(3);
      NewState = 0;
      CurrentState = 0;
      nEvents = 0;
      SoftEvent = 254; // No event
      MatrixFinished = false;

      // Reset event counters
      for (int x = 0; x < 5; x++) {
        GlobalCounterCounts[x] = 0;
      }
      // Read initial state of sensors      
      for (int x = 0; x < 8; x++) {
        if (PortInputsEnabled[x] == 1) { 
          PortInputLineValue[x] = digitalReadDirect(PortDigitalInputLines[x]); // Read each photogate's current state into an array
          if (PortInputLineValue[x] == HIGH) {PortInputLineLastKnownStatus[x] = HIGH;} else {PortInputLineLastKnownStatus[x] = LOW;} // Update last known state of input line
        } else {
          PortInputLineLastKnownStatus[x] = LOW; PortInputLineValue[x] = LOW;
        }
        PortInputLineOverride[x] = false; 
      }
      for (int x = 0; x < 2; x++) {
        BNCInputLineValue[x] = digitalReadDirect(BncInputLines[x]);
        if (BNCInputLineValue[x] == HIGH) {BNCInputLineLastKnownStatus[x] = true;} else {BNCInputLineLastKnownStatus[x] = false;}
        BNCInputLineOverride[x] = false; 
      }
      for (int x = 0; x < 4; x++) {
        if (WireInputsEnabled[x] == 1) { 
          WireInputLineValue[x] = digitalReadDirect(WireDigitalInputLines[x]);
          if (WireInputLineValue[x] == HIGH) {WireInputLineLastKnownStatus[x] = true;} else {WireInputLineLastKnownStatus[x] = false;}
        }
        WireInputLineOverride[x] = false; 
      }
      // Reset timers
      MatrixStartTime = 0;
      StateStartTime = MatrixStartTime;
      CurrentTime = MatrixStartTime;
      MatrixStartTimeMillis = millis();
      // Adjust outputs, scheduled waves, serial codes and sync port for first state
      setStateOutputs(CurrentState);
      RunningStateMatrix = 1;
      break;
      case 'X':   // Exit state matrix and return data
      MatrixFinished = true;
      RunningStateMatrix = false;
      setStateOutputs(0); // Returns all lines to low by forcing final state
      break;
    } // End switch commandbyte
  } // End SerialUSB.available
  
  if (RunningStateMatrix) {
    nCurrentEvents = 0;
    CurrentEvent[0] = 254; // Event 254 = No event
    CurrentTime++;
           // Refresh state of sensors and inputs
           for (int x = 0; x < 8; x++) {
             if ((PortInputsEnabled[x] == 1) && (!PortInputLineOverride[x])) {
              PortInputLineValue[x] = digitalReadDirect(PortDigitalInputLines[x]);
             }
          }
          for (int x = 0; x < 2; x++) {
            if (!PortInputLineOverride[x]) {
              BNCInputLineValue[x] = digitalReadDirect(BncInputLines[x]);
            }
          }
          for (int x = 0; x < 4; x++) {
            if ((WireInputsEnabled[x] == 1) && (!WireInputLineOverride[x])) { 
              WireInputLineValue[x] = digitalReadDirect(WireDigitalInputLines[x]);
            }
          }
         // Determine which port event occurred
         int Ev = 0; // Since port-in and port-out events are indexed sequentially, Ev replaces x in the loop.
         for (int x = 0; x < 8; x++) {
               // Determine port entry events
               if ((PortInputLineValue[x] == HIGH) && (PortInputLineLastKnownStatus[x] == LOW)) {
                  PortInputLineLastKnownStatus[x] = HIGH; CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
               }
               Ev = Ev + 1;
               // Determine port exit events
               if ((PortInputLineValue[x] == LOW) && (PortInputLineLastKnownStatus[x] == HIGH)) {
                  PortInputLineLastKnownStatus[x] = LOW; CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
               }
               Ev = Ev + 1;
         }
         // Determine which BNC event occurred
         for (int x = 0; x < 2; x++) { 
           // Determine BNC low-to-high events
           if ((BNCInputLineValue[x] == HIGH) && (BNCInputLineLastKnownStatus[x] == LOW)) {
              BNCInputLineLastKnownStatus[x] = HIGH; CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
           }
           Ev = Ev + 1;
           // Determine BNC high-to-low events
           if ((BNCInputLineValue[x] == LOW) && (BNCInputLineLastKnownStatus[x] == HIGH)) {
              BNCInputLineLastKnownStatus[x] = LOW; CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
           }
           Ev = Ev + 1;
         }
         // Determine which Wire event occurred
         for (int x = 0; x < 4; x++) { 
           // Determine Wire low-to-high events
             if ((WireInputLineValue[x] == HIGH) && (WireInputLineLastKnownStatus[x] == LOW)) {
                WireInputLineLastKnownStatus[x] = HIGH; CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
             }
             Ev = Ev + 1;
             // Determine Wire high-to-low events
             if ((WireInputLineValue[x] == LOW) && (WireInputLineLastKnownStatus[x] == HIGH)) {
                WireInputLineLastKnownStatus[x] = LOW; CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
             }
             Ev = Ev + 1;
         }
          // Map soft events to event code scheme
          if (SoftEvent < 254) {
            CurrentEvent[nCurrentEvents] = SoftEvent + Ev - 1; nCurrentEvents++;
            SoftEvent = 254;
          }
          Ev = 40;
          // Determine if a global timer expired
          for (int x = 0; x < 5; x++) {
            if (GlobalTimersActive[x] == true) {
              if (CurrentTime >= GlobalTimerEnd[x]) {
                CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
                GlobalTimersActive[x] = false;
              }
            }
            Ev = Ev + 1; 
          }
          // Determine if a global event counter threshold was exceeded
          for (int x = 0; x < 5; x++) {
            if (GlobalCounterAttachedEvents[x] < 254) {
              // Check for and handle threshold crossing
              if (GlobalCounterCounts[x] == GlobalCounterThresholds[x]) {
                CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
              }
              // Add current event to count (Crossing triggered on next cycle)
              for (int i = 0; i < nCurrentEvents; i++) {
                if (CurrentEvent[i] == GlobalCounterAttachedEvents[x]) {
                  GlobalCounterCounts[x] = GlobalCounterCounts[x] + 1;
                }
              }
            }
            Ev = Ev + 1; 
          }
          Ev = 39;
          // Determine if a state timer expired
          TimeFromStart = CurrentTime - StateStartTime;
          if ((TimeFromStart >= StateTimers[CurrentState]) && (MeaningfulStateTimer == true)) {
            CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
          }
          
          // Now determine if a state transition should occur. The first event linked to a state transition takes priority.
          byte StateTransitionFound = 0; int i = 0;
          while ((!StateTransitionFound) && (i < nCurrentEvents)) {
            if (CurrentEvent[i] < 40) {
              NewState = InputStateMatrix[CurrentState][CurrentEvent[i]];
            } else if (CurrentEvent[i] < 45) {
              CurrentColumn = CurrentEvent[0] - 40;
              NewState = GlobalTimerMatrix[CurrentState][CurrentColumn];
            } else if (CurrentEvent[i] < 50) {
              CurrentColumn = CurrentEvent[i] - 45;
              NewState = GlobalCounterMatrix[CurrentState][CurrentColumn];
            }
            if (NewState != CurrentState) {
              StateTransitionFound = 1;
            }
            i++;
          }
          // Store timestamp of events captured in this cycle
          if ((nEvents + nCurrentEvents) < MaxTimestamps) {
            for (int x = 0; x < nCurrentEvents; x++) {
              TimeStamps[nEvents] = CurrentTime;
              nEvents++;
            } 
          }
          // Make state transition if necessary
          if (NewState != CurrentState) {
             if (NewState == nStates) {
                RunningStateMatrix = false;
                MatrixFinished = true;
             } else {
                setStateOutputs(NewState);
                StateStartTime = CurrentTime;
                CurrentState = NewState;
             }
          }
          // Write events captured to USB (if events were captured)
          if (nCurrentEvents > 0) {
            SerialUSB.write(1); // Code for returning events
            SerialUSB.write(nCurrentEvents);
            for (int x = 0; x < nCurrentEvents; x++) {
              SerialUSB.write(CurrentEvent[x]);
            }
          }
  } // End running state matrix
  if (MatrixFinished) {
    MatrixFinished = 0;
    SyncRegWrite(0); // Reset the sync lines
      ValveRegWrite(0); // Reset valves
      for (int x=0;x<8;x++) { // Reset PWM lines
        PortPWMOutputState[x] = 0;
      }
      UpdatePWMOutputStates();
      SetBNCOutputLines(0); // Reset BNC outputs
      SetWireOutputLines(0); // Reset wire outputs
      SerialUSB.write(1); // Op Code for sending events
      SerialUSB.write(1); // Read one event
      SerialUSB.write(255); // Send Matrix-end code
      // Send trial-start timestamp (in milliseconds, basically immune to microsecond 32-bit timer wrap-over)
          SerialWriteLong(MatrixStartTimeMillis-SessionStartTime);
      // Send matrix start timestamp (in microseconds)
      SerialWriteLong(MatrixStartTime);
        if (nEvents > 9999) {nEvents = 10000;}
        SerialWriteShort(nEvents);
        for (int x = 0; x < nEvents; x++) {
          SerialWriteLong(TimeStamps[x]);
        }
        updateStatusLED(0);
        updateStatusLED(2);
        for (int x=0; x<5; x++) { // Shut down active global timers
          GlobalTimersActive[x] = false;
        }
  } // End Matrix finished
} // End timer handler

void SetBNCOutputLines(int BNCState) {
  switch(BNCState) {
        case 0: {digitalWriteDirect(BncOutputLines[0], LOW); digitalWriteDirect(BncOutputLines[1], LOW);} break;
        case 1: {digitalWriteDirect(BncOutputLines[0], HIGH); digitalWriteDirect(BncOutputLines[1], LOW);} break;
        case 2: {digitalWriteDirect(BncOutputLines[0], LOW); digitalWriteDirect(BncOutputLines[1], HIGH);} break;
        case 3: {digitalWriteDirect(BncOutputLines[0], HIGH); digitalWriteDirect(BncOutputLines[1], HIGH);} break;
  }
}
int ValveRegWrite(int value) {
  // Write to water chip
  SPI.transfer(value);
  digitalWriteDirect(ValveRegisterLatch,HIGH);
  digitalWriteDirect(ValveRegisterLatch,LOW);
}

int SyncRegWrite(int value) {
  // Write to LED driver chip
  SPI.transfer(value);
  digitalWriteDirect(SyncRegisterLatch,HIGH);
  digitalWriteDirect(SyncRegisterLatch,LOW);
}

void UpdatePWMOutputStates() {
  for (int x = 0; x < 8; x++) {
    analogWrite(PortPWMOutputLines[x], PortPWMOutputState[x]);
  }
}
void SetWireOutputLines(int WireState) {
  for (int x = 0; x < 4; x++) {
    digitalWriteDirect(WireDigitalOutputLines[x],bitRead(WireState,x));
  }
}

void updateStatusLED(int Mode) {
  CurrentTime = millis();
  switch (Mode) {
    case 0: {
      analogWrite(RedLEDPin, 0);
      digitalWriteDirect(GreenLEDPin, 0);
      analogWrite(BlueLEDPin, 0);
    } break;
    case 1: { // Waiting for matrix
    if (ConnectedToClient == 0) {
        if (CurrentTime > NextLEDBrightnessAdjustTime) {
          NextLEDBrightnessAdjustTime = CurrentTime + LEDBrightnessAdjustInterval;
          if (LEDBrightnessAdjustDirection == 1) {
            if (LEDBrightness < 255) {
              LEDBrightness = LEDBrightness + 1;
            } else {
              LEDBrightnessAdjustDirection = 0;
            }
          }
          if (LEDBrightnessAdjustDirection == 0) {
            if (LEDBrightness > 0) {
              LEDBrightness = LEDBrightness - 1;
            } else {
              LEDBrightnessAdjustDirection = 2;
            }
          }
          if (LEDBrightnessAdjustDirection == 2) {
            NextLEDBrightnessAdjustTime = CurrentTime + 500;
            LEDBrightnessAdjustDirection = 1;
          }
          analogWrite(BlueLEDPin, LEDBrightness);
        }
      }
    } break;
    case 2: {
      analogWrite(BlueLEDPin, 0);
      digitalWriteDirect(GreenLEDPin, 1);
    } break;
    case 3: {
      analogWrite(BlueLEDPin, 0);
      digitalWriteDirect(GreenLEDPin, 1);
      analogWrite(RedLEDPin, 128);
    } break;
  }
}

void setStateOutputs(byte State) {
    byte CurrentTimer = 0; // Used when referring to the timer currently being triggered
    byte CurrentCounter = 0; // Used when referring to the counter currently being reset
    ValveRegWrite(OutputStateMatrix[State][0]);
    SetBNCOutputLines(OutputStateMatrix[State][1]);
    SetWireOutputLines(OutputStateMatrix[State][2]);
    Serial1.write(OutputStateMatrix[State][3]);
    Serial2.write(OutputStateMatrix[State][4]);
    if (OutputStateMatrix[State][5] > 0) {
      SerialUSB.write(2); // Code for soft-code byte
      SerialUSB.write(OutputStateMatrix[State][5]); // Code for soft-code byte
    }
    for (int x = 0; x < 8; x++) {
      analogWrite(PortPWMOutputLines[x], OutputStateMatrix[State][x+9]);
    }
    // Trigger global timers
    CurrentTimer = OutputStateMatrix[State][6];
    if (CurrentTimer > 0){
      CurrentTimer = CurrentTimer - 1; // Convert to 0 index
      GlobalTimersActive[CurrentTimer] = true; 
      GlobalTimerEnd[CurrentTimer] = CurrentTime+GlobalTimers[CurrentTimer];
    }
    // Cancel global timers
    CurrentTimer = OutputStateMatrix[State][7];
    if (CurrentTimer > 0){
      CurrentTimer = CurrentTimer - 1; // Convert to 0 index
      GlobalTimersActive[CurrentTimer] = false;
    }
    // Reset event counters
    CurrentCounter = OutputStateMatrix[State][8];
    if (CurrentCounter > 0){
      CurrentCounter = CurrentCounter - 1; // Convert to 0 index
      GlobalCounterCounts[CurrentCounter] = 0;
    }
    if (InputStateMatrix[State][39] != State) {MeaningfulStateTimer = true;} else {MeaningfulStateTimer = false;}
    SyncRegWrite((State+1)); // Output binary state code, corrected for zero index
}

void manualOverrideOutputs() {
  byte OutputType = 0;
  OutputType = SerialReadByte();
  switch(OutputType) {
    case 'P':  // Override PWM lines
      for (int x = 0; x < 8; x++) {
        PortPWMOutputState[x] = SerialReadByte();
      }
      UpdatePWMOutputStates(); 
      break;
    case 'V':  // Override valves
      Byte1 = SerialReadByte();
      ValveRegWrite(Byte1);
      break;
    case 'B': // Override BNC lines
      Byte1 = SerialReadByte();
      SetBNCOutputLines(Byte1);
      break;
    case 'W':  // Override wire terminal output lines
      Byte1 = SerialReadByte();
      SetWireOutputLines(Byte1);
      break;
    case 'S': // Override serial module port 1
      Byte1 = SerialReadByte();  // Read data to send
      Serial1.write(Byte1);
      break;
    case 'T': // Override serial module port 2
      Byte1 = SerialReadByte();  // Read data to send
      Serial2.write(Byte1);
      break;
    }
 }
 
void digitalWriteDirect(int pin, boolean val){
  if(val) g_APinDescription[pin].pPort -> PIO_SODR = g_APinDescription[pin].ulPin;
  else    g_APinDescription[pin].pPort -> PIO_CODR = g_APinDescription[pin].ulPin;
}

byte digitalReadDirect(int pin){
  return !!(g_APinDescription[pin].pPort -> PIO_PDSR & g_APinDescription[pin].ulPin);
}

void SerialWriteLong(unsigned long num) {
  SerialUSB.write((byte)num); 
  SerialUSB.write((byte)(num >> 8)); 
  SerialUSB.write((byte)(num >> 16)); 
  SerialUSB.write((byte)(num >> 24));
}

void SerialWriteShort(word num) {
  SerialUSB.write((byte)num); 
  SerialUSB.write((byte)(num >> 8)); 
}

unsigned long SerialReadLong() {
  while (SerialUSB.available() == 0) {}
  LowByte = SerialUSB.read();
  while (SerialUSB.available() == 0) {}
  SecondByte = SerialUSB.read();
  while (SerialUSB.available() == 0) {}
  ThirdByte = SerialUSB.read();
  while (SerialUSB.available() == 0) {}
  FourthByte = SerialUSB.read();
  LongInt =  (unsigned long)(((unsigned long)FourthByte << 24) | ((unsigned long)ThirdByte << 16) | ((unsigned long)SecondByte << 8) | ((unsigned long)LowByte));
  return LongInt;
}

byte SerialReadByte(){
  while (SerialUSB.available() == 0) {}
  LowByte = SerialUSB.read();
  return LowByte;
}
