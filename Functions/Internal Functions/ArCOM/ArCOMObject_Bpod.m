%{
----------------------------------------------------------------------------

This file is part of the Sanworks ArCOM repository
Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

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

% ArCOM uses an Arduino library to simplify serial communication of different
% data types between MATLAB/GNU Octave and Arduino. To use the library,
% include the following at the top of your Arduino sketch:
% #include "ArCOM.h". See documentation for more Arduino-side tips.
%
% Initialization syntax:
% MyPort = ArCOMObject('COM3', 115200)
% where 'COM3' is the name of Arduino's serial port on your system, and 115200 is the baud rate.
% This call both creates and opens the port. It returns an object containing
% a serial port and properties. If PsychToolbox IOport interface is
% available, this is used by default. To use the java interface on a system
% with PsychToolbox, use ArCOM('open', 'COM3', 'java')
%
% Write: MyPort.write(myData, 'uint8') % where 'uint8' is a
% data type from the following list: 'uint8', 'uint16', 'uint32', 'int8', 'int16', 'int32', 'char'. 
% If no data type argument is specified, ArCOM assumes uint8. Additional
% pairs of vectors and types can be added, to be packaged into a single
% write operation i.e. MyPort.write(Data1, Type1, Data2, Type2,... DataN, TypeN)
%
% Read: myData = MyPort.read(nValues, 'uint8') % where nValues is the number
% of values to read, and 'uint8' is a data type (see Write above for list)
% If no data type argument is specified, ArCOM assumes uint8. Additional
% pairs of value numbers and types can be added, to be packaged into a single
% read operation i.e. [Array1, Array2] = MyPort.write(Data1, Type1, Data2, Type2)
%
% End: MyPort.close() % Closes, deletes and clears the serial port
% object in the workspace of the calling function. You can also type clear
% MyPort - the object destructor will automatically close the port.

classdef ArCOMObject_Bpod < handle
    properties
        Port
        baudRate
        Interface
        UseOctave
        UsePsychToolbox
        validDataTypes
    end
    methods
        function obj = ArCOMObject_Bpod(portString, baudRate, varargin)
            obj.Port = [];
            if (exist('OCTAVE_VERSION'))
                try
                    pkg load instrument-control
                catch
                    error('Please install the instrument control toolbox first. See http://wiki.octave.org/Instrument_control_package');
                end
                if (exist('serial') ~= 3)
                    error('Serial port communication is necessary for Pulse Pal, but is not supported in Octave on your platform.');
                end
                warning('off', 'Octave:num-to-str');
                obj.UseOctave = 1;
                obj.Interface = 2; % Octave serial interface
            else
                obj.UseOctave = 0;
            end
            try
                PsychtoolboxVersion;
                obj.UsePsychToolbox = 1;
                obj.Interface = 1; % PsychToolbox serial interface
            catch
                obj.UsePsychToolbox = 0;
                obj.Interface = 0; % Java serial interface
            end
            if nargin > 1
                if ischar(baudRate)
                    baudRate = str2double(baudRate);
                end
            else
                error('Error: Please add a baudRate argument when creating an ArCOM object')
            end
            if ~isnan(baudRate) && baudRate >= 1200
                obj.baudRate = baudRate;
            else
                error(['Error: ' baudRate ' is an invalid baud rate for ArCOM. Some common baud rates are: 9600, 115200'])
            end
            if nargin > 2
                forceOption = varargin{1};
                switch lower(forceOption)
                    case 'java'
                        obj.UsePsychToolbox = 0;
                        obj.Interface = 0;
                    case 'psychtoolbox'
                        obj.UsePsychToolbox = 1;
                        obj.Interface = 1;
                    otherwise
                        error('The third argument to ArCOM(''init'' must be either ''java'' or ''psychtoolbox''');
                end
            end
            obj.validDataTypes = {'char', 'uint8', 'uint16', 'uint32', 'int8', 'int16', 'int32'};
            switch obj.Interface
                case 0
                    obj.Port = serial(portString, 'BaudRate', 115200, 'Timeout', 1,'OutputBufferSize', 100000, 'InputBufferSize', 100000, 'DataTerminalReady', 'on', 'tag', 'ArCOM');
                    fopen(obj.Port);
                case 1
                    if ispc
                        portString = ['\\.\' portString];
                    end
                    IOPort('Verbosity', 0);
                    obj.Port = IOPort('OpenSerialPort', portString, 'BaudRate=115200, OutputBufferSize=1000000, InputBufferSize=1000000, DTR=1');
                    if (obj.Port < 0)
                        try
                            IOPort('Close', obj.Port);
                        catch
                        end
                        error(['Error: Unable to connect to port ' portString '. The port may be in use by another application.'])
                    end
                    pause(.1); % Helps on some platforms
                    varargout{1} = obj;
                case 2
                    if ispc
                        PortNum = str2double(portString(4:end));
                        if PortNum > 9
                            portString = ['\\\\.\\COM' num2str(PortNum)]; % As of Octave instrument control toolbox v0.2.2, ports higher than COM9 must use this syntax
                        end
                    end
                    obj.Port = serial(portString, 115200,  1);
                    pause(.2);
                    srl_flush(obj.Port);
            end
        end
        function bytesAvailable = bytesAvailable(obj)
            switch obj.Interface
                case 0 % MATLAB/Java
                    bytesAvailable = obj.Port.BytesAvailable;
                case 1 % MATLAB/PsychToolbox
                    bytesAvailable = IOPort('BytesAvailable', obj.Port);
                case 2 % Octave
                    error('Reading available bytes from a serial port buffer is not supported in Octave as of instrument control toolbox 0.2.2');
            end
        end
        function write(obj, varargin)
            if nargin == 2 % Single array with no data type specified (defaults to uint8)
                nArrays = 1;
                data2Send = varargin(1);
                dataTypes = {'uint8'};
            else
                nArrays = (nargin-1)/2;
                data2Send = varargin(1:2:end);
                dataTypes = varargin(2:2:end);
            end
            nTotalBytes = 0;
            DataLength = cellfun('length',data2Send);
            for i = 1:nArrays
                switch dataTypes{i}
                    case 'char'
                        nTotalBytes = nTotalBytes + DataLength(i);
                    case 'uint8'
                        nTotalBytes = nTotalBytes + DataLength(i);
                    case 'uint16'
                        DataLength(i) = DataLength(i)*2;
                        nTotalBytes = nTotalBytes + DataLength(i);
                    case 'uint32'
                        DataLength(i) = DataLength(i)*4;
                        nTotalBytes = nTotalBytes + DataLength(i);
                    case 'int8'
                        nTotalBytes = nTotalBytes + DataLength(i);
                    case 'int16'
                        DataLength(i) = DataLength(i)*2;
                        nTotalBytes = nTotalBytes + DataLength(i);
                    case 'int32'
                        DataLength(i) = DataLength(i)*4;
                        nTotalBytes = nTotalBytes + DataLength(i);
                end
            end
            ByteStringPos = 1;
            ByteString = uint8(zeros(1,nTotalBytes));
            for i = 1:nArrays
                dataType = dataTypes{i};
                data = data2Send{i};
                switch dataType % Check range and cast to uint8
                    case 'char'
                        if sum((data < 0)+(data > 128)) > 0
                            error('Error: a char was out of range: 0 to 128 (limited by Arduino)')
                        end
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = char(data);
                        ByteStringPos = ByteStringPos + DataLength(i);
                    case 'uint8'
                        if sum((data < 0)+(data > 255)) > 0
                            error('Error: an unsigned 8-bit integer was out of range: 0 to 255')
                        end
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = uint8(data);
                        ByteStringPos = ByteStringPos + DataLength(i);
                    case 'uint16'
                        if sum((data < 0)+(data > 65535)) > 0
                            error('Error: an unsigned 16-bit integer was out of range: 0 to 65,535')
                        end
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = typecast(uint16(data), 'uint8');
                        ByteStringPos = ByteStringPos + DataLength(i);
                    case 'uint32'
                        if sum((data < 0)+(data > 4294967295)) > 0
                            error('Error: an unsigned 32-bit integer was out of range: 0 to 4,294,967,295')
                        end
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = typecast(uint32(data), 'uint8');
                        ByteStringPos = ByteStringPos + DataLength(i);
                    case 'int8'
                        if sum((data < -128)+(data > 127)) > 0
                            error('Error: a signed 8-bit integer was out of range: -128 to 127')
                        end
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = typecast(int8(data), 'uint8');
                        ByteStringPos = ByteStringPos + DataLength(i);
                    case 'int16'
                        if sum((data < -32768)+(data > 32767)) > 0
                            error('Error: a signed 16-bit integer was out of range: -32,768 to 32,767')
                        end
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = typecast(int16(data), 'uint8');
                        ByteStringPos = ByteStringPos + DataLength(i);
                    case 'int32'
                        if sum((data < -2147483648)+(data > 2147483647)) > 0
                            error('Error: a signed 32-bit integer was out of range: -2,147,483,648 to 2,147,483,647')
                        end
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = typecast(int32(data), 'uint8');
                        ByteStringPos = ByteStringPos + DataLength(i);
                    otherwise
                        error(['The datatype ' dataType ' is not currently supported by ArCOM.']);
                end
            end
            switch obj.Interface
                case 0
                    fwrite(obj.Port, ByteString, 'uint8');
                case 1
                    IOPort('Write', obj.Port, ByteString, 1);
                case 2
                    srl_write(obj.Port, char(ByteString));
            end
        end
        function varargout = read(obj, varargin)
            if nargin == 2
                nArrays = 1;
                nValues = varargin(2);
                dataTypes = {'uint8'};
            else
                nArrays = (nargin-1)/2;
                nValues = varargin(1:2:end);
                dataTypes = varargin(2:2:end);
            end
            nValues = double(cell2mat(nValues));
            nTotalBytes = 0;
            for i = 1:nArrays
                switch dataTypes{i}
                    case 'char'
                        nTotalBytes = nTotalBytes + nValues(i);
                    case 'uint8'
                        nTotalBytes = nTotalBytes + nValues(i);
                    case 'uint16'
                        nTotalBytes = nTotalBytes + nValues(i)*2;
                    case 'uint32'
                        nTotalBytes = nTotalBytes + nValues(i)*4;
                    case 'int8'
                        nTotalBytes = nTotalBytes + nValues(i);
                    case 'int16'
                        nTotalBytes = nTotalBytes + nValues(i)*2;
                    case 'int32'
                        nTotalBytes = nTotalBytes + nValues(i)*4;
                end
            end
            switch obj.Interface
                case 0
                    ByteString = fread(obj.Port, nTotalBytes, 'uint8')';
                case 1
                    ByteString = IOPort('Read', obj.Port, 1, nTotalBytes);
                case 2
                    ByteString = srl_read(obj.Port, nTotalBytes);
            end
            if isempty(ByteString)
                error('Error: The serial port returned 0 bytes.')
            end
            Pos = 1;
            varargout = cell(1,nArrays);
            for i = 1:nArrays
                switch dataTypes{i}
                    case 'char'
                        varargout{i} = char(ByteString(Pos:Pos+nValues(i)-1)); Pos = Pos + nValues(i);
                    case 'uint8'
                        varargout{i} = uint8(ByteString(Pos:Pos+nValues(i)-1)); Pos = Pos + nValues(i);
                    case 'uint16'
                        varargout{i} = typecast(uint8(ByteString(Pos:Pos+(nValues(i)*2)-1)), 'uint16'); Pos = Pos + nValues(i)*2;
                    case 'uint32'
                        varargout{i} = typecast(uint8(ByteString(Pos:Pos+(nValues(i)*4)-1)), 'uint32'); Pos = Pos + nValues(i)*4;
                    case 'int8'
                        varargout{i} = typecast(uint8(ByteString(Pos:Pos+(nValues(i))-1)), 'int8'); Pos = Pos + nValues(i);
                    case 'int16'
                        varargout{i} = typecast(uint8(ByteString(Pos:Pos+(nValues(i)*2)-1)), 'int16'); Pos = Pos + nValues(i)*2;
                    case 'int32'
                        varargout{i} = typecast(uint8(ByteString(Pos:Pos+(nValues(i)*4)-1)), 'int32'); Pos = Pos + nValues(i)*4;
                end
            end
        end
        function delete(obj)
            switch obj.Interface
                case 0
                    fclose(obj.Port);
                    delete(obj.Port);
                case 1
                    IOPort('Close', obj.Port);
                case 2
                    fclose(obj.Port);
                    obj.Port = [];
            end
        end
        function close(obj)
            evalin('caller', ['clear ' inputname(1)])
        end
    end
end
