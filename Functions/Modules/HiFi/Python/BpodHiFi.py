from ArCOM import ArCOMObject
import numpy as np

class BpodHiFi(object):
    def __init__(self, PortName):
        self.Port = ArCOMObject(PortName, 115200)
        
    def play(self, SoundIndex):
        self.Port.write((ord('P'),SoundIndex), 'uint8')
        
    def stop(self):
        self.Port.write(ord('X'), 'uint8')
        
    def push(self):
        self.Port.write(ord('*'), 'uint8')
        confirm = self.Port.read(1, 'uint8')
        if confirm != 1:
             raise HiFiError('Error: Confirm code not returned.')
    
    def load(self, waveIndex, waveform):
        # waveform must be a 1xN or 2xN numpy array in range [-1, 1]
        isStereo = 1 # Placeholder for future mono data transfer
        isLooping = 0 # Default loop mode = off
        loopDuration = 0 # Default loop duration = 0
        bitDepth = 16
        if waveform.ndim == 1:
            waveform = np.stack((waveform, waveform))
        (nChannels,nSamples) = waveform.shape
        if bitDepth == 16:
            waveform = waveform*32767
        formattedWaveform = np.ravel(waveform, order='F')
        self.Port.write((ord('L'),waveIndex,isStereo, isLooping), 'uint8', (loopDuration, nSamples), 'uint32', formattedWaveform, 'int16')
        confirm = self.Port.read(1, 'uint8')
        if confirm != 1:
             raise HiFiError('Error: Confirm code not returned.')
    def __del__(self):
        self.Port.close()
        
class HiFiError(Exception):
    pass