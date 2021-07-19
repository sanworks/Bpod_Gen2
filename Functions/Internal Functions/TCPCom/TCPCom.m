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

% TCPCom wraps the PsychToolbox PNET class for communication with processes
% on the same machine, or on the local network. It inherits read/write syntax
% from the Sanworks ArCOM class: https://github.com/sanworks/ArCOM
%
% Usage:
% T = TCPCom(Port); % Initialize a tcp SERVER on local port 'Port'. T is returned
%     when a client has connected.
%
% T = TCPCom(IP, Port); % Initialize a tcp CLIENT connecting to a server at IP
%     address 'IP' and port 'Port'. IP is a string, e.g. '192.168.1.100' or
%     'localhost' for a server running on the same machine.
%
% nBytes = T.bytesAvailable; % Returns the number of bytes available to read
%
% byteMessage = T.read(nBytes); % Reads nBytes from the connection
%
% [myInt16, myDouble] = T.read(10, 'int16', 50, 'double'); % reads 10
%                       16-bit signed integers into data_int16 and 50
%                       double type values into data_double
%
% T.write(byteMessage); % Writes byteMessage to the connection
% T.write(myInt16, 'int16', myDouble, 'double'); % Writes myInt16 and
%                             myDouble as their respective data types
%
% clear T; % Disconnect and release all resources

