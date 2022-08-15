%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2022 Sanworks LLC, Rochester, New York, USA

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

% This function is intended to be run after a behavior session is complete.
% It reads the Flex I/O analog data file and combines it into BpodSystem.Data

function AddFlexIOAnalogData
global BpodSystem
if isfield(BpodSystem.Data, 'Analog')
    if BpodSystem.MachineType > 3
        stop(BpodSystem.Timers.AnalogTimer); % Stop acquisition + data logging
        pause(.5);
        AnalogMeta = BpodSystem.Data.Analog;
        myFile = fopen(AnalogMeta.FileName, 'r');
        if myFile == -1
            warning(['AddFlexIOAnalogData was called but could not open the analog data file: ' AnalogMeta.FileName ' No data was added to the primary data file.'])
        else
            Data = fread(myFile, (AnalogMeta.nSamples*AnalogMeta.nChannels)+AnalogMeta.nSamples, 'uint16');
            fclose(myFile);
            clear myFile; 
            BpodSystem.Data.Analog.Samples = []; 
            for i = 1:BpodSystem.Data.Analog.nChannels
                BpodSystem.Data.Analog.Samples(i,:) = Data(i+1:AnalogMeta.nChannels+1:end)'; 
            end
            BpodSystem.Data.Analog.Timestamps = BpodSystem.Data.TrialStartTimestamp:(1/AnalogMeta.SamplingRate):BpodSystem.Data.TrialStartTimestamp+((1/AnalogMeta.SamplingRate)*(AnalogMeta.nSamples-1)); 
            BpodSystem.Data.Analog.TrialNumber = Data(1:AnalogMeta.nChannels+1:end)'; 
            BpodSystem.Data.Analog.TrialData = cell(1,BpodSystem.Data.nTrials); 
            for i = 1:BpodSystem.Data.nTrials
                BpodSystem.Data.Analog.TrialData{i} = BpodSystem.Data.Analog.Samples(:,BpodSystem.Data.Analog.TrialNumber == i); 
            end
        end
    end
else
    warning('AddFlexIOAnalogData was called but could not find analog data to add. No data was added to the primary data file.')
end