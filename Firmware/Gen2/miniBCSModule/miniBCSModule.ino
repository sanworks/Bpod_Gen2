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

// The rotary encoder module, powered by Teensy 3.5, interfaces Bpod with a 1024-position rotary encoder: Yumo E6B2-CWZ3E
// The serial interface allows the user to set position thresholds, which generate Bpod events when crossed.
// The 'T' command starts a trial, by setting the current position to '512' (of 1024).
// Position data points and corresponding timestamps are logged until a threshold is reached.
// The 'E' command exits a trial, before a threshold is reached.
// The MATLAB interface can then retrieve the last trial's position log, before starting the next trial.
// The MATLAB can also stream the current position to a plot, for diagnostics.
//
// Future versions of this software will log position to Teensy's microSD card (currently logged to sRAM memory).
// With effectively no memory limit, the firmware will allow continuous recording to the card for an entire behavior session.
// The board's exposed I2C pins will be configured to log external events with position data: either incoming I2C messages or TTL pulses.
// The firmware will also be configured to calculate speed online (for treadmill assays), and speed thresholds can trigger events.
// The number of programmable thresholds will be larger than 2, limited by sRAM memory.

#include "ArCOM.h"


#define SERIAL_TX_BUFFER_SIZE 256
#define SERIAL_RX_BUFFER_SIZE 256
ArCOM myUSB(SerialUSB); // USB is an ArCOM object. ArCOM wraps Arduino's SerialUSB interface, to
ArCOM StateMachineCOM(Serial3); // UART serial port
ArCOM InputStreamCOM(Serial2); // UART serial port
// simplify moving data types between Arduino and MATLAB/GNU Octave.


#ifdef CALIBRATE
#define LAP_TEST_I
#endif

#define R11 25
#define R21 35
#define R31 45
#define R41 55
#define RBB 65
#define CBB1 30
#define CBB2 40
#define CBB3 50
#define CMODE 50
#define CWIDTH 48
#define CSPEED 40
#define WSPEED 56
#define RSPEED 75

#define ONCOL 30
#define OUTCOL 2


#define MAXCSpin 6
#define MAXCLKpin 13
#define MAXMOSIpin 11
#define MAXMISOpin 12
#define LCDCSpin 18

#define EncAoutPin A0
#define EncBoutPin A1

#define MAXOUTS 4

int Sensor1     =  16; // (A2)
int Sensor2     =  17; // (A3)
int Sensor3     =  15; // (A1)
int DistancePin =   3; //

//int EncoderAPin =   2;   //using Joshs defs
//int EncoderBPin =   5;
int SparePin    =   3;
int LEDpin      =  13;

#define SPEEDCHECK_USECS 100000

int Open          = 1;
int Close         = 0;

#define LASER_ON   HIGH
#define OUT1OFF  LOW
#define FW          1
#define BW          2
#define INJECT_ON  HIGH
#define OUT2OFF LOW
#define OUT3OFF  LOW
#define OUT4OFF  LOW

#define NO_MODE    0
#define POS13_MODE 1
#define POS21_MODE 3
#define POS32_MODE 2
#define DIST_MODE  4
#define SPEED_MODE 5
#define MANUAL_MODE 6
#define PULSE_MODE  7
#define LENGTH_MODE 8
#define LAP_MODE 9

const char * modestr[] =
{
  "(none)",
  "Pos 13",
  "Pos 32",
  "Pos 21",
  "Dist  ",
  "Speed ",
  "Manual",
  "Pulse ",
  "Length",
  "Laps  "
};

char   inst[100];
int    len;

int8_t BB1_last;
int8_t BB2_last;
int8_t BB3_last;
int16_t BBcount[3] = {0, 0, 0};

uint32_t DistanceTimer;
int16_t LastDistancePin = LOW;
int16_t NewDistancePin = LOW;

#define ON_MAX  0
#define OFF_MIN 1
#define RUN_SPEED_SET 2
#define DIST_START    3
#define DIST_STOP     4
#define BELT_LENGTH   5
#define NUM_PULSES    6
#define NUM_OFFSETS   7
#define LAP_POSITION  8
#define LAP_NUMBER    9

#define LASER_MODE 0
#define CURRENT_MODE 1

uint8_t StopMode[MAXOUTS] = {1, 1, 1, 1};
uint8_t outNum;
uint8_t ParamNum;
uint8_t firstTrig[MAXOUTS] = {1, 1, 1, 1 }; // track if this is first trigger of run

int16_t Value[MAXOUTS][10];  // holds setup vales:
//                 0 LASER   1 CURRENT
// 0 MAX ON
// 1 MAX OFF
// 2 RUN SPEED
// 3 DIST START
// 4 DIST STOP
// 5 BELT LENGTH
// 6 NUM_PULSES


uint8_t Mode[MAXOUTS];
int16_t OnTime[MAXOUTS]; // track how long output has been on
int16_t OffTime[MAXOUTS]; // track how long output has been off
uint8_t Output[MAXOUTS] = {0, 0}; // state of output 1 = on
int    Start;

int    LaserReady;
int    RunStatus;
float  LevelVolt[10];

int calflag = 0;

volatile uint8_t BB1_hits = 0;
volatile uint8_t BB2_hits = 0;
volatile uint8_t BB3_hits = 0;

volatile unsigned long BB1start;
volatile unsigned long BB2start;
volatile unsigned long BB3start;

volatile int16_t lapCount;
volatile int16_t lapPosition;

volatile uint16_t dir;
volatile int16_t marker_distance; // distance traveled since marker was passed
int32_t distance = 0;
int16_t last_marker = 0;  //track last marker position

