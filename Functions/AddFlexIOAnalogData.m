%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) Sanworks LLC, Rochester, New York, USA

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

% AddFlexIOAnalogData() is intended to be run on the Bpod computer after a session is complete.
% It reads the current Flex I/O analog data file and combines it into BpodSystem.Data
%
% Arguments:
% -sessionData: A Bpod session data structure
%
% Optional arguments must be provided in order, up to the argument required.
% -Arg 1: targetDataFormat. Default = 'Volts'. Use 'Bits' for a smaller data file.
%         In 'Bits' mode, samples are 12-bit values (0-4095), spanning the 0-5V range
%
% -Arg 2: Include trial-aligned data. This includes a cell array with cells containing
%         a copy of the analog data captured on each trial. This makes your data file larger.
%         Values: 1 to include, 0 if not.
%
% Return: sessionData, the Bpod session data struct, with an added field: Analog. 
% sessionData.Analog has fields:
% nChannels: The number of channels acquired
% Samples: The raw samples acquired. Units = volts or bits, depending on
%          optional targetDataFormat argument
% Timestamps: A timestamp for each sample. Units = seconds
% TrialNumber: The experimental trial number during which each sample was acquired
% TrialData (optional): A cell array containing a cell for each trial's analog data
% info: A struct containing human-readable information about .Analog's fields
%
% Example usage:
% sessionData = AddFlexIOAnalogData(sessionData, 'Bits', 1);
% This example imports data in bits, and adds a trial-aligned copy of the data to sessionData


function sessionData = AddFlexIOAnalogData(sessionData, varargin)

global BpodSystem % Import the global BpodSystem object

% Constants
VOLTAGE_RANGE_MAX = 5; % Flex I/O ADC maximum input voltage
BIT_MAX = 4095;        % Flex I/O ADC bit depth

if BpodSystem.MachineType > 3
    % Default params
    targetDataFormat = 0; % 0 = Volts, 1 = bits (0-4095 encoding voltage in range 0-5V)
    includeTrialAlignedData = 0; % If set to

    % Process optional arguments
    if nargin > 1
        targetDataString = varargin{1};
        if strcmpi(targetDataString, 'bits')
            targetDataFormat = 1;
        end
    end
    if nargin > 2
        includeTrialAlignedData = varargin{1};
    end
    
    % Ensure that analog acquisition is stopped
    if ~isempty(BpodSystem)
        if BpodSystem.MachineType > 3
            stop(BpodSystem.Timers.AnalogTimer); % Stop acquisition + data logging
            pause(.5);
        end
    else
        clear global BpodSystem
    end

    % Format and add analog data to the sessionData structure
    if isfield(sessionData, 'Analog')
        disp('Importing Flex I/O analog data to primary behavior data file. Please wait...')
        analogMeta = sessionData.Analog;
        myFile = fopen(analogMeta.FileName, 'r');
        if myFile == -1
            warning(['AddFlexIOAnalogData was called but could not open the analog data file: ' ... 
                analogMeta.FileName ' No data was added to the primary data file.'])
        else
            Data = fread(myFile, (analogMeta.nSamples*analogMeta.nChannels)+analogMeta.nSamples, 'uint16');
            if targetDataFormat == 0
                formattedData = (double(Data)/BIT_MAX)*VOLTAGE_RANGE_MAX; % Convert to volts
                sessionData.Analog.info.Samples = 'Analog measurements. Rows are separate analog input channels. Units = Volts';
            else
                formattedData = Data;
                sessionData.Analog.info.Samples = ['Analog measurements. Rows are separate analog input channels. ' ...
                                                   'Units = Bits (0-4095) encoding volts (0-5V)'];
            end
            fclose(myFile);
            clear myFile;
            sessionData.Analog.Samples = [];
            for i = 1:sessionData.Analog.nChannels
                sessionData.Analog.Samples(i,:) = formattedData(i+1:analogMeta.nChannels+1:end)';
            end
            oneTrialCompleted = isfield(sessionData, 'TrialStartTimestamp');
            if oneTrialCompleted
                sessionData.Analog.Timestamps =... 
                                  sessionData.TrialStartTimestamp:(1/analogMeta.SamplingRate):sessionData.TrialStartTimestamp + ... 
                                  ((1/analogMeta.SamplingRate)*(analogMeta.nSamples-1));
                sessionData.Analog.TrialNumber = Data(1:analogMeta.nChannels+1:end)';
                if includeTrialAlignedData
                    sessionData.Analog.TrialData = cell(1,sessionData.nTrials);
                    for i = 1:sessionData.nTrials
                        sessionData.Analog.TrialData{i} = sessionData.Analog.Samples(:,sessionData.Analog.TrialNumber == i);
                    end
                end
            else
                warning(['Flex I/O analog data NOT saved; the state machine must reach the exit state to complete at least 1 trial ' ...
                         'before data can be properly aligned.'])
            end
        end
        disp('Data import complete.')
    else
        warning('AddFlexIOAnalogData was called but could not find analog data to add. No data was added to the primary data file.')
    end
else
    warning('AddFlexIOAnalogData was called but the state machine does not have Flex I/O channels. No Flex I/O data added.')
end
