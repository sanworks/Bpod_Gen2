#ifndef __ARDUINO_AD9838X
#define __ARDUINO_AD9838X

#include <Arduino.h>
#include <SPI.h>

enum SignOutput {
  SIGN_OUTPUT_NONE        = 0x0000,
  SIGN_OUTPUT_MSB         = 0x0028,
  SIGN_OUTPUT_MSB_2       = 0x0020,
  SIGN_OUTPUT_COMPARATOR  = 0x0038,
};

enum OutputMode {
  OUTPUT_MODE_SINE        = 0x0000,
  OUTPUT_MODE_TRIANGLE    = 0x0002,
};

class AD983X {
public:
  AD983X(byte select_pin, int frequency_mhz);
  void setFrequencyWord(byte reg, uint32_t frequency);
  void setPhaseWord(byte reg, uint32_t phase);
  void setSignOutput(SignOutput out);
  void setOutputMode(OutputMode out);

  inline uint32_t computeFrequencyWord(uint32_t frequency) {
    // This is a manual expansion of (frequency * 2^28) / m_frequency_mhz
    // Since it doesn't require 64 bit multiplies or divides, it results in
    // substantially smaller code sizes.
    uint32_t lval = ((frequency & 0xFF) << 22) / (15625l * m_frequency_mhz);
    uint32_t mval = ((frequency & 0xFF00) << 14) / (15625l * m_frequency_mhz);
    uint32_t hval = ((frequency & 0xFF0000) << 6) / (15625l * m_frequency_mhz);
    return (hval << 16) + (mval << 8) + lval;
  }

  inline void setFrequency(byte reg, long int frequency) {
    frequency = this->computeFrequencyWord(frequency);
    this->setFrequencyWord(reg, frequency);
  }

  inline void setFrequency(byte reg, float frequency) {
    this->setFrequencyWord(reg, (frequency * (1l << 28)) / (m_frequency_mhz * 1000000));
  }

protected:
  void init();
  void writeReg(uint16_t value);

  byte m_select_pin;
  int m_frequency_mhz;
  uint16_t m_reg;
};

class AD983X_PIN : public AD983X {
private:
  byte m_reset_pin;
public:
  AD983X_PIN(byte select_pin, int frequency_mhz, byte reset_pin);
  void reset(boolean in_reset);
  void begin();
};

class AD983X_SW : public AD983X {
public:
  AD983X_SW(byte select_pin, int frequency_mhz);
  void reset(boolean in_reset);
  void begin();
  void selectFrequency(byte reg);
  void selectPhase(byte reg);
};

#endif
