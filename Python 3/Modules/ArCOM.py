'''
----------------------------------------------------------------------------

This file is part of the Sanworks ArCOM repository
Copyright (C) 2017 Sanworks LLC, Stony Brook, New York, USA

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
import numpy as np
import serial

class ArCOMObject(object):
    def __init__(self, serialPortName, baudRate):
        self.serialObject = 0
        self.typeNames = ('uint8', 'int8', 'char', 'uint16', 'int16', 'uint32', 'int32')
        self.typeBytes = (1, 1, 1, 2, 2, 4, 4)
        self.typeSymbols = ('B', 'b', 'c', 'H', 'h', 'L', 'l')
        self.serialObject = serial.Serial(serialPortName, baudRate, timeout=1)
    def __del__(self):
        self.serialObject.close()
    def open(self, serialPortName, baudRate):
        self.serialObject = serial.Serial(serialPortName, baudRate, timeout=1)
    def close(self):
        self.serialObject.close()
    def bytesAvailable(self):
        return self.serialObject.inWaiting()
    def write(self,*arg):
        nTypes = int(len(arg)/2)
        argPos = 0;
        messageBytes = b''
        for i in range(0,nTypes):
            data = arg[argPos]
            argPos+= 1
            datatype = arg[argPos]
            argPos+= 1
            if ((datatype in self.typeNames) is False):
                raise ArCOMError('Error: ' + datatype + ' is not a data type supported by ArCOM.')
            datatypePos = self.typeNames.index(datatype)
            
            if type(data).__module__ == np.__name__:
                NPdata = data
            else:
                if isinstance(data, str):
                    NPdata = np.array(data, 'c')
                else:
                    NPdata = np.array(data, dtype=datatype)
            messageBytes += NPdata.tobytes()               
        self.serialObject.write(messageBytes)
    def read(self,*arg): # Read an array of values
        nTypes = int(len(arg)/2);
        argPos = 0;
        returnType = 0; # Set to 1 to return numpy types
        outputs = [];
        for i in range(0,nTypes):
            nValues = arg[argPos]
            argPos+= 1
            datatype = arg[argPos]
            if ((datatype in self.typeNames) is False):
                raise ArCOMError('Error: ' + datatype + ' is not a data type supported by ArCOM.')
            argPos+= 1
            typeIndex = self.typeNames.index(datatype)
            byteWidth = self.typeBytes[typeIndex]
            nBytes2Read = int(nValues*byteWidth);
            datatype2Read = datatype
            if datatype == 'char':
                datatype2Read = 'uint8'
            if nBytes2Read > 1:
                k = 5
            messageBytes = self.serialObject.read(nBytes2Read)
            nBytesRead = len(messageBytes)
            if nBytesRead < nBytes2Read:
                raise ArCOMError('Error: serial port timed out. ' + str(nBytesRead) + ' bytes read. Expected ' + str(nBytes2Read) +' byte(s).')
            thisOutput = np.frombuffer(messageBytes, datatype2Read)
            if nTypes == 1:
                if returnType == 0: # Standard
                    if len(thisOutput) > 1:
                        if datatype == 'char':
                            outputs = messageBytes.decode("utf-8")
                        else:
                            outputs = thisOutput.tolist()
                    else:
                        if datatype == 'char':
                            outputs = messageBytes.decode("utf-8")
                        else:
                            outputs = int(thisOutput[0]);    
                else:
                    outputs = thisOutput
            else:
                if returnType == 0: # Standard
                    if len(thisOutput) > 1:
                        if datatype == 'char':
                            outputs.append(messageBytes.decode("utf-8"))
                        else:
                            outputs.append(thisOutput.tolist())
                    else:
                        outputs.append(thisOutput[0])    
                else: # Numpy
                    outputs.append(thisOutput)
        return outputs
class ArCOMError(Exception):
    pass
