%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
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
%}

% ArCOM uses an Arduino library to simplify serial communication of different
% data types between MATLAB/GNU Octave and Arduino. To use the library,
% include the following at the top of your Arduino sketch:
% #include "ArCOM.h". See documentation for more Arduino-side tips.
%
% Initialization syntax:
% MyPort = ArCOMObject('COM3')
% where 'COM3' is the name of Arduino's serial port on your system
% This call both creates and opens the port. It returns an object containing
% a serial port and properties. If PsychToolbox IOport interface is
% available, this is used by default. To use the java interface on a system
% with PsychToolbox, use ArCOMObject('COM3', 'java')
%
% ArCOM can be created with the following optional arguments:
% MyPort = ArCOMObject('COM3', baudRate, Interface, TCPPort, InputBufferSize, OutputBufferSize, IOPortBackgroundReads)
% To avoid time-costly arg parsing, all arguments must be provided, up to the highest one needed.
% baudRate is in bps. This is ignored for microcontrollers with native USB support (e.g. 32-bit Arduino, Teensy 3.X-4.X).
% Interface can be either [], 'Java', 'PsychToolbox'. [] defaults to Java for r2019b or newer, and Psychtoolbox on older versions.
% TCPPort can be [], or a port on a remote computer if using the Ethernet interface.
% InputBufferSize and OutputBufferSize must be in range 0-10M bytes
% IOPortBackgroundReads is 0 (Do not Use Background Reads, Default) or 1 (Use Background Reads). Only relevant if IOPort serial interface is used.
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
% Clear unread bytes: MyPort.flush();
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
        PortName
    end
    properties (Access = private)
        InBuffer
        Timeout = 3;
        TCPport = 11258;
        OutputBufferSize = 1000000; % Bytes
        InputBufferSize = 1000000; % Bytes
        JavaPortType = 0;
    end
    methods
        function obj = ArCOMObject_Bpod(portString, varargin)
            obj.UsePsychToolbox = 0;
            obj.Interface = 0; % Java serial interface
            baudRate = 115200;
            obj.TCPport = [];
            IOPortBackgroundReadStr = [];
            InputBufferSize = 1000000;
            OutputBufferSize = 1000000;
            if verLessThan('matlab', '9.7') % Default to Psychtoolbox IOPort on old MATLAB
                try
                    PsychtoolboxVersion;
                    obj.UsePsychToolbox = 1;
                    obj.Interface = 1; % PsychToolbox serial interface
                catch
                end
            end
            if nargin > 1
                if ~isempty(varargin{1})
                    baudRate = varargin{1};
                end
            end
            if nargin > 2
                if ~isempty(varargin{2})
                    switch lower(varargin{2})
                        case 'java'
                            obj.UsePsychToolbox = 0;
                            obj.Interface = 0;
                        case 'psychtoolbox'
                            obj.UsePsychToolbox = 1;
                            obj.Interface = 1;
                        otherwise
                            error('The third argument to ArCOM(''init'' must be ''java'' or ''psychtoolbox''');
                    end
                end
            end
            if nargin > 3
                obj.TCPport = varargin{3};
            end
            if nargin > 4
                if ~isempty(varargin{4})
                    InputBufferSize = varargin{4};
                end
            end
            if nargin > 5
                if ~isempty(varargin{5})
                    OutputBufferSize = varargin{5};
                end
            end
            if InputBufferSize > 10000000 || InputBufferSize < 0
                error('ArCOM error: InputBufferSize must be in range 0,10000000')
            end
            if OutputBufferSize > 10000000 || OutputBufferSize < 0
                error('ArCOM error: OutputBufferSize must be in range 0,10000000')
            end
            obj.InputBufferSize = InputBufferSize;
            obj.OutputBufferSize = OutputBufferSize;
            if nargin > 6
                IOPortBackgroundReads = varargin{6};
                if IOPortBackgroundReads
                    IOPortBackgroundReadStr = ', PollLatency=0.001, StartBackgroundRead=1';
                end
            end

            obj.Port = [];
            obj.InBuffer = BpodDoubleSidedBuffer(obj.InputBufferSize);
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

            if ischar(baudRate)
                baudRate = str2double(baudRate);
            end
            if ~isnan(baudRate) && baudRate >= 1200
                obj.baudRate = baudRate;
            else
                error(['Error: ' baudRate ' is an invalid baud rate for ArCOM. Some common baud rates are: 9600, 115200'])
            end
            obj.validDataTypes = {'char', 'uint8', 'uint16', 'uint32', 'int8', 'int16', 'int32'};
            % If PortString is an IP address, set Interface to 3 or 4 (TCP/IP via Instrument Control or Psych Toolbox)
            if (portString(1) > 47) && (portString(1) < 58) && sum(portString == '.') > 2
                v = ver;
                hasITC = any(strcmp(cellstr(char(v.Name)), 'Instrument Control Toolbox'));
                if hasITC == 0
                    if obj.UsePsychToolbox == 0
                        error ('Error: You must install PsychToolbox or MATLAB Instrument Control Toolbox to connect to a Bpod state machine via Ethernet.')
                    else
                        obj.Interface = 4;
                    end
                else
                    if obj.UsePsychToolbox == 0
                        obj.Interface = 3;
                    else
                        obj.Interface = 4;
                    end
                end
            end
            originalPortString = portString;
            switch obj.Interface
                case 0
                    if verLessThan('matlab','9.7')
                        obj.Port = serial(portString, 'BaudRate', baudRate, 'Timeout', 3,'OutputBufferSize', obj.OutputBufferSize, 'InputBufferSize', obj.InputBufferSize, 'DataTerminalReady', 'on', 'tag', 'ArCOM');
                        fopen(obj.Port);
                        obj.JavaPortType = 0;
                    else
                        obj.Port = serialport(portString, baudRate);
                        setDTR(obj.Port, true);
                        obj.JavaPortType = 1;
                    end
                case 1
                    if ispc
                        portString = ['\\.\' portString];
                    end
                    IOPort('Verbosity', 0);
                    obj.Port = IOPort('OpenSerialPort', portString, ['ReceiveTimeout=3, BaudRate=' num2str(baudRate) ', OutputBufferSize=' num2str(obj.OutputBufferSize) ', InputBufferSize=' num2str(obj.InputBufferSize) ', DTR=1' IOPortBackgroundReadStr]);
                    if (obj.Port < 0)
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
                    obj.Port = serial(portString, baudRate,  1);
                    pause(.2);
                    srl_flush(obj.Port);
                case 3
                    obj.Port = tcpip(portString,obj.TCPport, 'InputBufferSize', obj.InputBufferSize, 'OutputBufferSize', obj.OutputBufferSize, 'Timeout', 3);
                    fopen(obj.Port);
                    pause(.1);
                    fwrite(obj.Port,'H', 'uint8');
                    ConnConfirmed = logical(fread(obj.Port, 1, 'uint8'));
                    if ~ConnConfirmed
                        fclose(obj.Port);
                        delete(obj.Port);
                        error(['Error: Could not connect to server at ' portString])
                    end
                case 4
                    obj.Port = pnet('tcpconnect',portString,obj.TCPport);
                    pause(.1);
                    pnet(obj.Port,'setwritetimeout',3);
                    pnet(obj.Port,'setreadtimeout',3);
                    pnet(obj.Port,'write', 'H')
                    ConnConfirmed = logical(uint8(pnet(obj.Port,'read', 1)));
                    if ~ConnConfirmed
                        fclose(obj.Port);
                        delete(obj.Port);
                        error(['Error: Could not connect to server at ' portString])
                    end
            end
            obj.PortName = originalPortString;
        end
        function bytesAvailable = bytesAvailable(obj)
            switch obj.Interface
                case 0 % MATLAB/Java
                    if obj.JavaPortType == 0
                        bytesAvailable = obj.Port.BytesAvailable + obj.InBuffer.bytesAvailable;
                    else
                        bytesAvailable = obj.Port.NumBytesAvailable + obj.InBuffer.bytesAvailable;
                    end
                case 1 % MATLAB/PsychToolbox
                    bytesAvailable = IOPort('BytesAvailable', obj.Port) + obj.InBuffer.bytesAvailable;
                case 2 % Octave
                    error('Reading available bytes from a serial port buffer is not supported in Octave as of instrument control toolbox 0.2.2');
                case 3
                    bytesAvailable = obj.Port.BytesAvailable + obj.InBuffer.bytesAvailable;
                case 4
                    bytesAvailable = length(pnet(obj.Port,'read', 65536, 'uint8', 'native','view', 'noblock')) + obj.InBuffer.bytesAvailable;
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
                    case 'uint64'
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = typecast(uint64(data), 'uint8');
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
                    case 'int64'
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = typecast(int64(data), 'uint8');
                        ByteStringPos = ByteStringPos + DataLength(i);
                    otherwise
                        error(['The datatype ' dataType ' is not currently supported by ArCOM.']);
                end
            end
            nFullWrites = floor(length(ByteString)/obj.OutputBufferSize);
            partialWriteLength = length(ByteString)-(nFullWrites*obj.OutputBufferSize);
            Pos = 1;
            switch obj.Interface
                case 0
                    for i = 1:nFullWrites
                        if obj.JavaPortType == 0
                            fwrite(obj.Port, ByteString(Pos:Pos+obj.OutputBufferSize-1), 'uint8');
                        else
                            obj.Port.write(ByteString(Pos:Pos+obj.OutputBufferSize-1), 'uint8');
                        end
                        Pos = Pos + obj.OutputBufferSize;
                    end
                    if partialWriteLength > 0
                        if obj.JavaPortType == 0
                            fwrite(obj.Port, ByteString(Pos:end), 'uint8');
                        else
                            obj.Port.write(ByteString(Pos:end), 'uint8');
                        end
                    end
                case 1
                    for i = 1:nFullWrites
                        IOPort('Write', obj.Port, ByteString(Pos:Pos+obj.OutputBufferSize-1), 1);
                        Pos = Pos + obj.OutputBufferSize;
                    end
                    if partialWriteLength > 0
                        IOPort('Write', obj.Port, ByteString(Pos:end), 1);
                    end
                case 2
                    srl_write(obj.Port, char(ByteString));
                case 3
                    fwrite(obj.Port, ['R' typecast(uint32(length(ByteString)), 'uint8'), ByteString]);
                case 4
                    pnet(obj.Port,'write', uint8(['R' typecast(uint32(length(ByteString)), 'uint8'), ByteString]));
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
                    case {'char', 'uint8', 'int8'}
                        nTotalBytes = nTotalBytes + nValues(i);
                    case {'uint16','int16'}
                        nTotalBytes = nTotalBytes + nValues(i)*2;
                    case {'uint32','int32'}
                        nTotalBytes = nTotalBytes + nValues(i)*4;
                    case {'uint64','int64'}
                        nTotalBytes = nTotalBytes + nValues(i)*8;
                end
            end
            CurrentTime = clock;
            StartTime = CurrentTime(end);
            CurrentTime = StartTime;
            while nTotalBytes > obj.InBuffer.bytesAvailable && (CurrentTime-StartTime < obj.Timeout)
                CurrentTime = clock;
                CurrentTime = CurrentTime(end);
                switch obj.Interface
                    case 0
                        if obj.JavaPortType == 0
                            nBytesAvailable = obj.Port.BytesAvailable;
                        else
                            nBytesAvailable = obj.Port.NumBytesAvailable;
                        end
                        if nBytesAvailable > 0
                            if obj.JavaPortType == 0
                                NewBytes = fread(obj.Port, nBytesAvailable, 'uint8')';
                            else
                                NewBytes = obj.Port.read(nBytesAvailable, 'uint8');
                            end
                            obj.InBuffer.write(NewBytes);
                        end
                    case 1
                        nBytesAvailable = IOPort('BytesAvailable', obj.Port);
                        if nBytesAvailable > 0
                            NewBytes = IOPort('Read', obj.Port, 1, nBytesAvailable);
                            obj.InBuffer.write(NewBytes);
                        end
                    case 2
                        error('Reading available bytes from a serial port buffer is not supported in Octave as of instrument control toolbox 0.2.2');
                    case 3
                        nBytesAvailable = obj.Port.BytesAvailable;
                        if nBytesAvailable > 0
                            NewBytes = fread(obj.Port, nBytesAvailable, 'uint8')';
                            obj.InBuffer.write(NewBytes);
                        end
                    case 4
                        nBytesAvailable = length(pnet(obj.Port,'read', 65536, 'uint8', 'native','view', 'noblock'));
                        if nBytesAvailable > 0
                            NewBytes = uint8(pnet(obj.Port,'read', nBytesAvailable, 'uint8'));
                            obj.InBuffer.write(NewBytes);
                        end
                end
            end
            if nTotalBytes > obj.InBuffer.bytesAvailable
                error('Error: The USB serial port did not return the requested number of bytes.')
            end
            varargout = cell(1,nArrays);
            for i = 1:nArrays
                switch dataTypes{i}
                    case 'char'
                        nBytesRead = nValues(i);
                        varargout{i} = char(obj.InBuffer.read(nBytesRead));
                    case 'uint8'
                        nBytesRead = nValues(i);
                        varargout{i} = obj.InBuffer.read(nBytesRead);
                    case 'uint16'
                        nBytesRead = nValues(i)*2;
                        varargout{i} = typecast(obj.InBuffer.read(nBytesRead), 'uint16');
                    case 'uint32'
                        nBytesRead = nValues(i)*4;
                        varargout{i} = typecast(obj.InBuffer.read(nBytesRead), 'uint32');
                    case 'uint64'
                        nBytesRead = nValues(i)*8;
                        varargout{i} = typecast(obj.InBuffer.read(nBytesRead), 'uint64');
                    case 'int8'
                        nBytesRead = nValues(i);
                        varargout{i} = typecast(obj.InBuffer.read(nBytesRead), 'int8');
                    case 'int16'
                        nBytesRead = nValues(i)*2;
                        varargout{i} = typecast(obj.InBuffer.read(nBytesRead), 'int16');
                    case 'int32'
                        nBytesRead = nValues(i)*4;
                        varargout{i} = typecast(obj.InBuffer.read(nBytesRead), 'int32');
                    case 'int64'
                        nBytesRead = nValues(i)*8;
                        varargout{i} = typecast(obj.InBuffer.read(nBytesRead), 'int64');
                end
            end
        end

        function flush(obj)
            obj.read(obj.bytesAvailable, 'uint8');
        end

        function delete(obj)
            switch obj.Interface
                case 0
                    if obj.JavaPortType == 0
                        fclose(obj.Port);
                        delete(obj.Port);
                    else
                        obj.Port = [];
                    end
                case 1
                    if (obj.Port >= 0)
                        IOPort('Close', obj.Port);
                    end
                case 2
                    fclose(obj.Port);
                    obj.Port = [];
                case 3
                    fclose(obj.Port);
                    delete(obj.Port);
                case 4
                    pnet(obj.Port,'close');
            end
        end
        function close(obj)
            evalin('caller', ['clear ' inputname(1)])
        end
    end
end
