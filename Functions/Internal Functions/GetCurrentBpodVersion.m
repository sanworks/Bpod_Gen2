function latestVersion = GetCurrentBpodVersion(varargin)
branchName = 'master';
if nargin > 0
    branchName = varargin{1};
end
latestVersion = [];
[a,reply]=system('ping -n 1 www.google.com'); % Check for connection (works on Win + Linux)
if ~isempty(strfind(reply, 'Received = 1')) % If connected, read console version m-file from Gen2 repo master branch
    [reply, status] = urlread(['https://raw.githubusercontent.com/sanworks/Bpod_Gen2/' branchName '/Functions/Internal%20Functions/BpodSoftwareVersion.m']);
    verPos = find(reply == '=');
    if ~isempty(verPos)
        verString = strtrim(reply(verPos(end)+1:end-1));
        latestVersion = str2double(verString);
    end
end