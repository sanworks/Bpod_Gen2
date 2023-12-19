classdef MCC_AnalogIn < handle
    properties
        nSecondsToAcquire = 30;
    end
    properties (Access = private)
        s % NIdaq Session
        ch % Analog channel
        lh % Listener handle
        dataBuffer
        dataBufferTemplate
        nSamplesToAcquire
        acqStartTime
    end
    methods
        function obj = MCC_AnalogIn(varargin)
            obj.s = daq.createSession('mcc');
            obj.s.Rate = 200000; % Set to 200kHz
            obj.ch = addAnalogInputChannel(obj.s,'Board0','ai0', 'Voltage');
            obj.ch.TerminalConfig = 'SingleEnded';
            obj.ch.Range = [-10,10];
            obj.dataBuffer.Data = [];
            obj.dataBuffer.Time = [];
            obj.dataBufferTemplate = obj.dataBuffer;
            if (nargin > 0)
                obj.nSecondsToAcquire = varargin{1};
            end
            obj.s.DurationInSeconds = obj.nSecondsToAcquire;
            obj.nSamplesToAcquire = obj.nSecondsToAcquire*obj.s.Rate;
        end
        function Data = acquire(obj)
            RawData = startForeground(obj.s);
            k = 5;
        end
        function startAcquiring(obj)
            obj.lh = addlistener(obj.s,'DataAvailable',@(h,e)obj.readData(e)); 
            startBackground(obj.s);
            obj.acqStartTime = now;
        end
        function data = GetData(obj)
            
            while length(obj.dataBuffer.Data) < obj.nSamplesToAcquire
                pause(.1);
            end
            data = obj.dataBuffer;
            data.Data = data.Data(1:obj.nSamplesToAcquire);
            data.Time = data.Time(1:obj.nSamplesToAcquire);
            obj.dataBuffer = obj.dataBufferTemplate;
            delete(obj.lh);
        end
        function readData(obj, newData)
            obj.dataBuffer.Data = [obj.dataBuffer.Data newData.Data'];
            obj.dataBuffer.Time = [obj.dataBuffer.Time newData.TimeStamps'];
        end
    end
end

