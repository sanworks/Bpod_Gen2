from BpodHiFi import BpodHiFi
import numpy as np
import time
H = BpodHiFi('COM22')
time.sleep(0.01)
SF = 192000
Freq = 1000
Duration = 1
Wave = np.sin(2 * np.pi * Freq * np.arange(Duration * SF) / SF)
tic = time.perf_counter(); 
H.load(0, Wave); 
print(time.perf_counter() - tic)
H.push()
time.sleep(0.01)
H.play(0)
del H