classdef TCPCom < handle
    properties
        TCPobj
        Port
        IPAddress
        NetworkRole
        validDataTypes
    end
    properties (Access = private)
        Socket
        InBuffer
        InBufferBytesAvailable
        Time2WaitForClient = 10; % Seconds to wait for a client
        Timeout = 3;
        IPaddress
        currentPort
    end
    methods
        function obj = TCPCom(varargin)
            IP = 'localhost';
            obj.Socket = -1;
            switch nargin
                case 1
                    obj.NetworkRole = 'Server';
                    Port = varargin{1};
                case 2
                    obj.NetworkRole = 'Client';
                    IP = varargin{1};
                    Port = varargin{2};
            end
            obj.TCPobj = [];
            obj.InBuffer = [];
            obj.InBufferBytesAvailable = 0;
            obj.validDataTypes = {'char', 'uint8', 'uint16', 'uint32', 'uint64', 'int8', 'int16', 'int32', 'int64', 'single', 'double'};
            switch obj.NetworkRole
                case 'Client'
                    obj.TCPobj = pnet('tcpconnect',IP,Port);
                case 'Server'
                    obj.Socket=pnet('tcpsocket',Port);
                    if obj.Socket == -1
                        error('TCPCom: Error creating socket on localhost.');
                    else
                        disp(['TCPCom: Created a socket on port ' num2str(Port) '. Waiting ' num2str(obj.Time2WaitForClient) 's for client connection...']);
                        pnet(obj.Socket,'setreadtimeout', obj.Time2WaitForClient);
                        obj.TCPobj=pnet(obj.Socket,'tcplisten');
                    end
            end
            if obj.TCPobj == -1
                if strcmp(obj.NetworkRole, 'Server')
                    pnet(obj.Socket, 'close');
                end
                error(['TCPCom: Could not connect to server at ' IP ' on port ' num2str(Port)])
            else
                disp(['TCPCom: Connection established on port ' num2str(Port)])
            end
            pause(.1);
            pnet(obj.TCPobj,'setwritetimeout',obj.Timeout);
            pnet(obj.TCPobj,'setreadtimeout',obj.Timeout);
            obj.IPAddress = IP;
            obj.Port = Port;
        end
        function bytesAvailable = bytesAvailable(obj)
            obj.assertConn; % Assert that connection is still active, and attempt to renew if not
            bytesAvailable = length(pnet(obj.TCPobj,'read', 65536, 'uint8', 'native','view', 'noblock')) + obj.InBufferBytesAvailable;
        end
        function write(obj, varargin)
            obj.assertConn; % Assert that connection is still active, and attempt to renew if not
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
                    case 'uint16'
                        DataLength(i) = DataLength(i)*2;
                    case 'uint32'
                        DataLength(i) = DataLength(i)*4;
                    case 'uint64'
                        DataLength(i) = DataLength(i)*8;
                    case 'int16'
                        DataLength(i) = DataLength(i)*2;
                    case 'int32'
                        DataLength(i) = DataLength(i)*4;
                    case 'int64'
                        DataLength(i) = DataLength(i)*8;
                    case 'single'
                        DataLength(i) = DataLength(i)*4;
                    case 'double'
                        DataLength(i) = DataLength(i)*8;
                end
                nTotalBytes = nTotalBytes + DataLength(i);
            end
            ByteStringPos = 1;
            ByteString = uint8(zeros(1,nTotalBytes));
            for i = 1:nArrays
                dataType = dataTypes{i};
                data = data2Send{i};
                switch dataType % Check range and cast to uint8
                    case 'char'
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = uint8(char(data));
                    case 'uint8'
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = uint8(data);
                    case 'uint16'
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = typecast(uint16(data), 'uint8');
                    case 'uint32'
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = typecast(uint32(data), 'uint8');
                    case 'uint64'
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = typecast(uint64(data), 'uint8');
                    case 'int8'
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = typecast(int8(data), 'uint8');
                    case 'int16'
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = typecast(int16(data), 'uint8');
                    case 'int32'
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = typecast(int32(data), 'uint8');
                    case 'int64'
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = typecast(int64(data), 'uint8');
                    case 'single'
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = typecast(single(data), 'uint8');
                    case 'double'
                        ByteString(ByteStringPos:ByteStringPos+DataLength(i)-1) = typecast(double(data), 'uint8');
                    otherwise
                        error(['Error: Data type: ' dataType ' not supported by PythonLink'])
                end
                ByteStringPos = ByteStringPos + DataLength(i);
            end
            pnet(obj.TCPobj,'write', ByteString);
        end
        function varargout = read(obj, varargin)
            obj.assertConn; % Assert that connection is still active, and attempt to renew if not
            if nargin == 2
                nArrays = 1;
                nValues = varargin(1);
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
                    case {'uint32','int32','single'}
                        nTotalBytes = nTotalBytes + nValues(i)*4;
                    case {'uint64','int64','double'}
                        nTotalBytes = nTotalBytes + nValues(i)*8;
                end
            end
            StartTime = now*100000;
            while nTotalBytes > obj.InBufferBytesAvailable && ((now*100000)-StartTime < obj.Timeout)
                nBytesAvailable = length(pnet(obj.TCPobj,'read', 65536, 'uint8', 'native','view', 'noblock'));
                if nBytesAvailable > 0
                    obj.InBuffer = [obj.InBuffer uint8(pnet(obj.TCPobj,'read', nBytesAvailable, 'uint8'))];
                end
                obj.InBufferBytesAvailable = obj.InBufferBytesAvailable + nBytesAvailable;
            end
            
            if nTotalBytes > obj.InBufferBytesAvailable
                error('Error: The TCP port did not return the requested number of bytes.')
            end
            Pos = 1;
            varargout = cell(1,nArrays);
            for i = 1:nArrays
                switch dataTypes{i}
                    case 'char'
                        nBytesRead = nValues(i);
                        varargout{i} = char(obj.InBuffer(1:nBytesRead));
                    case 'uint8'
                        nBytesRead = nValues(i);
                        varargout{i} = uint8(obj.InBuffer(1:nBytesRead));
                    case 'uint16'
                        nBytesRead = nValues(i)*2;
                        varargout{i} = typecast(uint8(obj.InBuffer(1:nBytesRead)), 'uint16');
                    case 'uint32'
                        nBytesRead = nValues(i)*4;
                        varargout{i} = typecast(uint8(obj.InBuffer(1:nBytesRead)), 'uint32');
                    case 'uint64'
                        nBytesRead = nValues(i)*8;
                        varargout{i} = typecast(uint8(obj.InBuffer(1:nBytesRead)), 'uint64');
                    case 'int8'
                        nBytesRead = nValues(i);
                        varargout{i} = typecast(uint8(obj.InBuffer(1:nBytesRead)), 'int8');
                    case 'int16'
                        nBytesRead = nValues(i)*2;
                        varargout{i} = typecast(uint8(obj.InBuffer(1:nBytesRead)), 'int16');
                    case 'int32'
                        nBytesRead = nValues(i)*4;
                        varargout{i} = typecast(uint8(obj.InBuffer(1:nBytesRead)), 'int32');
                    case 'int64'
                        nBytesRead = nValues(i)*8;
                        varargout{i} = typecast(uint8(obj.InBuffer(1:nBytesRead)), 'int64');
                    case 'single'
                        nBytesRead = nValues(i)*4;
                        varargout{i} = typecast(uint8(obj.InBuffer(1:nBytesRead)), 'single');
                    case 'double'
                        nBytesRead = nValues(i)*8;
                        varargout{i} = typecast(uint8(obj.InBuffer(1:nBytesRead)), 'double');
                end
                Pos = Pos + nBytesRead;
                obj.InBuffer = obj.InBuffer(nBytesRead+1:end);
                obj.InBufferBytesAvailable = obj.InBufferBytesAvailable - nBytesRead;
            end
        end
        function renew(obj) % Disconnect and renew connection
            if obj.TCPobj ~= -1
                pnet(obj.TCPobj,'close');
            end
            switch obj.NetworkRole
                case 'Server'
                    disp('Connection to client dropped. Attempting to reconnect...');
                    try
                        status = pnet(obj.Socket, 'status');
                    catch
                        obj.Socket=pnet('tcpsocket',obj.Port);
                        if obj.Socket == -1
                            error('TCPCom: Error creating socket on localhost.');
                        end
                    end
                    obj.TCPobj=pnet(obj.Socket,'tcplisten');
                    if obj.TCPobj == -1
                        pnet(obj.Socket, 'close');
                        error(['TCPCom: Could not connect to client on port ' num2str(obj.Port)])
                    end
                case 'Client'
                    obj.TCPobj = pnet('tcpconnect',obj.IPAddress,obj.Port);
                    if obj.TCPobj == -1
                        error(['TCPCom: Could not connect to server at ' obj.IPAddress ' on port ' num2str(obj.Port)])
                    end
            end
            pnet(obj.TCPobj,'setwritetimeout',obj.Timeout);
            pnet(obj.TCPobj,'setreadtimeout',obj.Timeout);
            disp('REMOTE HOST RECONNECTED');
        end
        function assertConn(obj)
            pnet(obj.TCPobj,'read', 1, 'uint8', 'native','view', 'noblock'); % Peek at first byte available. If connection is broken, this updates pnet 'status'
            status = pnet(obj.TCPobj, 'status');
            if status < 1
                obj.renew;
            end
        end
        function delete(obj)
            if obj.TCPobj ~= -1
                pnet(obj.TCPobj,'close');
                if obj.Socket > -1
                    pnet(obj.Socket, 'close');
                end
            end
        end
    end
end
