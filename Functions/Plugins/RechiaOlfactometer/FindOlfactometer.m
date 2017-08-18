function OlfIp = FindOlfactometer()
load OlfConfig
LastKnownIP = OlfConfig.OlfServerIP;
Candidates = cell(1);
nCandidates = 0;
progressbar;
Found = 0;
FormattedLocalIP = GetMyIP('I');
if FormattedLocalIP(4) < 100
    StartSearch = 0;
else
    StartSearch = 99;
end
x = 1;
while (x < 50) && (Found == 0)
    progressbar(x/50)
    try
        Candidate = [FormattedLocalIP(1:end-1) x+StartSearch];
        Candidate = [num2str(Candidate(1)) '.' num2str(Candidate(2)) '.' num2str(Candidate(3)) '.' num2str(Candidate(4))];
        Response = TCPWrite(Candidate, 3336, 'NOOP');
        Response = strtrim(Response);
        if strcmp(Response, 'OK')
            nCandidates = nCandidates + 1;
            Candidates{nCandidates} = Candidate;
            progressbar(1)
            Found = 1;
        end
    catch
        k = 5;
    end
    x = x + 1;
end
if ~isempty(Candidates)
    OlfIp = Candidates{1};
end