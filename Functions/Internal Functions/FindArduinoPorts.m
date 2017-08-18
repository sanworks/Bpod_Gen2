function ArduinoPorts = FindArduinoPorts

if ispc
    [Status RawString] = system('wmic path Win32_SerialPort Where "Caption LIKE ''%Arduino%''" Get DeviceID'); % Search for Arduino on USB Serial
    PortLocations = strfind(RawString, 'COM');
    ArduinoPorts = cell(1,100);
    nPorts = length(PortLocations);
    for x = 1:nPorts
        Clip = RawString(PortLocations(x):PortLocations(x)+6);
        ArduinoPorts{x} = Clip(1:find(Clip == 32,1, 'first')-1);
    end
    ArduinoPorts = ArduinoPorts(1:nPorts);
 elseif ismac % Contributed by Thiago Gouvea JUN_9_2016
    [trash, RawSerialPortList] = system('ls /dev/tty.usbmodem*');
    string = strtrim(RawSerialPortList);
    PortStringPositions = strfind(string, '/dev/tty.usbmodem');
    nPorts = length(PortStringPositions);
    CandidatePorts = cell(1,nPorts);
    nGoodPorts = 0;
    for x = 1:nPorts
        if PortStringPositions(x)+20 <= length(string)
            CandidatePort = strtrim(string(PortStringPositions(x):PortStringPositions(x)+20));
            nGoodPorts = nGoodPorts + 1;
            CandidatePorts{nGoodPorts} = CandidatePort;
        end
    end
    ArduinoPorts = CandidatePorts(1:nGoodPorts);
else
    [trash, RawSerialPortList] = system('ls /dev/ttyACM*');
    string = strtrim(RawSerialPortList);
    PortStringPositions = strfind(string, '/dev/ttyACM');
    nPorts = length(PortStringPositions);
    CandidatePorts = cell(1,nPorts);
    nGoodPorts = 0;
    for x = 1:nPorts
        if PortStringPositions(x)+11 <= length(string)
            CandidatePort = strtrim(string(PortStringPositions(x):PortStringPositions(x)+11));
            nGoodPorts = nGoodPorts + 1;
            CandidatePorts{nGoodPorts} = CandidatePort;
        end
    end
    ArduinoPorts = CandidatePorts(1:nGoodPorts);
end