from ArCOM import ArCOMObject
import numpy as np

class BpodHiFi(object):
    def __init__(self, PortName):
        self.Port = ArCOMObject(PortName, 115200)
        self.Port.write(ord('I'), 'uint8'); # Get current parameters
        InfoParams8Bit = self.Port.read(4, 'uint8')
        InfoParams32Bit = self.Port.read(3, 'uint32')
        self.isHD = InfoParams8Bit[0] # HiFi Module Model (0=base,1=HD)
        self._samplingRate = InfoParams32Bit[0] # use H.samplingRate = X. Underscored version does not support get and set callbacks
        self.bitDepth = InfoParams8Bit[1] # Bits per sample (fixed in firmware)
        self.maxWaves = InfoParams8Bit[2] # Number of sounds the device can store
        digitalAttBits = InfoParams8Bit[3]
        self._digitalAttenuation_dB = np.double(digitalAttBits)*-0.5
        self._synthAmplitude = 0; # 0 = synth off, 1 = max
        self._synthAmplitudeFade = 0; # Number of samples over which to ramp changes in synth amplitude (0 = instant change)
        self._synthWaveform = 'WhiteNoise'; # WhiteNoise or Sine
        self._synthFrequency = 1000; # Frequency of waveform (if sine)
        self.Port.write(ord('F'), 'uint8', self._synthFrequency*1000, 'uint32') # Force SynthFrequency
        confirm = self.Port.read(1, 'uint8')
        self._headphoneAmpEnabled = 0;
        self._headphoneAmpGain = 15;
        self.Port.write((ord('G'), 15), 'uint8'); # Set gain to non-painful initial level (range = 0-63)
        self.Port.read(1, 'uint8');
        self.maxSamplesPerWaveform = InfoParams32Bit[1]*192000
        self.maxEnvelopeSamples = InfoParams32Bit[2]
        self.validSamplingRates = (44100,48000,96000,192000)
        self.minAttenuation_Pro = -103
        self.minAttenuation_HD = -120
        
    @property
    def samplingRate(self):
        return self._samplingRate
    
    @samplingRate.setter
    def samplingRate(self, value):
        if not value in self.validSamplingRates:
            raise HiFiError('Error: Invalid Sampling Rate.')
        self.Port.write(ord('S'), 'uint8', value, 'uint32');
        confirm = self.Port.read(1, 'uint8');
        if confirm != 1:
             raise HiFiError('Error setting sampling rate: Confirm code not returned.')
        self._samplingRate = value
        
    @property
    def digitalAttenuation_dB(self):
        return self._digitalAttenuation_dB
    
    @digitalAttenuation_dB.setter
    def digitalAttenuation_dB(self, value):
        minAttenuation = self.minAttenuation_Pro
        if self.isHD:
            minAttenuation = self.minAttenuation_HD
        if (value > 0) or (value < minAttenuation):
            raise HiFiError('Error: Invalid digitalAttenuation_dB. Value must be in range: [' + str(minAttenuation) + ',0]')
        attenuationBits = value*-2;
        self.Port.write((ord('A'),attenuationBits), 'uint8')
        confirm = self.Port.read(1, 'uint8');
        if confirm != 1:
             raise HiFiError('Error setting digitalAttenuation: Confirm code not returned.')
        self._digitalAttenuation_dB = value
    
    @property
    def synthAmplitude(self):
        return self._synthAmplitude
    
    @synthAmplitude.setter
    def synthAmplitude(self, value):
        if not ((value >= 0) and (value <= 1)):
            raise HiFiError('Error: Synth amplitude values must range between 0 and 1.')
        amplitudeBits = round(value*32767);
        self.Port.write(ord('N'), 'uint8', amplitudeBits, 'uint16')
        confirm = self.Port.read(1, 'uint8');
        if confirm != 1:
             raise HiFiError('Error setting synthAmplitude: Confirm code not returned.')
        self._synthAmplitude = value
    
    @property
    def synthAmplitudeFade(self):
        return self._synthAmplitudeFade    
    
    @synthAmplitudeFade.setter
    def synthAmplitudeFade(self, value):
        if not ((value >= 0) and (value <= 1920000)):
            raise HiFiError('Error: Synth amplitude fade must range between 0 and 1920000 samples.')
        self.Port.write(ord('Z'), 'uint8', value, 'uint32')
        confirm = self.Port.read(1, 'uint8');
        if confirm != 1:
             raise HiFiError('Error setting synthAmplitudeFade: Confirm code not returned.')
        self._synthAmplitudeFade = value
    
    @property
    def synthWaveform(self):
        return self._synthWaveform   
    
    @synthWaveform.setter
    def synthWaveform(self, value):
        validWaveforms = ['WhiteNoise','Sine']
        if not value in validWaveforms:
            raise HiFiError('Invalid value for synthWaveform: Valid values are WhiteNoise or Sine.')
        waveformIndex = validWaveforms.index(value)
        self.Port.write((ord('W'),waveformIndex), 'uint8')
        confirm = self.Port.read(1, 'uint8');
        if confirm != 1:
             raise HiFiError('Error setting synthWaveform: Confirm code not returned.')
        self._synthWaveform = value
        
    @property
    def synthFrequency(self):
        return self._synthFrequency
    
    @synthFrequency.setter
    def synthFrequency(self, value):
        if not ((value >= 20) and (value <= 80000)):
            raise HiFiError('Error: Synth frequency must range between 0 and 80000 Hz.')
        self.Port.write(ord('F'), 'uint8', value*1000, 'uint32')
        confirm = self.Port.read(1, 'uint8')
        if confirm != 1:
             raise HiFiError('Error setting synthFrequency: Confirm code not returned.')
        self._synthFrequency = value
        
    @property
    def headphoneAmpEnabled(self):
        return self._headphoneAmpEnabled
    
    @headphoneAmpEnabled.setter
    def headphoneAmpEnabled(self, value):
        validValues = (0,1)
        if not value in validValues:
            raise HiFiError('Error: headphoneAmpEnabled must be 0 (disabled) or 1 (enabled)')
        self.Port.write((ord('H'),value), 'uint8')
        confirm = self.Port.read(1, 'uint8');
        if confirm != 1:
             raise HiFiError('Error setting headphone amp: Confirm code not returned.')
        self._headphoneAmpEnabled = value
    
    @property
    def headphoneAmpGain(self):
        return self._headphoneAmpGain  
    
    @headphoneAmpGain.setter
    def headphoneAmpGain(self, value):
        if not ((value >= 0) and (value <= 63)):
            raise HiFiError('Error: Headphone amp gain values must range between 0 and 63.')
        self.Port.write((ord('G'),value), 'uint8')
        confirm = self.Port.read(1, 'uint8');
        if confirm != 1:
             raise HiFiError('Error setting headphone amp gain: Confirm code not returned.')
        self._headphoneAmpGain = value
        
    def play(self, SoundIndex):
        self.Port.write((ord('P'),SoundIndex), 'uint8')
        
    def stop(self):
        self.Port.write(ord('X'), 'uint8')
        
    def push(self):
        self.Port.write(ord('*'), 'uint8')
        confirm = self.Port.read(1, 'uint8')
        if confirm != 1:
             raise HiFiError('Error: Confirm code not returned.')
    def setAMEnvelope(self, envelope):
        if not envelope.ndim == 1:
            raise HiFiError('Error: AM Envelope must be a 1xN array.')
        nEnvelopeSamples = envelope.shape[0]
        if nEnvelopeSamples > self.maxEnvelopeSamples:
            raise HiFiError('Error: AM Envelope cannot contain more than ' + str(self.maxEnvelopeSamples) + ' samples.')
        if not ((envelope >= 0).all() and (envelope <= 1).all()):
            raise HiFiError('Error: AM Envelope values must range between 0 and 1.')
        self.Port.write((ord('E'), 1, ord('M')), 'uint8', nEnvelopeSamples, 'uint16', envelope, 'single')
        confirm = self.Port.read(2, 'uint8')
    def load(self, soundIndex, waveform):
        # waveform must be a 1xN or 2xN numpy array in range [-1, 1]
        isStereo = 1 # Default to stereo
        isLooping = 0 # Default loop mode = off
        loopDuration = 0 # Default loop duration = 0
        if (soundIndex < 0) or (soundIndex > self.maxWaves-1):
            raise HiFiError('Error: Invalid sound index (' + str(soundIndex) + '). The HiFi module supports up to ' + str(self.maxWaves) + ' sounds.')
        
        if waveform.ndim == 1:
            isStereo = 0
            nChannels = 1
            nSamples = waveform.shape[0]
            formattedWaveform = waveform
        else:
            (nChannels,nSamples) = waveform.shape
            formattedWaveform = np.ravel(waveform, order='F')
        if self.bitDepth == 16:
            formattedWaveform = formattedWaveform*32767
        self.Port.write((ord('L'),soundIndex,isStereo, isLooping), 'uint8', (loopDuration, nSamples), 'uint32', formattedWaveform, 'int16')
        confirm = self.Port.read(1, 'uint8')
        if confirm != 1:
             raise HiFiError('Error: Confirm code not returned.')
    def __repr__ (self): # Self description when the object is entered into the IPython console with no properties or methods specified
        return ('\nBpodHiFi with user properties:' + '\n\n'
        'Port: ArCOMObject(' + self.Port.serialObject.port + ')'  + '\n'
        'samplingRate: ' + str(self.samplingRate) + '\n'
        'digitalAttenuation_dB: ' + str(self.digitalAttenuation_dB) + '\n'
        'synthAmplitude: ' + str(self.synthAmplitude) + '\n'
        'synthAmplitudeFade: ' + str(self.synthAmplitudeFade) + '\n'
        'synthWaveform: ' + str(self.synthWaveform) + '\n'
        'synthFrequency: ' + str(self.synthFrequency) + '\n'
        'headphoneAmpEnabled: ' + str(self.headphoneAmpEnabled) + '\n'
        'headphoneAmpGain: ' + str(self.headphoneAmpGain) + '\n'
        )
    def __del__(self):
        self.Port.close()
        
class HiFiError(Exception):
    pass