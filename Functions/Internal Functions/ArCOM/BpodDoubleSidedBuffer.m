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

classdef BpodDoubleSidedBuffer < handle
    % Implements a double sided buffer for bytes (uint8 type).
    % This is more efficient than a circular buffer, but requires twice the memory.
    
    properties
        bytesAvailable
    end
    
    properties (Access = private)
        Buffer1
        Buffer2
        Buffer1WritePos = 1;
        Buffer2WritePos = 1;
        Buffer1ReadPos = 1;
        Buffer2ReadPos = 1;
        currentOutputBuffer
        bufferSizeInBytes
    end
    
    methods
        function obj = BpodDoubleSidedBuffer(bufferSizeInBytes)
            obj.bufferSizeInBytes = bufferSizeInBytes;
            obj.Buffer1 = zeros(1,obj.bufferSizeInBytes, 'uint8');
            obj.Buffer2 = zeros(1,obj.bufferSizeInBytes, 'uint8');
            obj.currentOutputBuffer = 2;
            obj.bytesAvailable = 0;
        end
        
        function obj = write(obj,dataIn)
            nBytes = length(dataIn);
            switch obj.currentOutputBuffer
                case 1
                    if obj.Buffer2WritePos + nBytes - 1 > obj.bufferSizeInBytes
                        error('Error: Buffer overflow');
                    end
                    obj.Buffer2(obj.Buffer2WritePos:obj.Buffer2WritePos+nBytes-1) = dataIn;
                    obj.Buffer2WritePos = obj.Buffer2WritePos + nBytes;
                case 2
                    if obj.Buffer1WritePos + nBytes - 1 > obj.bufferSizeInBytes
                        error('Error: Buffer overflow');
                    end
                    obj.Buffer1(obj.Buffer1WritePos:obj.Buffer1WritePos+nBytes-1) = dataIn;
                    obj.Buffer1WritePos = obj.Buffer1WritePos + nBytes;
            end
            obj.bytesAvailable = obj.bytesAvailable + nBytes;
        end
        
        function dataOut = read(obj,nBytes)
            if nBytes > obj.bytesAvailable
                error(['Error: Tried to read ' num2str(nBytes) ' bytes but ' num2str(obj.bytesAvailable) ' are available']);
            end
            dataOut = obj.Buffer1(1:nBytes); % Preallocate, faster than zeros() but contains random data
            dataOutPos = 1;
            switch obj.currentOutputBuffer
                case 1
                    nBytes2Read = obj.Buffer1WritePos - obj.Buffer1ReadPos;
                    if nBytes2Read > nBytes
                        nBytes2Read = nBytes;
                    end
                    if nBytes2Read > 0
                        dataOut(1:nBytes2Read) = obj.Buffer1(obj.Buffer1ReadPos:obj.Buffer1ReadPos+nBytes2Read-1);
                        obj.Buffer1ReadPos = obj.Buffer1ReadPos + nBytes;
                    end
                    if nBytes2Read < nBytes % This buffer is empty. Time to swap.
                        dataOutPos = dataOutPos + nBytes2Read;
                        nBytesToRead = nBytes - (dataOutPos-1);
                        if obj.Buffer2WritePos < nBytesToRead
                            error('Error: Buffer underrun');
                        end
                        dataOut(dataOutPos:nBytes) = obj.Buffer2(1:nBytesToRead);
                        obj.Buffer2ReadPos = nBytesToRead + 1;
                        obj.currentOutputBuffer = 2;
                        obj.Buffer1ReadPos = 1;
                        obj.Buffer1WritePos = 1;
                    end
                case 2
                    nBytes2Read = obj.Buffer2WritePos - obj.Buffer2ReadPos;
                    if nBytes2Read > nBytes
                        nBytes2Read = nBytes;
                    end
                    if nBytes2Read > 0
                        dataOut(1:nBytes2Read) = obj.Buffer2(obj.Buffer2ReadPos:obj.Buffer2ReadPos+nBytes2Read-1);
                        obj.Buffer2ReadPos = obj.Buffer2ReadPos + nBytes;
                    end
                    if nBytes2Read < nBytes % This buffer is empty. Time to swap.
                        dataOutPos = dataOutPos + nBytes2Read;
                        nBytesToRead = nBytes - (dataOutPos-1);
                        if obj.Buffer1WritePos < nBytesToRead
                            error('Error: Buffer underrun');
                        end
                        dataOut(dataOutPos:nBytes) = obj.Buffer1(1:nBytesToRead);
                        obj.Buffer1ReadPos = nBytesToRead + 1;
                        obj.currentOutputBuffer = 1;
                        obj.Buffer2ReadPos = 1;
                        obj.Buffer2WritePos = 1;
                    end
            end
            obj.bytesAvailable = obj.bytesAvailable - nBytes;
        end
    end
end

