function BonsaiOverride
global BpodSystem
Message = fread(BpodSystem.BonsaiSocket, BpodSystem.BonsaiSocket.BytesAvailable);
fwrite(BpodSystem.SerialPort, Message);