// running states
#define IDLE_STATE  0
#define WAIT_STATE  1
#define START_STATE 2
#define RUN_STATE   3
#define END_STATE   4
#define OFF_STATE   5
#define DIST_RUN_STATE 6
#define POS_RUN_STATE  7
#define DIST_FINISHED_STATE 8
#define ON_STATE 9
#define DELAY_STATE 10
#define SKIP_STATE 11
#define INIT_STATE 12

static int8_t state[MAXOUTS] = {IDLE_STATE, IDLE_STATE, IDLE_STATE, IDLE_STATE}; // track current state of each mode
static int8_t last_state[MAXOUTS]  = {IDLE_STATE, IDLE_STATE, IDLE_STATE, IDLE_STATE};

volatile int firstBB1 = 0;

static int32_t run_speed = 0;
static int32_t BB1_distance = 0;
volatile uint32_t last_usecs;
volatile uint32_t this_usecs;
volatile uint32_t encoder_usecs;
static int32_t length_distance;
uint32_t beltLength = 0;
uint32_t speedcnt;  // used in speed cal
int32_t maxspeed ;
int32_t  speeddistance;

uint32_t  beltLengthCounts[MAXOUTS];
uint32_t  pulseLength[MAXOUTS];
uint8_t   pulseCounts[MAXOUTS];
uint8_t   offsetCounts[MAXOUTS];
int32_t  nextTransition[MAXOUTS];

static int16_t laser_msecs = 0;

#define LARGE_TREADMILL
#ifdef LARGE_TREADMILL
// large treadmill with analog encoder
// the uMICRONS is used for speed, but our timer is 4usec so
//   we need to divide by 4
// the MICRONS is used for distance, so leave it be
#define uMICRONS_PER_COUNT 319186  //638372 //2553487   // 4" x PI / 125 = 2.553 mm /count
#define MICRONS_PER_COUNT 1276  //2553
#else
// small treadmill with 5420-ES214 encoder - 200 counts /rev
//  1" x PI / 100 = 2.553 mm /count
#define uMICRONS_PER_COUNT 99746 //638372  // um/cnt /4usec per tic
#define MICRONS_PER_COUNT 399  //2553  //798
#endif



#define MIN_ELAPSED 1000000  // anything slower than this is too slow

#define SPEED_TIMEOUT 100000   // 100 msec !!! - check this
// 12500   // = 1/16e6/256/count sec
//w/o encoder 'tic' before we assume speed is 0


IntervalTimer tenMs;

//BPOD SETUP

// ======== Versions ========
#define VERSION "20170117"

// Module setup
unsigned long FirmwareVersion = 1;
char moduleName[] = "RotaryEncoder"; // Name of module for manual override UI and state machine assembler
char* eventNames[] = {"L", "R"}; // Left and right threshold crossings (with respect to position at trial start).
byte nEventNames = (sizeof(eventNames) / sizeof(char *));

// Hardware setup
const byte EncoderAPin = 35; //get the right pins
const byte EncoderBPin = 36; 
const byte EncoderPinZ = 37;  

// Parameters
unsigned short leftThreshold = 412; // in range 0-1024, corresponding to 0-360 degrees
unsigned short rightThreshold = 612; // in range 0-1024, corresponding to 0-360 degrees

// State variables
boolean isStreaming = false; // If currently streaming position and time data
boolean isLogging = false; // If currently logging position and time to RAM memory
boolean inTrial = false; // If currently in a trial
int EncoderPos = 0; // Current position of the rotary encoder

// Program variables
byte opCode = 0;
byte param = 0;
boolean trialFinished = 0;
byte terminatingEvent = 0;
boolean EncoderPinAValue = 0;
boolean EncoderPinALastValue = 0;
boolean EncoderPinBValue = 0;
boolean posChange = 0;
word EncoderPos16Bit =  0;
const int dataMax = 10000;
unsigned long timeLog[dataMax] = {0};
unsigned short posLog[dataMax] = {0};
unsigned long choiceTime = 0;
unsigned int dataPos = 0;

unsigned long startTime = 0;
unsigned long currentTime = 0;
unsigned long timeFromStart = 0;

void BPinInt() // just update output
{
  int ENCB = digitalReadFast(EncoderBPin);
  digitalWriteFast( EncBoutPin, ENCB);
}

// ------------------------------------------
// interrupt routine for ENCODER_A rising edge
// ---------------------------------------------
void encoder()
{
  //  noInterrupts();
  //  this_usecs = TCNT1; // Timer3.read();  // get time since last encoder tick
  //  TCNT1 = 0;
  //  interrupts();

  int ENCA = digitalReadFast(EncoderAPin);  // always update output
  digitalWriteFast( EncAoutPin, ENCA);

  if ( ENCA == HIGH) // but only process after rising edge
  {
    int ENCB = digitalReadFast(EncoderBPin);
    noInterrupts();  // guard against zero speed interrupt timer
    this_usecs = micros();
    encoder_usecs = this_usecs - last_usecs;
    last_usecs = this_usecs;
    run_speed = uMICRONS_PER_COUNT / encoder_usecs;
    //run_speed = uMICRONS_PER_COUNT / encoderusecs;
    //Serial.println(run_speed);
    //  encoderusecs = 0;
    interrupts();


    //

    // figure out the direction
    if (ENCA == ENCB )
    {
      //    if(dir == BW ) Serial.print('F');
      dir = FW;
      marker_distance++;
      BB1_distance++;
      length_distance++;
    }
    else
    {
      //    if(dir == FW ) Serial.print('B');
      dir = BW;
      marker_distance--;
      BB1_distance--;
    }
  }
}


