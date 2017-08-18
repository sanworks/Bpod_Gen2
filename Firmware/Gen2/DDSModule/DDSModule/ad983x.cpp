#include "ad983x.h"

#define REG_FREQ1   0x8000
#define REG_FREQ0   0x4000
#define REG_PHASE0  0xC000
#define REG_PHASE1  0xE000

#define REG_B28     0x2000
#define REG_HLB     0x1000
#define REG_FSEL    0x0800
#define REG_PSEL    0x0400
#define REG_PINSW   0x0200
#define REG_RESET   0x0100
#define REG_SLEEP1  0x0080
#define REG_SLEEP12 0x0040
#define REG_OPBITEN 0x0020
#define REG_SIGNPIB 0x0010
#define REG_DIV2    0x0008
#define REG_MODE    0x0002

#define SIGN_OUTPUT_MASK (REG_OPBITEN | REG_SIGNPIB | REG_DIV2 | REG_MODE)

void AD983X::writeReg(uint16_t value) {
  SPI.setBitOrder(MSBFIRST);
  SPI.setDataMode(SPI_MODE2);
  digitalWrite(m_select_pin, LOW);
  delayMicroseconds(10);
  SPI.transfer(value >> 8);
  SPI.transfer(value & 0xFF);
  delayMicroseconds(10);
  digitalWrite(m_select_pin, HIGH);
}

void AD983X::setFrequencyWord(byte reg, uint32_t frequency) {
  writeReg((reg?REG_FREQ1:REG_FREQ0) | (frequency & 0x3FFF));
  writeReg((reg?REG_FREQ1:REG_FREQ0) | ((frequency >> 14) & 0x3FFF));
}

void AD983X::setPhaseWord(byte reg, uint32_t phase) {
  writeReg((reg?REG_PHASE1:REG_PHASE0) | (phase & 0x0FFF));
}

void AD983X::setSignOutput(SignOutput out) {
  m_reg = (m_reg & ~SIGN_OUTPUT_MASK) | out;
  writeReg(m_reg);
}

void AD983X::setOutputMode(OutputMode out) {
  if(out == OUTPUT_MODE_TRIANGLE) {
    m_reg = (m_reg & ~SIGN_OUTPUT_MASK) | out;
  } else {
    m_reg &= ~REG_MODE;
  }
  writeReg(m_reg);
}

void AD983X::init() {
  SPI.begin();
  writeReg(m_reg);

  // Initialize frequency and phase registers to 0
  this->setFrequencyWord(0, 0);
  this->setFrequencyWord(1, 0);
  this->setPhaseWord(0, 0);
  this->setPhaseWord(1, 0);
}

AD983X::AD983X(byte select_pin, int frequency_mhz) : 
	m_select_pin(select_pin), m_frequency_mhz(frequency_mhz), m_reg(REG_B28) {
  digitalWrite(select_pin, HIGH);
  pinMode(select_pin, OUTPUT);
}

void AD983X_SW::reset(boolean in_reset) {
  if(in_reset) {
    m_reg |= REG_RESET;
  } else {
    m_reg &= ~REG_RESET;
  }
  this->writeReg(m_reg);
}

void AD983X_SW::begin() {
  reset(true);
  init();
  reset(false);
}

AD983X_SW::AD983X_SW(byte select_pin, int frequency_mhz) :
    AD983X(select_pin, frequency_mhz) {
}

void AD983X_SW::selectFrequency(byte reg) {
  if(reg) {
    m_reg |= REG_FSEL;
  } else {
    m_reg &= ~REG_FSEL;
  }
  writeReg(m_reg);
}

void AD983X_SW::selectPhase(byte reg) {
  if(reg) {
    m_reg |= REG_PSEL;
  } else {
    m_reg &= ~REG_PSEL;
  }
  writeReg(m_reg);
}

void AD983X_PIN::reset(boolean in_reset) {
  digitalWrite(m_reset_pin, in_reset);
}

void AD983X_PIN::begin() {
  reset(true);
  init();
  reset(false);    
}

AD983X_PIN::AD983X_PIN(byte select_pin, int frequency_mhz, byte reset_pin) :
    AD983X(select_pin, frequency_mhz), m_reset_pin(reset_pin) {
  pinMode(m_reset_pin, OUTPUT);
  m_reg |= REG_PINSW | REG_RESET;
}
