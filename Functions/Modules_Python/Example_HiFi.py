"""
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod_Gen2 repository
Copyright (C) 2023 Sanworks LLC, Rochester, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
"""

# Example code demonstrating basic usage of bpod_hifi.py to program and control the Bpod HiFi module via its USB port
from bpod_hifi import BpodHiFi
import numpy as np
import time

# Parameters
SF = 192000  # Sampling rate (units = Hz)
Freq = 1000  # Pure tone frequency (units = Hz)
Duration = 1  # Full tone duration (units = Seconds. Full tone is interrupted by stop command in example below)

H = BpodHiFi('COM43')  # Create an instance of the HiFi module
Wave = np.sin(2 * np.pi * Freq * np.arange(Duration * SF) / SF)  # Generate audio waveform
H.sampling_rate = SF  # Set sampling rate
H.digital_attenuation_db = -15  # Digital attenuation (units = dB)
tic = time.perf_counter()  # Start measuring data transfer time
H.load(0, Wave)  # Upload waveform to the HiFi module
print('Load Time (s): ' + str(time.perf_counter() - tic))
H.push()  # Add the newly uploaded sounds to the current sound set, overwriting any existing sound at each sound index
Envelope = np.linspace(0, 1, 1920)  # 10ms linear ramp
H.set_am_envelope(Envelope)  # Set the AM envelope. This is applied to playback at sound onset, and in reverse at offset
H.play(0)  # Play the sound
time.sleep(0.5)  # Wait 500ms
H.stop()  # Stop the sound
del H  # Delete the bpod_hifi object, releasing the USB serial port