// ------------------------------------------
// interrupt routine for 10 msec timer
// ---------------------------------------------

void Timer10msec()
{

  for ( uint8_t i = 0; i < MAXOUTS; i++ )
  {
    if ( Output[i] ) // is output active?
    {
      if ( OnTime[i]  < 32000 )
        OnTime[i] += 10;
    }
    else
    {
      if ( OffTime[i] < 32000 )
        OffTime[i] += 10;

    }
  }

}

// ------------------------------------------
// interrupt routine for timer3 - 0 speed detector
// ---------------------------------------------
// void EncoderTimeOut()
//ISR(TIMER1_COMPA_vect)
//{
//    run_speed = 0;
//}


void speedTimeout()
{
  noInterrupts();  // guard against encoder interrupt
  // if these are equal then the encoder interrupt has not fired since last check
  if ( last_usecs == this_usecs )
  {
    run_speed = 0;
    last_usecs = micros();  // start counting over again
  }
  interrupts();
}

// -----------------------------------------------------
// interrupt routine for Beam Break 1 - position detect
// -----------------------------------------------------

void BB1on()
{
  //MAX11300write(BB2OUT, HIGH);  //not using this adc on bpod
  BB1start = millis();
  firstBB1 = 1;
  BBcount[0]++;
  //MAX11300write(BB1OUT, HIGH);    //not using this adc on bpod
  //  lcd.fillRect(CBB1,RBB, 8, 8, BLACK);
  //  lcd.refresh();
  BB1_distance = 0;
  BB1_last = 0;      // note that we found a hole
  //     lcd.fillRect(0,85,95,95, WHITE);
  //     lcd.setCursor(0, 85);
  //     lcd.print(BBcount[0]);
  //     lcd.refresh();
  //MAX11300write(BB2OUT, LOW);     //not using this adc on bpod
  ///  Serial.println("1on");
}

void BB2on()
{
  BB2start = millis();
  BBcount[1]++;
  //MAX11300write(BB2OUT, HIGH);
  //lcd.fillRect(CBB2,RBB, 8, 8, BLACK);
  //lcd.refresh();
  // Serial.println("2");
  //
}

void BB3on()
{
  BB3start = millis();
  BBcount[MAXOUTS]++;
  //  Serial.print(',');
  //  Serial.print(marker_distance);
  //lcd.fillRect(CBB3,RBB, 8, 8, BLACK);
  //lcd.refresh();
}

uint32_t getBB1distance(void)
{
  uint32_t dist;
  noInterrupts();
  dist  = BB1_distance;
  interrupts();
  return dist;
}

uint8_t PosStart(uint8_t output)
{
  uint8_t started = 0;

  switch (Mode[output])
  {
    case POS13_MODE:
      if ( BB1start > BB3start )
      {
        started = 1;
      }
      break;
    case POS21_MODE:
      if ( BB2start > BB1start )
      {
        started = 1;
      }
      break;
    case POS32_MODE:
      if ( BB3start > BB2start )
      {
        started = 1;
      }
      break;
  }  // end switch-case mode type
  return started;
}

uint8_t PosEnd(uint8_t output)
{
  uint8_t ended = 0;

  switch (Mode[output])
  {
    case POS13_MODE:
      if ( BB3start > BB1start )
      {
        ended = 1;
      }
      break;
    case POS21_MODE:
      if ( BB1start > BB2start )
      {
        ended = 1;
      }
      break;
    case POS32_MODE:
      if ( BB2start > BB3start )
      {
        ended = 1;
      }
      break;
  }  // end switch-case mode type
  return ended;
}

// ===============================
// === O U T P U T  O N  ===
// ===============================

uint8_t OutputOn(uint8_t output)
{
  if ( firstTrig[output] == 0 ) // not first time trigger
  {
    // only turn on if we have been off long enough
    noInterrupts();
    int16_t offtimeval = OffTime[output];
    interrupts();
    if ( offtimeval >= Value[output][OFF_MIN] ) // everything good, turn on
    {
      if ( Output[output] == 0 )
      {
        //MAX11300write(output, HIGH);
        Output[output] = 1;
#ifdef DEBUG
        Serial.println("^^^^");
#endif
      }
      return (1);
    }
    else
    {
#ifdef DEBUG
      Serial.print(offtimeval);
      Serial.print(" offT < ");
      Serial.println(Value[output][OFF_MIN]);
#endif
      return (0);
    }
  }
  else  // first trigger - no wait
  {
    //     firstTrig[output] = 0;

    if ( Output[output] == 0 )
    {
     // MAX11300write(output, HIGH);
      Output[output] = 1;
#ifdef DEBUG
      Serial.println("1st^^^^^");
#endif

    }
    return (1);
  }
}

// ===============================
// === O U T P U T   O F F  ===
// ===============================

void OutputOff(uint8_t output)
{
  if ( Output[output] == 1 )
    //MAX11300write(output, LOW);  
    {
    Output[output] = 0;
#ifdef DEBUG
    Serial.println("vvvvvv");
#endif
  }
}

// ===============================
// === O U T P U T   C H E C K ===
// ===============================

// check if ouput has been on too long

uint8_t  OutputCheck(uint8_t output)
{
  noInterrupts();
  int16_t ontimeval = OnTime[output];
  interrupts();

  if ( ontimeval >= Value[output][ON_MAX] )
  {

#ifdef DEBUG
    Serial.print(ontimeval);
    Serial.print(">=");
    Serial.println(Value[output][ON_MAX]);
#endif
    OutputOff(output);
    return (0);
  }
  else
  {
    return (1);
  }

}


