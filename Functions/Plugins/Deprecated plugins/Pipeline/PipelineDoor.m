function varargout = PipelineDoor(op, varargin)
global PipelineSystem
switch op
    case 'init'
        Port = varargin{1};
        if ispc
           PipelineSystem.SerialPort = serial(Port, 'BaudRate', 9600, 'Timeout', 1, 'DataTerminalReady', 'on');
        else
           PipelineSystem.SerialPort = serial(Port, 'BaudRate', 9600, 'Timeout', 1, 'DataTerminalReady', 'off');
        end
        fopen(PipelineSystem.SerialPort);
    case 'open'
        GateID = varargin{1};
        fwrite(PipelineSystem.SerialPort, ['O' GateID]);
    case 'clean'
        GateID = varargin{1};
        fwrite(PipelineSystem.SerialPort, ['L' GateID]);
    case 'endClean'
        GateID = varargin{1};
        fwrite(PipelineSystem.SerialPort, ['E' GateID]);
    case 'close'
        GateID = varargin{1};
        fwrite(PipelineSystem.SerialPort, ['C', GateID]);
         Result = WaitForDoorClose;
         varargout{1} = Result;
    case 'cycle'
        GateID = varargin{1};
        fwrite(PipelineSystem.SerialPort, ['S' GateID], 'uint8');
        Result = WaitForDoorClose;
        varargout{1} = Result;
    case 'readSensor'
        SensorID = varargin{1};
        fwrite(PipelineSystem.SerialPort, ['R' SensorID], 'uint8');
        SensorValue = fread(PipelineSystem.SerialPort, 1);
        varargout{1} = SensorValue;
    case 'end'
        fclose(PipelineSystem.SerialPort);
        delete(PipelineSystem.SerialPort);
end

function Result = WaitForDoorClose
global PipelineSystem
tic
while PipelineSystem.SerialPort.BytesAvailable == 0
%     pause(.001);
%     if toc > 1
%         error('Error: Door close failure detected.')
%     end
end
Result = fread(PipelineSystem.SerialPort, PipelineSystem.SerialPort.BytesAvailable);