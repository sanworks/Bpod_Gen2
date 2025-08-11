function formattedPanelName = formatPanelDisplayName(moduleName)
% Format module name for Console display in uicontrol
% formattedPanelName = formatPanelDisplayName(moduleName)
%
% MATLAB's undocumented support for HTML in uicontrol apparently ended in
% 2025 and \n in older versions behaves differently so a compatibility
% function is required
%
% Arguments
% ---------
% moduleName : char
%     Name of module
%
% Returns
% -------
% formattedPanelName : char
%     Name with version compatible split into two lines

%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) Sanworks LLC, Rochester, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the 
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}

compatibleHTML = verLessThan('matlab', '25');

if strcmp(moduleName, 'State Machine')
    if compatibleHTML
        formattedPanelName = '<html>&nbsp;State<br>Machine</html>';
    else
        formattedPanelName = sprintf('State\nMachine');
    end
    return
end

uCase = (moduleName > 64 & moduleName < 91);
lCase = (moduleName > 96 & moduleName < 123);
if sum(uCase) == 2 && length(uCase) > 5 && sum(lCase) > 0
    % if the module name is long enough split into two lines
    capPos = find(uCase);
    namePart1 = moduleName(1:capPos(2)-1);
    namePart2 = moduleName(capPos(2):end);
    if compatibleHTML
        bufferLength = 5-length(namePart2);
        if bufferLength < 1
            bufferLength = 0;
        end
        buffer = ['<html>' repmat('&nbsp;', 1, bufferLength)];
        namePart2 = [buffer namePart2(1:end-1) ' ' namePart2(end)];
        formattedPanelName = ['<html>&nbsp;' namePart1 '<br>' namePart2];
    else
        namePart2 = [namePart2(1:end-1) ' ' namePart2(end)];
        formattedPanelName = sprintf('%s\n%s', namePart1, namePart2);
    end
else
    moduleName = [moduleName(1:end-1) ' ' moduleName(end)];
    formattedPanelName = moduleName;
end

end