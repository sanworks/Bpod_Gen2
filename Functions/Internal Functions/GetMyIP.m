function IP = GetMyIP(varargin)

% Function to get the system's IP address
% Optional FORMAT argument specifies format
% FORMAT = 'I' for a four byte integer array
% FORMAT = 'S' for a string
% Usage example: IP = GetMyIP('I')

% Intended to be Platform-independent
% Tested on:
% r2013a/Win7
% r2008b/XP
% r2012a/OSX
% JS January 2014

if nargin > 0
    format = varargin{1};
else
    format = 'S';
end

address = java.net.InetAddress.getLocalHost;
ipAddress = char(address.getHostAddress);
if format == 'I'
    Dots = find(ipAddress == uint8('.'));
    IP(1) = uint8(str2double(ipAddress(1:Dots(1)-1)));
    IP(2) = uint8(str2double(ipAddress(Dots(1)+1:Dots(2)-1)));
    IP(3) = uint8(str2double(ipAddress(Dots(2)+1:Dots(3)-1)));
    IP(4) = uint8(str2double(ipAddress(Dots(3)+1:end)));
elseif format == 'S'
    IP = ipAddress;
else
    error('Error: Invalid format specified for IP address. Valid formats are: ''I'' (Integer array) or ''S'' (String)')
end