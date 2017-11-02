function latestVersion = GetCurrentBpodVersion(varargin)
branchName = 'master';
if nargin > 0
    branchName = varargin{1};
end
latestVersion = [];
if ispc
    [a,reply]=system('ping -n 1 -w 1000 www.google.com'); % Check for connection
    ConnectConfirmString = 'Received = 1';
elseif ismac

else
    [a,reply]=system('timeout 1 ping -c 1 www.google.com'); % Check for connection
    ConnectConfirmString = '1 received';
end

if ~isempty(strfind(reply, ConnectConfirmString)) % If connected, read console version m-file from Gen2 repo master branch
    [reply, status] = urlread(['https://raw.githubusercontent.com/sanworks/Bpod_Gen2/' branchName '/Functions/Internal%20Functions/BpodSoftwareVersion.m']);
    verPos = find(reply == '=');
    if ~isempty(verPos)
        verString = strtrim(reply(verPos(end)+1:end-1));
        latestVersion = str2double(verString);
    end
end