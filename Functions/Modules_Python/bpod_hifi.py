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

from arcom import ArCom
import numpy as np


class BpodHiFi(object):
    def __init__(self, port_name):
        self.Port = ArCom(port_name, 480000000)
        self.Port.write(ord('I'), 'uint8')  # Get current parameters
        info_params8_bit = self.Port.read(4, 'uint8')
        info_params32_bit = self.Port.read(3, 'uint32')
        self._isHD = info_params8_bit[0]  # HiFi Module Model (0=base,1=HD)
        self._samplingRate = info_params32_bit[0]  # Units = Hz
        self._bitDepth = info_params8_bit[1]  # Bits per sample (fixed in firmware)
        self._maxWaves = info_params8_bit[2]  # Number of sounds the device can store
        self._digitalAttenuation_dB = np.double(info_params8_bit[3])*-0.5  # Units = dB
        self._synthAmplitude = 0  # 0 = synth off, 1 = max
        self._synthAmplitudeFade = 0  # Number of samples to ramp changes in synth amplitude (0 = instant change)
        self._synthWaveform = 'WhiteNoise'  # 'WhiteNoise' or 'Sine'
        self._synthFrequency = 1000  # Frequency of waveform (if sine)
        self.Port.write(ord('F'), 'uint8', self._synthFrequency*1000, 'uint32')  # Force SynthFrequency
        confirm = self.Port.read(1, 'uint8')
        self._headphoneAmpEnabled = 0
        self._headphoneAmpGain = 15
        self.Port.write((ord('G'), 15), 'uint8')  # Set headphone amp gain to non-painful initial level (range = 0-63)
        confirm = self.Port.read(1, 'uint8')  # Read confirmation byte
        self._maxSamplesPerWaveform = info_params32_bit[1]*192000
        self._maxEnvelopeSamples = info_params32_bit[2]
        self._validSamplingRates = (44100, 48000, 96000, 192000)
        self._minAttenuation_Pro = -103
        self._minAttenuation_HD = -120

    @property
    def sampling_rate(self):
        return self._samplingRate

    @sampling_rate.setter
    def sampling_rate(self, value):
        if value not in self._validSamplingRates:
            raise HiFiError('Error: Invalid Sampling Rate.')
        self.Port.write(ord('S'), 'uint8', value, 'uint32')
        confirm = self.Port.read(1, 'uint8')
        if confirm != 1:
            raise HiFiError('Error setting sampling rate: Confirm code not returned.')
        self._samplingRate = value

    @property
    def digital_attenuation_db(self):
        return self._digitalAttenuation_dB

    @digital_attenuation_db.setter
    def digital_attenuation_db(self, value):
        min_attenuation = self._minAttenuation_Pro
        if self._isHD:
            min_attenuation = self._minAttenuation_HD
        if (value > 0) or (value < min_attenuation):
            raise HiFiError('Error: Invalid digitalAttenuation_dB. ' +
                            'Value must be in range: [' + str(min_attenuation) + ',0]')
        attenuation_bits = value*-2
        self.Port.write((ord('A'),attenuation_bits), 'uint8')
        confirm = self.Port.read(1, 'uint8')
        if confirm != 1:
            raise HiFiError('Error setting digitalAttenuation: Confirm code not returned.')
        self._digitalAttenuation_dB = value

    @property
    def synth_amplitude(self):
        return self._synthAmplitude

    @synth_amplitude.setter
    def synth_amplitude(self, value):
        if not ((value >= 0) and (value <= 1)):
            raise HiFiError('Error: Synth amplitude values must range between 0 and 1.')
        amplitude_bits = round(value*65535)
        self.Port.write(ord('N'), 'uint8', amplitude_bits, 'uint16')
        confirm = self.Port.read(1, 'uint8')
        if confirm != 1:
            raise HiFiError('Error setting synthAmplitude: Confirm code not returned.')
        self._synthAmplitude = value

    @property
    def synth_amplitude_fade(self):
        return self._synthAmplitudeFade

    @synth_amplitude_fade.setter
    def synth_amplitude_fade(self, value):
        if not ((value >= 0) and (value <= 1920000)):
            raise HiFiError('Error: Synth amplitude fade must range between 0 and 1920000 samples.')
        self.Port.write(ord('Z'), 'uint8', value, 'uint32')
        confirm = self.Port.read(1, 'uint8')
        if confirm != 1:
            raise HiFiError('Error setting synthAmplitudeFade: Confirm code not returned.')
        self._synthAmplitudeFade = value

    @property
    def synth_waveform(self):
        return self._synthWaveform

    @synth_waveform.setter
    def synth_waveform(self, value):
        valid_waveforms = ['WhiteNoise','Sine']
        if value not in valid_waveforms:
            raise HiFiError('Invalid value for synthWaveform: Valid values are WhiteNoise or Sine.')
        self.Port.write((ord('W'),valid_waveforms.index(value)), 'uint8')
        confirm = self.Port.read(1, 'uint8')
        if confirm != 1:
            raise HiFiError('Error setting synthWaveform: Confirm code not returned.')
        self._synthWaveform = value

    @property
    def synth_frequency(self):
        return self._synthFrequency

    @synth_frequency.setter
    def synth_frequency(self, value):
        if not ((value >= 20) and (value <= 80000)):
            raise HiFiError('Error: Synth frequency must range between 0 and 80000 Hz.')
        self.Port.write(ord('F'), 'uint8', value*1000, 'uint32')
        confirm = self.Port.read(1, 'uint8')
        if confirm != 1:
            raise HiFiError('Error setting synthFrequency: Confirm code not returned.')
        self._synthFrequency = value

    @property
    def headphone_amp_enabled(self):
        return self._headphoneAmpEnabled

    @headphone_amp_enabled.setter
    def headphone_amp_enabled(self, value):
        valid_values = (0,1)
        if value not in valid_values:
            raise HiFiError('Error: headphoneAmpEnabled must be 0 (disabled) or 1 (enabled)')
        self.Port.write((ord('H'),value), 'uint8')
        confirm = self.Port.read(1, 'uint8')
        if confirm != 1:
            raise HiFiError('Error setting headphone amp: Confirm code not returned.')
        self._headphoneAmpEnabled = value

    @property
    def headphone_amp_gain(self):
        return self._headphoneAmpGain

    @headphone_amp_gain.setter
    def headphone_amp_gain(self, value):
        if not ((value >= 0) and (value <= 63)):
            raise HiFiError('Error: Headphone amp gain values must range between 0 and 63.')
        self.Port.write((ord('G'),value), 'uint8')
        confirm = self.Port.read(1, 'uint8')
        if confirm != 1:
            raise HiFiError('Error setting headphone amp gain: Confirm code not returned.')
        self._headphoneAmpGain = value

    def play(self, sound_index):
        self.Port.write((ord('P'), sound_index), 'uint8')

    def stop(self):
        self.Port.write(ord('X'), 'uint8')

    def push(self):
        self.Port.write(ord('*'), 'uint8')
        confirm = self.Port.read(1, 'uint8')
        if confirm != 1:
            raise HiFiError('Error: Confirm code not returned.')

    def set_am_envelope(self, envelope):
        if not envelope.ndim == 1:
            raise HiFiError('Error: AM Envelope must be a 1xN array.')
        n_envelope_samples = envelope.shape[0]
        if n_envelope_samples > self._maxEnvelopeSamples:
            raise HiFiError('Error: AM Envelope cannot contain more than ' + str(self._maxEnvelopeSamples) + ' samples.')
        if not ((envelope >= 0).all() and (envelope <= 1).all()):
            raise HiFiError('Error: AM Envelope values must range between 0 and 1.')
        self.Port.write((ord('E'), 1, ord('M')), 'uint8', n_envelope_samples, 'uint16', envelope, 'single')
        confirm = self.Port.read(2, 'uint8')

    def load(self, sound_index, waveform):
        # waveform must be a 1xN or 2xN numpy array in range [-1, 1]
        is_stereo = 1 # Default to stereo
        is_looping = 0 # Default loop mode = off
        loop_duration = 0 # Default loop duration = 0
        if (sound_index < 0) or (sound_index > self._maxWaves - 1):
            raise HiFiError('Error: Invalid sound index (' + str(sound_index) + '). ' +
                            'The HiFi module supports up to ' + str(self._maxWaves) + ' sounds.')

        if waveform.ndim == 1:
            is_stereo = 0
            n_samples = waveform.shape[0]
            formatted_waveform = waveform
        else:
            (nChannels,n_samples) = waveform.shape
            formatted_waveform = np.ravel(waveform, order='F')
        if self._bitDepth == 16:
            formatted_waveform = formatted_waveform*32767
        self.Port.write((ord('L'), sound_index, is_stereo, is_looping), 'uint8',
                        (loop_duration, n_samples), 'uint32', formatted_waveform, 'int16')
        confirm = self.Port.read(1, 'uint8')
        if confirm != 1:
            raise HiFiError('Error: Confirm code not returned.')

    def __repr__ (self):  # Self-description when the object is entered into the Python console with no properties or methods specified
        return ('\nBpodHiFi with user properties:' + '\n\n'
                'Port: ArCOMObject(' + self.Port.serialObject.port + ')' + '\n'
                'samplingRate: ' + str(self.sampling_rate) + '\n'
                'digitalAttenuation_dB: ' + str(self.digital_attenuation_db) + '\n'
                'synthAmplitude: ' + str(self.synth_amplitude) + '\n'
                'synthAmplitudeFade: ' + str(self.synth_amplitude_fade) + '\n'
                'synthWaveform: ' + str(self.synth_waveform) + '\n'
                'synthFrequency: ' + str(self.synth_frequency) + '\n'
                'headphoneAmpEnabled: ' + str(self.headphone_amp_enabled) + '\n'
                'headphoneAmpGain: ' + str(self.headphone_amp_gain) + '\n'
                )

    def __del__(self):
        self.Port.close()


class HiFiError(Exception):
    pass
