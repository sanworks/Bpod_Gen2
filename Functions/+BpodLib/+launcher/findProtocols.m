function ProtocolNames = findProtocols(BpodSystem)
% ProtocolNames = findProtocols(BpodSystem)
% Returns a cell array of protocol names found in the ProtocolFolder


if strcmp(BpodSystem.Path.ProtocolFolder, BpodSystem.SystemSettings.ProtocolFolder)  % todo: make this less janky?
    startPos = 3;
else
    startPos = 2;
end
Candidates = dir(BpodSystem.Path.ProtocolFolder);
ProtocolNames = cell(0);
nProtocols = 0;
for x = startPos:length(Candidates)
    if Candidates(x).isdir
        ProtocolFolder = fullfile(BpodSystem.Path.ProtocolFolder, Candidates(x).name);
        Contents = dir(ProtocolFolder);
        nItems = length(Contents);
        Found = 0;
        for y = 3:nItems
            if strcmp(Contents(y).name, [Candidates(x).name '.m'])
                Found = 1;
            end
        end
        if Found
            ProtocolName = Candidates(x).name;
        else
            ProtocolName = ['<' Candidates(x).name '>'];
        end
        nProtocols = nProtocols + 1;
        ProtocolNames{nProtocols} = ProtocolName;
    end
end

if isempty(ProtocolNames)
    ProtocolNames = {'No Protocols Found'};
else
    % Sort to put organizing directories first
    Types = ones(1,nProtocols);
    for i = 1:nProtocols
        ProtocolName = ProtocolNames{i};
        if ProtocolName(1) == '<'
            Types(i) = 0;
        end
    end
    [a, Order] = sort(Types);
    ProtocolNames = ProtocolNames(Order);
end

end