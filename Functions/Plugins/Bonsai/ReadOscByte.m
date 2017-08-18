function OscByte = ReadOscByte
global BpodSystem
Message = BpodSocketServer('read', 16);
OscByte = uint8(Message(16));