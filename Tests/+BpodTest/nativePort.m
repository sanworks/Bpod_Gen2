function comport = nativePort(varargin)
% Convert a serial port identifier into its machine format
% comport = nativePort(comport)

p = inputParser();
p.addRequired('comport');
p.addParameter('idformat', true, @islogical);
p.parse(varargin{:});
comport = p.Results.comport;

if isa(comport, 'cell')
    comportArray = cell(size(comport));
    for idx = 1:numel(comport)
        comportArray{idx} = BpodTest.nativePort(comport{idx}, 'idformat', p.Results.idformat);
    end
    comport = comportArray;
    return;
end

if isunix && ~ispc
    if startsWith(comport, 'COM')
        comport = replace(comport, 'COM', '/dev/ttyACM');
    end
else
    if startsWith(comport, '/dev/')
        % could be ttyACM 
        comport = replace(comport, '/dev/ttyACM', 'COM');
        comport = replace(comport, '/dev/ttyUSB', 'COM');
    end
end

if p.Results.idformat
    comport = erase(comport, '/dev/');
end
end