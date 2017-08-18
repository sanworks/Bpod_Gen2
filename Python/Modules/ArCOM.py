'''
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
'''
import struct
import serial

class ArCOMObject(object):
    def __init__(self, serialPortName, baudRate):
        self.serialObject = 0
        self.typeNames = ('uint8', 'int8', 'char', 'uint16', 'int16', 'uint32', 'int32')
        self.typeBytes = (1, 1, 1, 2, 2, 4, 4)
        self.typeSymbols = ('B', 'b', 'c', 'H', 'h', 'L', 'l')
        self.serialObject = serial.Serial(serialPortName, baudRate, timeout=1)
    def open(self, serialPortName, baudRate):
        self.serialObject = serial.Serial(serialPortName, baudRate, timeout=1)
    def close(self):
        self.serialObject.close()
    def bytesAvailable(self):
        return self.serialObject.inWaiting()
    def write(self,*arg):
        nTypes = len(arg)/2;
        argPos = 0;
        messageBytes = '';
        for i in range(0,nTypes):
            data = arg[argPos]
            argPos+= 1
            datatype = arg[argPos]
            if ((datatype in self.typeNames) is False):
                raise ArCOMError('Error: ' + datatype + ' is not a data type supported by ArCOM.')
            datatypePos = self.typeNames.index(datatype)
            argPos+= 1
            isList = False
            if isinstance(data, (tuple, list, str)):
                nValues = len(data)
                isList = True
            elif isinstance(data, int):
                nValues = 1
            else:
                raise ArCOMError('Error: Each python datatype to write must be int, str, tuple or list.')
            dataTypeSymbol = '<' + self.typeSymbols[datatypePos]*nValues
            if isList:
                messageBytes += struct.pack(dataTypeSymbol,*data)
            else:
                messageBytes += struct.pack(dataTypeSymbol,data)
        self.serialObject.write(messageBytes)
    def read(self, datatype): # Read one value
        if ((datatype in self.typeNames) is False):
            raise ArCOMError('Error: ' + datatype + ' is not a data type supported by ArCOM.')
        typeIndex = self.typeNames.index(datatype)
        dataTypeSymbol = self.typeSymbols[typeIndex]
        byteWidth = self.typeBytes[typeIndex]
        messageBytes = self.serialObject.read(byteWidth)
        nBytesRead = len(messageBytes)
        if nBytesRead < byteWidth:
            raise ArCOMError('Error: serial port timed out. ' + str(nBytesRead) + ' bytes read. Expected ' + str(nBytes2Read) +' byte(s).')
        dataFormat = '<' + dataTypeSymbol
        if datatype == 'char':
            thisOutput = str(messageBytes)
        else:
            thisOutput = struct.unpack(dataFormat,messageBytes)
            thisOutput = int(thisOutput[0])
        return thisOutput
    def readArray(self,*arg): # Read an array of values
        nTypes = len(arg)/2;
        argPos = 0;
        outputs = [];
        for i in range(0,nTypes):
            nValues = arg[argPos]
            argPos+= 1
            datatype = arg[argPos]
            if ((datatype in self.typeNames) is False):
                raise ArCOMError('Error: ' + datatype + ' is not a data type supported by ArCOM.')
            argPos+= 1
            typeIndex = self.typeNames.index(datatype)
            dataTypeSymbol = self.typeSymbols[typeIndex]
            byteWidth = self.typeBytes[typeIndex]
            nBytes2Read = nValues*byteWidth;
            messageBytes = self.serialObject.read(nBytes2Read)
            nBytesRead = len(messageBytes)
            if nBytesRead < nBytes2Read:
                raise ArCOMError('Error: serial port timed out. ' + str(nBytesRead) + ' bytes read. Expected ' + str(nBytes2Read) +' byte(s).')
            dataFormat = '<' + dataTypeSymbol*nValues
            if datatype == 'char':
                thisOutput = str(messageBytes)
            else:
                thisOutput = list(struct.unpack(dataFormat,messageBytes))
            outputs.append(thisOutput)
        if nTypes == 1:
            outputs = thisOutput
        return outputs
class ArCOMError(Exception):
    pass