// ==============================
// ===  C H E C K   S T A T E ===
// ==============================

// check and update the current operating state

void CheckState(void)
{
  uint8_t i;
  static int16_t last_distance = 0;
  static int16_t distance;
  int32_t speed_now;
  static int32_t BB1time;
  static int32_t  BB1length;

#ifdef DEBUG
  for (i = 0; i < MAXOUTS; i++)
  {
    if ( state[i] != last_state[i])
    {
      Serial.print(Mode[i]);
      Serial.print(" st[");
      Serial.print(i);
      Serial.print("]=");
      Serial.println(state[i]);
      last_state[i] = state[i];
    }
  }
#endif

  for ( i = 0; i < MAXOUTS; i++) // go through laser then injection
  {
    switch (Mode[i])
    {
      case NO_MODE:  // nothing set
        break;

      case POS13_MODE: // ====== position modes ======
      case POS21_MODE:
      case POS32_MODE:

        switch (state[i])
        {
          case WAIT_STATE:  // start up - wait for start

            if ( PosStart(i) ) // stay here until we can turn on
            {
              if ( OutputOn(i) )
              {
                firstTrig[i] = 0;
                state[i] = POS_RUN_STATE;
                noInterrupts();
                OnTime[i] = 0;  // reset on timer for output
                interrupts();
              }
            }
            break;

          case POS_RUN_STATE: // output is on
            if ( PosEnd(i) ) // if end marker, turn off
            {
              state[i] = OFF_STATE; // go wait for next
            }
            else
            {
              if ( StopMode[i] == 1 ) // turn off while stopped if mode = 1
              { // and don't accumulate on time when stopped
                noInterrupts();
                speed_now = run_speed;
                interrupts();

                if ( speed_now  < 1 )
                {
                  OutputOff(i);
                }
                else
                {
                  OutputOn(i);
                }
              }

              // while waiting see if timeout occured
              // if so, then turn off
              if ( OutputCheck(i) == 0 )
              {
                state[i] = OFF_STATE;
              }

            }
            break;

          case OFF_STATE: // we are off, wait until pass off marker
            if ( PosEnd(i) )
            {
              OutputOff(i);
              noInterrupts();
              OffTime[i] = 0; // reset off timer
              interrupts();
              state[i] = WAIT_STATE;
            }
            break;

        } // end switch-case for position modes
        break;

      case DIST_MODE:   // ============== DISTANCE MODE =======
        noInterrupts();
        if ( last_marker != marker_distance)
        {
          last_marker = marker_distance;
          distance = (int16_t)( ((int32_t)last_marker * MICRONS_PER_COUNT) / 1000);
        }
        interrupts();

        if ( distance != last_distance)
        {

          last_distance = distance;
        }


        switch (state[i])
        {
          case WAIT_STATE:   // start here - wait for beam break as start position
            if ( firstBB1 == 1 ) // got 1st beam break
            {
              state[i] = START_STATE;
              noInterrupts();
              marker_distance = 0;
              last_marker = 0;
              distance = 0;
              interrupts();
#ifdef DEBUG
              Serial.print("WAI-STR offt=");
              Serial.print(OffTime[i]);
              Serial.print(" d=");
              Serial.println(distance);
#endif
            }
            break;

          case START_STATE: // wait to get to start distance
            //    Serial.print('.');
            if ( distance > Value[i][DIST_START] ) // we passed 'GO'
            {
              if ( OutputOn(i) ) // if we turned on - good
              {
                noInterrupts();
                OnTime[i] = 0; // reset timer
                interrupts();
                state[i] = DIST_RUN_STATE;  // we are running
#ifdef DEBUG
                Serial.print("STR-RUN d=");
                Serial.println(distance);
#endif
              }
              else // else in off timeout, skip till next try
              {
                state[i] = WAIT_STATE;
                firstBB1 = 0;
#ifdef DEBUG
                Serial.print("STR-WAI off=");
                Serial.print(OffTime[i]);
                Serial.print(",d=");
                Serial.println(distance);
#endif
              }
            }
            break;

          case DIST_RUN_STATE:  // output is on, go the distance
            if ( distance > Value[i][DIST_STOP] ) // got to end point, turn ouput off
            {
#ifdef DEBUG

              Serial.print("RUN-FIN ");
              Serial.print( Value[i][DIST_STOP]);
              Serial.print(",d=");
              Serial.println( distance);
#endif
              OutputOff(i);

              state[i] =  DIST_FINISHED_STATE;   // end finish up

            }
            else  // or if we stopped, turn off
            {
              if ( StopMode[i] == 1 ) // turn off while stopped if mode = 1
              { // and don't accumulate on time when stopped

                noInterrupts();
                speed_now = run_speed;
                interrupts();

                if ( speed_now < 1 ) // stopped - turn output off
                {
                  OutputOff(i);
                }
                else   // going - turn on
                {
                  OutputOn(i);
                }
              }
              // on too long? - off
              if ( OutputCheck(i) == 0 )
              {
                state[i] = DIST_FINISHED_STATE;
              }
            }
            break;
          case DIST_FINISHED_STATE:  // set back up for another run
            noInterrupts();
            OffTime[i] = 0; // reset off timer
            interrupts();
            firstTrig[i] = 0;
            firstBB1 = 0;
            state[i] = WAIT_STATE;  // go wait for start of treadmill (beam break)
#ifdef DEBUG
            Serial.println("FIN-WAI");
#endif
            break;

        } // end switch-case for distance
        //           OutputCheck(i);
        break;

      case SPEED_MODE:    // ============== SPEED MODE ======
        noInterrupts();
        speed_now = run_speed;
        interrupts();

        switch ( state[i])
        {
          case WAIT_STATE:
            if ( speed_now >= Value[i][RUN_SPEED_SET] )
            {
              if ( OutputOn(i) )
              {
                firstTrig[i] = 0;
                noInterrupts();
                OnTime[i] = 0; // reset on timer
                interrupts();
                state[i] = RUN_STATE;
              }
            }
            break;
          case RUN_STATE:
            if ( speed_now < Value[i][RUN_SPEED_SET] )
            { // went below - off
              OutputOff(i);
              noInterrupts();
              OffTime[i] = 0; // reset off timer
              interrupts();
              state[i] = WAIT_STATE;
            }
            else
            { // on too long - off
              if ( OutputCheck(i) == 0 )
              {
                noInterrupts();
                OffTime[i] = 0; // reset off timer
                interrupts();
                state[i] = WAIT_STATE;
              }
            }
            break;

        } // end switch-case speed state
        break;

      case MANUAL_MODE:    // ========= MANUAL MODE ==============
        switch ( state[i])
        {
          case WAIT_STATE:   // reset offtimer
            noInterrupts();
            OffTime[i] = 0;
            interrupts();
            state[i] = START_STATE;
            break;
          case START_STATE:  // set output on
            if ( OutputOn(i) ) // wait until it actually goes on
            {
              firstTrig[i] = 0;
              noInterrupts();
              OnTime[i] = 0;
              interrupts();
              state[i] = RUN_STATE;
            }
            break;
          case RUN_STATE:   // wait for timeout
            if ( OutputCheck(i) == 0 )
            {
              //                     Serial.println('E');
              state[i] = END_STATE;
            }
            break;
          case END_STATE:  // done
            break;
        }
        break;

      case PULSE_MODE:    // =========== PULSE MODE =================
        switch ( state[i])
        {
          case WAIT_STATE:   // reset off timer
            noInterrupts();
            OffTime[i] = 0;
            interrupts();
            beltLengthCounts[i] = (uint32_t)Value[i][BELT_LENGTH] * 1000 / MICRONS_PER_COUNT;
#ifdef DEBUG
            Serial.print("BL= ");
            Serial.print(beltLengthCounts[i]);
            Serial.print(" PL= ");
            Serial.println(beltLengthCounts[i] / (Value[i][NUM_PULSES] * Value[i][NUM_OFFSETS]) );
#endif

            if ( (Value[i][NUM_PULSES] * Value[i][NUM_OFFSETS]) < 1 )
            {
              state[i] = END_STATE;
            }
            else if ( beltLengthCounts[i] < (Value[i][NUM_PULSES] * Value[i][NUM_OFFSETS]) )
            {
              state[i] = END_STATE;
            }
            else
            {
              pulseLength[i] = beltLengthCounts[i] / (Value[i][NUM_PULSES] * Value[i][NUM_OFFSETS]);
              state[i] = START_STATE;
              offsetCounts[i] = 0; //Value[i][NUM_OFFSETS];
              pulseCounts[i] = 0;
            }
            break;

          case START_STATE:  // wait for Pos 1
            if ( firstBB1 == 1 )
            {
#ifdef DEBUG
              Serial.print("S= ");
              Serial.println( getBB1distance());
#endif
              if (  offsetCounts[i]  > 0 )   //  all but first have an initial delay
              {
                nextTransition[i] = pulseLength[i]  *  offsetCounts[i];
                state[i] = DELAY_STATE;
#ifdef DEBUG
                Serial.print("Dly= ");
                Serial.println( nextTransition[i] );
#endif
              }
              else  // if initial - do on time
              {
                nextTransition[i] =  0;  // this will cause a '0' delay
                state[i] = DELAY_STATE;
              }

            }
            break;

          case DELAY_STATE:
            // wait for off length

            if ( getBB1distance() >= nextTransition[i] ) // initial off is done
            {
              nextTransition[i] += pulseLength[i];  // set up on time
              noInterrupts();
              OnTime[i] = 0;  // reset on timer for output
              interrupts();
              if ( OutputOn(i) ) // wait until it actually goes on
              {
#ifdef DEBUG
                Serial.print("=====O= ");
                Serial.print(" ");
                Serial.print(pulseCounts[i]);
                Serial.print(" ");
                Serial.print(offsetCounts[i]);
                Serial.print(" ");
                Serial.print(getBB1distance() );
                Serial.print(" ");
                Serial.println( nextTransition[i] );
#endif
                firstTrig[i] = 0;
                noInterrupts();
                OnTime[i] = 0;
                interrupts();
                state[i] = ON_STATE;

                firstBB1 = 0;  // reset BB1catch
              }
            }
            break;

          case ON_STATE:
            if ( getBB1distance() >= nextTransition[i] ) // on is done
            {

              OutputOff(i);
              nextTransition[i] += pulseLength[i] * (Value[i][NUM_OFFSETS] - 1) ; // figure  off time
#ifdef DEBUG
              Serial.print("F= ");
              Serial.println( nextTransition[i] );
#endif
              state[i] = OFF_STATE;
              firstBB1 = 0;  // reset BB1catch
            }
            else  if ( OutputCheck(i) == 0 )
            {
              noInterrupts();
              OffTime[i] = 0; // reset off timer
              interrupts();
              //                       state[i] = WAIT_STATE;
            }
            break;

          case OFF_STATE :
            if ( (getBB1distance() >= nextTransition[i]) || ( firstBB1 == 1 ) ) // off is done, or we ran past end of loop
            {
#ifdef DEBUG
              Serial.print("D= ");
              Serial.println( getBB1distance() );
#endif

              if ( (pulseCounts[i] == (Value[i][NUM_PULSES] - 1)) && (offsetCounts[i] ==  (Value[i][NUM_OFFSETS] - 1))  ) // this round done wait for POS1
              {
#ifdef DEBUG
                Serial.print("ROUND ");
                Serial.println( getBB1distance() );
#endif
                state[i] = SKIP_STATE;  // at end we will skip a rev
              }
              else if ( pulseCounts[i] == (Value[i][NUM_PULSES] - 1) ) // this offset done
              {
#ifdef DEBUG
                Serial.print("Loop ");
#endif
                offsetCounts[i]++;
                pulseCounts[i] = 0;
                state[i] = START_STATE;
              }
              else
              {
#ifdef DEBUG
                Serial.println("Count ");
#endif
                pulseCounts[i]++;
                state[i] = DELAY_STATE;  // when we get here - we will immediately set up and run ON
              }

            }
            break;

          case SKIP_STATE:   // wait a rev before starting next
            if ( (firstBB1 == 1) && (getBB1distance() > 20) )  // be sure we get past any double BBs
            {
              pulseCounts[i] = 0;
              offsetCounts[i] = 0;
              firstBB1 = 0;  // reset BB1catch
              state[i] = START_STATE;
            }
            break;

          case END_STATE:  // done
            break;
        }
        break;

      case LENGTH_MODE:   // ========== LENGTH MODE =============
        switch ( state[i])
        {
          case WAIT_STATE:   // reset offtimer
            if (firstBB1 == 1 )  // passed 'go'
            {
              state[i] = RUN_STATE;
              noInterrupts();
              length_distance = 0;
              firstBB1 = 0;
              interrupts();
            }
            break;
          case RUN_STATE:
            if ( firstBB1 == 1 )
            {
              noInterrupts();
              //                    Serial.print("B");
              //                     Serial.println(length_distance * MICRONS_PER_COUNT/1000);
              length_distance = 0;
              firstBB1 = 0;
              interrupts();
            }
            break;
        }
        break;

      case LAP_MODE:    // ========== LAP  MODE ========
        switch ( state[i])
        {
          case WAIT_STATE:  // set up
            OutputOff(i);
            lapCount = Value[i][LAP_NUMBER];
            lapPosition = Value[i][LAP_POSITION] - 1; //(GUI is 1-3, we want 0-2)
#ifdef DEBUG
            Serial.println("Lap WAIT");
            Serial.println(lapCount);
            Serial.println(lapPosition);
#endif
            // be sure values are in range
            if ( (lapCount < 1) || (lapCount > 5) )state[i] = END_STATE;
            if ( (lapPosition < 0) || (lapPosition > 2) ) state[i] = END_STATE;
            if ( state[i] != END_STATE )
            {
              BBcount[lapPosition] = 0; // reset lap count for desired BB
              state[i] = RUN_STATE;
            }
            //      lcd.fillRect(0,0,95,9, WHITE);
            //      lcd.setCursor(0, 0);
            //      lcd.print("Lap:");
            //      lcd.print(lapCount);
            //      lcd.print(" ");
            //      lcd.print(lapPosition);
            //      lcd.refresh();

            break;
          case RUN_STATE:  // startup - wait here for first BB
            if ( BBcount[lapPosition] > 0 ) // start at first BB (count = 1)
            {
              OutputOn(i);
              state[i] = ON_STATE;
              BBcount[lapPosition] = 0;  // reset laps
              speedcnt = 0;
              maxspeed = 0;
              BB1time = BB1start;
            }
            break;
          case ON_STATE:  // at BB turn on and start counting
            if ( BBcount[lapPosition] >= lapCount ) // stop after last lap (LapCount+1)
            {
              OutputOff(i);
              state[i] = OFF_STATE; // and go to off mode
              BBcount[lapPosition] = 0;  // reset laps
#ifdef CALIBRATE
              Serial.print("Speed integral: ");
              Serial.println(speedcnt);
              Serial.print("Max Speed: ");
              Serial.println( maxspeed);
              Serial.print("Distance: ");
              Serial.println(BB1length);
              Serial.print("Time: ");
              Serial.println( millis() - BB1time);
#endif
            }
            else
            {
              BB1length = getBB1distance();
            }
            break;
          case OFF_STATE:  // at BB turn on and start counting
            if ( BBcount[lapPosition] >= lapCount ) // stop after last lap (LapCount+1)
            {
              OutputOn(i);
              state[i] = ON_STATE; // and go to off mode
              BBcount[lapPosition] = 0;  // reset laps
              speedcnt = 0;
              maxspeed = 0;
              BB1time = BB1start;
            }
            break;
          case END_STATE:
            break;

        } // end LAP_MODE
        break;

    } // end switch-case for mode type
  } // end loop through two outputs
}    // check current states


