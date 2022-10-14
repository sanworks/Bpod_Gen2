import numpy as np
import socket
# Constructor arguments:
#
# TCP_PORT = the port number to open (e.g. 11235).
#
# CXN_TYPE = 'local' to communicate with an instance of MATLAB on this PC, 
#            'network' for MATLAB on another machine on the local network

class TCPCom(object):
    def __init__(self, TCP_PORT, CXN_TYPE):
        self.typeNames = (
            'uint8', 'int8', 'char', 'uint16', 'int16', 
            'uint32', 'int32', 'uint64', 'int64', 'float32', 'float64')
        self.typeBytes = (1, 1, 1, 2, 2, 4, 4, 8, 8, 4, 8)
        
        # Get IP Address on local network
        testSock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        testIP = "8.8.8.8"
        testSock.connect((testIP, 0))
        self.tcpIP = testSock.getsockname()[0]
        testSock.close()
        
        if CXN_TYPE == 'local':
            self.tcpIP = 'localhost'
        elif CXN_TYPE != 'network':
            raise MLinkError('Error: ' + CXN_TYPE + ' is not a valid connection type.')
        
        # Setup TCP Server
        self.tcpPort = TCP_PORT
        self.tcpSocket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.tcpSocket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.tcpSocket.bind((self.tcpIP, self.tcpPort))
        self.connect2Client()
        
    def connect2Client(self):
        print ("Listening on IP:", self.tcpIP, " Port:", self.tcpPort)
        self.tcpSocket.listen(1) # Listen for up to 1 client before rejecting additional ones
        
        # Wait for connection
        self.tcpConnection, addr = self.tcpSocket.accept()
        print ('New Connection from IP: ', addr)
        self.tcpConnection.setblocking(False)
        
    def closeClientConnection(self):
        self.tcpConnection.shutdown(socket.SHUT_RDWR)
        self.tcpConnection.close()
        
    def read(self, nValues, dataType):
        if ((dataType in self.typeNames) is False):
            raise MLinkError('Error: ' + dataType + ' is not a data type supported by MATLABLink.')
        typeIndex = self.typeNames.index(dataType)
        byteWidth = self.typeBytes[typeIndex]
        nBytes2Read = nValues*byteWidth;
        data = bytearray(nBytes2Read)
        nBytesRead = 0
        while nBytesRead < nBytes2Read:
            try:
                if nBytes2Read-nBytesRead < 4096:
                    packet = self.tcpConnection.recv(nBytes2Read-nBytesRead)
                else:
                    packet = self.tcpConnection.recv(4096)
                if not packet:
                    return None
                packetLength = len(packet)
                data[nBytesRead:nBytesRead+packetLength] = packet
                nBytesRead += packetLength
            except:
                pass
        if nBytesRead < nBytes2Read:
            raise MLinkError('Error: tcp port timed out. ' + str(nBytesRead) + ' bytes read. Expected ' + str(nBytes2Read) +' byte(s).')
        output = np.frombuffer(data, dataType)
        return output
    def readByteNonBlocking(self):
        try:
            packet = self.tcpConnection.recv(1)
            output = np.frombuffer(packet, 'uint8')
        except:
            output = None
        return output
    def write(self, message, dataType):
        if ((dataType in self.typeNames) is False):
            raise MLinkError('Error: ' + dataType + ' is not a data type supported by MATLABLink.')
        if type(message).__module__ == np.__name__:
            NPdata = message.astype(dataType)
        else:
            NPdata = np.array(message, dtype=dataType)
        messageBytes = NPdata.tobytes()   
        self.tcpConnection.send(messageBytes)
        
    def bytesAvailable(self):
        try:
            peek = self.tcpConnection.recv(65536, socket.MSG_PEEK)
        except:
            peek = []
        return len(peek)
    
    def setBlocking(self, val):
        self.tcpConnection.setblocking(val)
        
    def setTimeout(self, val):
        self.tcpSocket.settimeout(val)
        self.tcpConnection.settimeout(val)
        
    def __del__(self):
        self.tcpConnection.shutdown(socket.SHUT_RDWR)
        self.tcpConnection.close()
        self.tcpSocket.close()
        
class MLinkError(Exception):
    pass