function ByteMessage = Osc2Bytes(OscMessage)
% Returns an array containing the lowest bytes of 32-bit ints from an Osc message
MessageLength = length(OscMessage);
CommaPos = find(OscMessage==44, 1, 'first');
StartPos = CommaPos+4;
nBytes = (MessageLength-StartPos+1)/4;
ByteMessage = uint8(zeros(1,nBytes));
Pos = StartPos;
for x = 1:nBytes
    ByteMessage(x) = uint8(OscMessage(Pos+3));
    Pos = Pos + 4;
end