void setup() {
  // put your setup code here, to run once:
  SerialUSB.begin(115200);
  Serial3.begin(1312500);
  Serial2.begin(1312500);
  pinMode(Sensor1,  INPUT_PULLUP);
  pinMode(Sensor2,  INPUT_PULLUP);
  pinMode(Sensor3,  INPUT_PULLUP);
  pinMode(EncoderAPin, INPUT);
  pinMode (EncoderBPin, INPUT);
  pinMode(13, OUTPUT);
  digitalWrite(13, HIGH);
  pinMode(EncAoutPin, OUTPUT);
  pinMode(EncBoutPin, OUTPUT);
  digitalWrite(EncAoutPin, LOW);
  digitalWrite(EncBoutPin, LOW);


  len = 0;
  inst[0] = '\n';

  for (uint8_t i = 0; i < MAXOUTS; i++ )
  {
    Value[i][0] = 100;   // output on max
    Value[i][1] = 100;   // output off min
    Value[i][2] = 200;    // run speed trig
    Value[i][3] = 100;    // dist start
    Value[i][4] = 150;    // dist stop
    Value[i][5] = 0;
    Value[i][6] = 0;
    Value[i][7] = 1;    // assume lap mode uses position 1
    Value[i][8] = 1;    // assume lap count is 1
    Mode[i] = 0;
    Output[i] = 1;   // will force ouputs to be set off
    OutputOff(i);    //  since we only change out if it needs it
  
  }

  LaserReady  =  1;
  RunStatus   =  0;

  attachInterrupt(EncoderAPin, encoder, CHANGE);
  attachInterrupt(EncoderBPin, BPinInt, CHANGE);
  attachInterrupt(Sensor1 , BB1on, FALLING);
  //  attachInterrupt(2, BB2on, FALLING);
  //  attachInterrupt(3, BB3on, FALLING);

  BB1_last = digitalRead(Sensor1);
  BB2_last = digitalRead(Sensor2);
  BB3_last = digitalRead(Sensor3);

  last_usecs = micros();
  tenMs.begin(Timer10msec, 10000);
} //end setup


