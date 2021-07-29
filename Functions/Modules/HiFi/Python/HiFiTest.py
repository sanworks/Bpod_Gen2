from BpodHiFi import BpodHiFi
import numpy as np
import time
H = BpodHiFi('COM32')
SF = 192000 # Sampling rate
Freq = 1000 # Tone frequency
Duration = 1 # Full tone duration (interrupted by stop command below)
Wave = np.sin(2 * np.pi * Freq * np.arange(Duration * SF) / SF)
tic = time.perf_counter(); 
H.samplingRate = SF
H.digitalAttenuation_dB = -15 # Digital attenuation
H.load(0, Wave); 
print('Load Time (s): ' + str(time.perf_counter() - tic))
H.push()
Envelope = np.linspace(0,1,1920) # 10ms linear ramp
H.setAMEnvelope(Envelope)
H.play(0)
time.sleep(0.5)
H.stop()
del H
