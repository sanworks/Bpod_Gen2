// TEMPORARY firmware to provide example code, in advance of analog input module availability.
// This firmware uses Arduino M0's ADC to create a closed loop with the analog output module.
// It samples the first analog input channel on the M0 and sends its value over 
// a dedicated UART line to the DDS module once every 0.1 ms.

#include "ArCOM.h"
#include <SPI.h>
#define SERIAL_TX_BUFFER_SIZE 256
#define SERIAL_RX_BUFFER_SIZE 256

// Pin definitions
const byte nInputChannels = 1;
const byte AnalogChannel = A0;

// Variables
uint16_t adcValue = 0;
uint16_t freq = 0;
byte opCode = 0;

// Wrap 2 serial interfaces
ArCOM USBCOM(SerialUSB); // Creates an ArCOM object called USBCOM, wrapping SerialUSB (the USB connection for Arduino M0)
ArCOM Serial1COM(Serial1); // Creates an ArCOM object called Serial1COM, wrapping Serial1 (connection to Analog Ouptut module)

void setup() {
  Serial1.begin(1312500);
  analogReadResolution(16); // Set analog values to return 16-bit resolution (actual converter is 12-bit)
  setTimer(); // Start hardware timer for even sampling (see ugly ARM code below; much cleaner wrappers available on Arduino DUE and Teensy)
}

void loop() { // loop runs in parallel with hardware timer callback, at lower interrupt priority.
 
}

void timerCallback() { // runs once each time the hardware timer ticks
  adcValue = analogRead(AnalogChannel);
  Serial1COM.writeByte('M');
  Serial1COM.writeUint16(adcValue);
}

// ---------------- These functions use ARM commands to initialize and handle the timer. -------------------------
void setTimer() {
  //
  // The timer interval in milliseconds is set by (1/(48000000 / (PRESCALER * (COUNTER TOP + 1))))*1000
  // To set a 1 ms timer, PRESCALER = 64, and COUNTER TOP = 749: (1/(48000000 / (64 * (749 + 1))))*1000 = 1 ms
  // To set a 100 microsecond timer, PRESCALER = 64, and COUNTER TOP = 149: (1/(48000000 / (64 * (149 + 1))))*1000 = 0.2 ms
  // To set a 200 microsecond timer, PRESCALER = 64, and COUNTER TOP = 74: (1/(48000000 / (64 * (74 + 1))))*1000 = 0.1 ms
  // To set a 50 microsecond timer, PRESCALER = 16, and COUNTER TOP = 149: (1/(48000000 / (16 * (149 + 1))))*1000 = 0.05 ms
  // Set these values manually below, to set the timer interval. 
  //
  // Enable clock for TC 
  REG_GCLK_CLKCTRL = (uint16_t) (GCLK_CLKCTRL_CLKEN | GCLK_CLKCTRL_GEN_GCLK0 | 0x1A) ;
  //GCLK->CLKCTRL.reg = 0x441A;
  while ( GCLK->STATUS.bit.SYNCBUSY == 1 ); // wait for sync 


  // The type cast must fit with the selected timer 
  Tcc* TC = (Tcc*) TCC0; // get timer struct
  
  TC->CTRLA.reg &= ~TCC_CTRLA_ENABLE;   // Disable TC
  while (TC->SYNCBUSY.bit.ENABLE == 1); // wait for sync 


  TC->CTRLA.reg |= TCC_CTRLA_PRESCALER_DIV64;   // Set perscaler


  TC->WAVE.reg |= TCC_WAVE_WAVEGEN_NFRQ;   // Set wave form configuration 
  while (TC->SYNCBUSY.bit.WAVE == 1); // wait for sync 

  TC->PER.reg = 149;              // Set counter Top using the PER register  
  while (TC->SYNCBUSY.bit.PER == 1); // wait for sync 

  TC->CC[0].reg = 0xFFF;
  while (TC->SYNCBUSY.bit.CC0 == 1); // wait for sync 
  
  // Interrupts 
  TC->INTENSET.reg = 0;                 // disable all interrupts
  TC->INTENSET.bit.OVF = 1;          // enable overfollow
  TC->INTENSET.bit.MC0 = 1;          // enable compare match to CC0

  // Enable InterruptVector
  NVIC_EnableIRQ(TCC0_IRQn);

  // Enable TC
  TC->CTRLA.reg |= TCC_CTRLA_ENABLE ;
  while (TC->SYNCBUSY.bit.ENABLE == 1); // wait for sync 
}

void TCC0_Handler() // Timer handler
{
  Tcc* TC = (Tcc*) TCC0;       // get timer struct
  if (TC->INTFLAG.bit.OVF == 1) {  // If the timer overflow flag is true
    timerCallback();
    TC->INTFLAG.bit.OVF = 1;    // Clear the overflow flag
  }
}
// ------------------------------- End ARM timer functions ----------------------------------------
