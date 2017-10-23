function USBSerialPorts = FindUSBSerialPorts(obj)
    SerialPortKeywords = {'Arduino', 'Teensy', 'Sparkfun', 'COM'};
    nKeywords = length(SerialPortKeywords);
    USBSerialPorts = struct;
    if ispc
        for k = 1:nKeywords
            USBSerialPorts.(SerialPortKeywords{k}) = cell(1,100);
        end
        for k = 1:nKeywords
            [Status RawString] = system(['wmic path Win32_SerialPort Where "Caption LIKE ''%' SerialPortKeywords{k} '%''" Get DeviceID']);
            PortLocations = strfind(RawString, 'COM');
            nPorts = length(PortLocations);
            nPortsAdded = 0;
            for p = 1:nPorts
                Clip = RawString(PortLocations(p):PortLocations(p)+6);
                CandidatePort = Clip(1:find(Clip == 32,1, 'first')-1);
                if ~strcmp(CandidatePort, 'COM1')
                    novelPort = 1;
                    for i = 1:nKeywords
                        if sum(strcmp(CandidatePort, USBSerialPorts.(SerialPortKeywords{i}))) > 0
                            novelPort = 0;
                        end
                    end
                    if novelPort == 1
                        nPortsAdded = nPortsAdded + 1;
                        USBSerialPorts.(SerialPortKeywords{k}){nPortsAdded} = CandidatePort;
                    end
                end
            end
            USBSerialPorts.(SerialPortKeywords{k}) = USBSerialPorts.(SerialPortKeywords{k})(1:nPortsAdded);
        end
    elseif ismac % Contributed by Thiago Gouvea JUN_9_2016
        [trash, RawSerialPortList] = system('ls /dev/cu.usbmodem*');
        string = strtrim(RawSerialPortList);
        PortStringPositions = strfind(string, '/dev/cu.usbmodem');
        StringEnds = find(string == 9);
        nPorts = length(PortStringPositions);
        CandidatePorts = cell(1,nPorts);
        nGoodPorts = 0;
        for x = 1:nPorts
            if x < nPorts && nPorts > 1
                CandidatePort = string(PortStringPositions(x):StringEnds(x)-1);
            elseif x == nPorts
                CandidatePort = string(PortStringPositions(x):end);
            end
            nGoodPorts = nGoodPorts + 1;
            CandidatePorts{nGoodPorts} = CandidatePort;
        end
        USBSerialPorts.(SerialPortKeywords{1}) = CandidatePorts(1:nGoodPorts);
        if nKeywords > 1
            for i = 2:nKeywords
                USBSerialPorts.(SerialPortKeywords{i}) = '';
            end
        end
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
        USBSerialPorts.(SerialPortKeywords{1}) = CandidatePorts(1:nGoodPorts);
        if nKeywords > 1
            for i = 2:nKeywords
                USBSerialPorts.(SerialPortKeywords{i}) = '';
            end
        end
    end
end