// =================
// ===  L O O P  ===
// =================

void loop() {
  int    TargetChar;
  char   temp[100];
  char   sync;
  int    Rx;
  int    i;
  int    runningsignal;
  float  RunningVolt;
  int32_t speed;

  // =============== CHECK BEAM BREAKS =======
  if ( BB1_last == 0) // new BB,
  {
    BB1_last = 2; // jsut do this once each BB
  }

  if ( (BB1_last == 2 ) && digitalRead(Sensor1) ) // belt start trigger passed
  {
    //MAX11300write(BB1OUT, LOW); //send ttl
    BB1_last = 1;
  }


  CheckState();

  noInterrupts();

  if ( (micros() - last_usecs) > SPEED_TIMEOUT  )
  {
    run_speed = 0;
  }
  speed = run_speed;
  interrupts();

  speedcnt += speed;
  if ( speed > maxspeed ) maxspeed = speed;

  // == DAC OUTPUT ===
  // DAC set up as +/-5V out
  // want 1V = 100mm/sec
  //if ( dir == BW ) // if reverse running
    //DAC =  0x800 - speed * 4;  //for bpod pins?
  //  else
      ////for bpod pins?
      //DAC = speed * 4 + 0x800;  // gain = ~2V/200 counts and offset for DAC 0
  //    if ( DAC < 0 ) DAC == 0;
  //if ( DAC > 0xFFF ) DAC == 0xFFF;
  //MAX11300writeAnalog(DACPin, DAC);

  speed = speed >> 2;

  currentTime = millis();
  if (StateMachineCOM.available() > 0) {
    opCode = StateMachineCOM.readByte();
    switch (opCode) {
      case 255: // Return module name and info
        returnModuleInfo();
        break;
      case 'T':
        startTrial();
        break;
    }
  }

  //============================================================================
  //  Instruction
  // - commands are '~c:v
  // where 'c' is the command letter, 'v' is the value(s)
  //============================================================================

  if (SerialUSB.available() > 0) {
    opCode = myUSB.readByte();
    switch (opCode) {
      case 'C': // Handshake
        myUSB.writeByte(217);
        break;
      case 'S': // Start streaming
        EncoderPos = 512; // Set to mid-range
        isStreaming = true;
        startTime = currentTime;
        break;
      case 's': // Start trial (changed from bpod code of 'T' since 'T' reserved in minibcs
        startTrial();
        break;
      case 'E': // End trial
        inTrial = false;
        isLogging = false;
        break;
      case 'P': // Program parameters (1 at a time)
        param = myUSB.readByte();
        switch (param) {
          case 'L':
            leftThreshold = myUSB.readUint16();
            break;
          case 'R':
            rightThreshold = myUSB.readUint16();
            break;
        }
        break;
      case 'A': // Program parameters (all at once)
        leftThreshold = myUSB.readUint16();
        rightThreshold = myUSB.readUint16();
        myUSB.writeByte(1);
        break;
      case 'R': // Return data
        isLogging = false;
        if (trialFinished) {
          trialFinished = false;
          myUSB.writeUint16(dataPos);
          myUSB.writeUint16Array(posLog, dataPos);
          myUSB.writeUint32Array(timeLog, dataPos);
          dataPos = 0;
        } else {
          dataPos = 0;
          myUSB.writeUint16(dataPos);
        }
        break;

      case 'Q': // Return current encoder position
        myUSB.writeUint16(EncoderPos);
        break;
      case 'X': // Exit
        isStreaming = false;
        isLogging = false;
        inTrial = false;
        dataPos = 0;
        EncoderPos = 512;
        break;
      //minibcs codes
      case 'd':   // distance readback
        noInterrupts();
        Serial.print("d}");
        Serial.println( ((int32_t)marker_distance * MICRONS_PER_COUNT) / 1000);
        marker_distance = 0;
        interrupts();
        break;
      case 't':   // show set values
        Serial.print ("================");
        Serial.write (13);
        Serial.write (10);
        for ( int i = 0; i < MAXOUTS; i++)
        {
          Serial.print (Value[i][0]);
          Serial.print (" ");
          Serial.print (Value[i][1]);
          Serial.print (" ");
          Serial.print (Value[i][2]);
          Serial.print (" ");
          Serial.print (Value[i][3]);
          Serial.print (" ");
          Serial.print (Value[i][4]);
          Serial.print (" ");
          Serial.print (Value[i][5]);
          Serial.write (13);
          Serial.write (10);
        }
        Serial.print (" ");
        Serial.write (13);
        Serial.write (10);
        Serial.print (" ");
        Serial.write (13);
        Serial.write (10);
        break;
      case 'T':   // set new value for a parameter
        outNum = inst[3] - '0'; // which output
        if ( outNum > 3 ) break;
        ParamNum = inst[5] - '0'; // which value
        if ( ParamNum > 9 ) break;
        Value[outNum][ParamNum] = atoi(&inst[7]); //value starts at 7

        break;
      case 'Z':    //
        inst[0] = 32;  //~
        inst[1] = 32;  //Z
        inst[2] = 32;  //:
        ParamNum = inst[3] - 48;
        inst[3] = 32;  //0-6
        inst[4] = 32;  //:
        if (ParamNum >= 5) ParamNum = 5;
        Serial.print("Z}");
        Serial.print (ParamNum);
        Serial.write (13);
        Serial.write (10);
        break;

      case 'M':    // set Mode
        outNum = inst[3] - '0'; // which output
        if ( outNum > 3 ) break;
        Mode[outNum] = atoi(&inst[5]);
        Serial.print("M}");
        Serial.print(outNum);
        Serial.print(':');
        Serial.println(Mode[outNum]);
        OutputOff(outNum); // always turn output off at a mode change
        state[outNum] = WAIT_STATE;
        firstBB1 = 0;
        firstTrig[outNum] = 1;
        break;
      case 'L':    // set stop mode (turn output off when stopped if = 1)
        outNum = inst[3] - '0'; // which output?
        if ( outNum > 3 ) break;
        StopMode[outNum] = inst[5] - '0';  // Which Output
        Serial.print("L}");
        Serial.println(StopMode[outNum]);

        break;


    } // End switch(opCode)
  } // End if (SerialUSB.available())
  timeFromStart = currentTime - startTime;
  EncoderPinAValue = digitalRead(EncoderAPin);
  if (EncoderPinAValue == HIGH && EncoderPinALastValue == LOW) {
    EncoderPinBValue = digitalRead(EncoderBPin);
    if (EncoderPinBValue == HIGH) {
      EncoderPos++; posChange = true;
    } else {
      EncoderPos--; posChange = true;
    }
    if (EncoderPos == 1024) {
      EncoderPos = 0;
    } else if (EncoderPos == -1) {
      EncoderPos = 1023;
    }
    if (isStreaming) {
      EncoderPos16Bit = (word)EncoderPos;
      myUSB.writeUint16(EncoderPos16Bit);
      myUSB.writeUint32(timeFromStart);
    }
  }
  if (inTrial) {
    if (posChange) { // If the position changed since previous loop
      if (EncoderPos <= leftThreshold) {
        inTrial = false;
        terminatingEvent = 1;
        StateMachineCOM.writeByte(terminatingEvent);
      }
      if (EncoderPos >= rightThreshold) {
        inTrial = false;
        terminatingEvent = 2;
        StateMachineCOM.writeByte(terminatingEvent);
      }
    }
    if (!inTrial) {
      startTime = currentTime;
      if (dataPos < dataMax) { // Add final data point
        posLog[dataPos] = EncoderPos;
        timeLog[dataPos] = timeFromStart;
        dataPos++;
      }
      trialFinished = true;
      isLogging = false; // Stop logging
    }
  }
  if (isLogging) {
    if (posChange) { // If the position changed since previous loop
      posChange = false;
      if (dataPos < dataMax) {
        posLog[dataPos] = EncoderPos;
        timeLog[dataPos] = timeFromStart;
        dataPos++;
      }
    }
  }
  EncoderPinALastValue = EncoderPinAValue;
}

