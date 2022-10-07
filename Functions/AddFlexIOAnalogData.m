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
% It reads the current Flex I/O analog data file and combines it into BpodSystem.Data

function SessionData = AddFlexIOAnalogData(SessionData, varargin)
%
% Optional arguments must be provided in order, up to the argument required.
% Arg 1: Data format. Default = 'Volts'. Use 'Bits' for a smaller data file.
% In 'Bits' mode, samples are 12-bit values (0-4095), spanning the 0-5V range
%
% Arg 2: Include trial-aligned data. This includes a cell array with cells containing
% a copy of the analog data captured on each trial. This makes your data file larger.
% Values: 1 to include, 0 if not.
%
% Example usage:
% AddFlexIOAnalogData('Bits', 1) imports data in bits, and adds a trial-aligned copy of the data.

global BpodSystem
if BpodSystem.MachineType > 3
    % Default params
    VoltageRangeMax = 5; % Hard-coded
    TargetDataFormat = 0; % 0 = Volts, 1 = bits (0-4095 encoding voltage in range 0-5V)
    IncludeTrialAlignedData = 0; % If set to
    % Check for overrides
    if nargin > 1
        TargetDataString = varargin{1};
        if strcmpi(TargetDataString, 'bits')
            TargetDataFormat = 1;
        end
    end
    if nargin > 2
        IncludeTrialAlignedData = varargin{1};
    end
    if ~isempty(BpodSystem)
        if BpodSystem.MachineType > 3
            stop(BpodSystem.Timers.AnalogTimer); % Stop acquisition + data logging
            pause(.5);
        end
    else
        clear global BpodSystem
    end
    if isfield(SessionData, 'Analog')
        disp('Importing Flex I/O analog data to primary behavior data file. Please wait...')
        AnalogMeta = SessionData.Analog;
        myFile = fopen(AnalogMeta.FileName, 'r');
        if myFile == -1
            warning(['AddFlexIOAnalogData was called but could not open the analog data file: ' AnalogMeta.FileName ' No data was added to the primary data file.'])
        else
            Data = fread(myFile, (AnalogMeta.nSamples*AnalogMeta.nChannels)+AnalogMeta.nSamples, 'uint16');
            if TargetDataFormat == 0
                FormattedData = (double(Data)/4095)*VoltageRangeMax; % Convert to volts
                SessionData.Analog.info.Samples = 'Analog measurements captured. Rows are separate analog input channels. Units = Volts';
            else
                FormattedData = Data;
                SessionData.Analog.info.Samples = 'Analog measurements captured. Rows are separate analog input channels. Units = Bits (0-4095) encoding volts (0-5V)';
            end
            fclose(myFile);
            clear myFile;
            SessionData.Analog.Samples = [];
            for i = 1:SessionData.Analog.nChannels
                SessionData.Analog.Samples(i,:) = FormattedData(i+1:AnalogMeta.nChannels+1:end)';
            end
            oneTrialCompleted = isfield(SessionData, 'TrialStartTimestamp');
            if oneTrialCompleted
                SessionData.Analog.Timestamps = SessionData.TrialStartTimestamp:(1/AnalogMeta.SamplingRate):SessionData.TrialStartTimestamp+((1/AnalogMeta.SamplingRate)*(AnalogMeta.nSamples-1));
                SessionData.Analog.TrialNumber = Data(1:AnalogMeta.nChannels+1:end)';
                if IncludeTrialAlignedData
                    SessionData.Analog.TrialData = cell(1,SessionData.nTrials);
                    for i = 1:SessionData.nTrials
                        SessionData.Analog.TrialData{i} = SessionData.Analog.Samples(:,SessionData.Analog.TrialNumber == i);
                    end
                end
            else
                warning('Flex I/O analog data NOT saved; the state machine must reach the exit state to complete at least 1 trial before data can be properly aligned.')
            end
        end
        disp('Data import complete.')
    else
        warning('AddFlexIOAnalogData was called but could not find analog data to add. No data was added to the primary data file.')
    end
else
    warning('AddFlexIOAnalogData was called but the state machine does not have Flex I/O channels. No Flex I/O data added.')
end
