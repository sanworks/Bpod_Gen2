%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2021 Sanworks LLC, Rochester, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}
function ProcessAnalogSamples(obj, e)
    if obj.AnalogSerialPort.bytesAvailable() > 0
        nChannels = sum(obj.HW.FlexIO_ChannelTypes == 2);
        nBytesAvailable = obj.AnalogSerialPort.bytesAvailable;
        nSamplesToRead = floor(nBytesAvailable/((2*(nChannels+1))));
        if nSamplesToRead > 0
            Msg = obj.AnalogSerialPort.read((nSamplesToRead*(nChannels+1)), 'uint16');
            if obj.Status.RecordAnalog
                fwrite(obj.AnalogDataFile, Msg, 'uint16');
            end
            Msg(1:nChannels+1:end) = []; % Remove trial number data
            newData = reshape(Msg, nChannels, nSamplesToRead);
            obj.Status.nAnalogSamples = obj.Status.nAnalogSamples + nSamplesToRead;
            obj.Data.Analog.nSamples = obj.Status.nAnalogSamples;
            if obj.Status.AnalogViewer == 1
                obj.analogViewer('update', newData);
            end
        end
    end
end