void returnModuleInfo() {
  StateMachineCOM.writeByte(65); // Acknowledge
  StateMachineCOM.writeUint32(FirmwareVersion); // 4-byte firmware version
  StateMachineCOM.writeByte(sizeof(moduleName) - 1); // Length of module name
  StateMachineCOM.writeCharArray(moduleName, sizeof(moduleName) - 1); // Module name
  StateMachineCOM.writeByte(1); // 1 if more info follows, 0 if not
  StateMachineCOM.writeByte('#'); // Op code for: Number of behavior events this module can generate
  StateMachineCOM.writeByte(2); // 2 thresholds
  StateMachineCOM.writeByte(1); // 1 if more info follows, 0 if not
  StateMachineCOM.writeByte('E'); // Op code for: Behavior event names
  StateMachineCOM.writeByte(nEventNames);
  for (int i = 0; i < nEventNames; i++) { // Once for each event name
    StateMachineCOM.writeByte(strlen(eventNames[i])); // Send event name length
    for (int j = 0; j < strlen(eventNames[i]); j++) { // Once for each character in this event name
      StateMachineCOM.writeByte(*(eventNames[i] + j)); // Send the character
    }
  }
  StateMachineCOM.writeByte(0); // 1 if more info follows, 0 if not
}

void startTrial() {
  EncoderPos = 512;
  dataPos = 0;
  startTime = currentTime;
  inTrial = true;
  isLogging = true;
  timeFromStart = 0;
}

