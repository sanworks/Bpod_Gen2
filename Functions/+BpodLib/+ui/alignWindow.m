function alignWindow(fig, targetFig)
% Aligns top right of a figure window with the top right of another window.
% alignWindow(fig, targetFig)
%
% Parameters
% ----------
% fig : Figure
%     The window to move.
% targetFig : Figure | position vector
%     The window to align with, or the Position of the figure (i.e. [left bottom width height])

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

% Get the positions of the figures
if ~isa(fig, 'matlab.ui.Figure')
    error('BpodLib:alignWindow:InvalidHandle', 'Window to move is not a figure.')
end
figPos = get(fig, 'Position');
if isa(targetFig, 'matlab.ui.Figure')
    targetPos = get(targetFig, 'Position');
elseif numel(targetFig) == 4
    targetPos = targetFig; % If targetFig is a position vector
else
    error('BpodLib:alignWindow:InvalidTarget', 'Target must be figure or position vector.');
end

% Calculate new origins (are from bottom left)
newX = targetPos(1) + targetPos(3) - figPos(3);
newY = targetPos(2) + targetPos(4) - figPos(4);

set(fig, 'Position', [newX, newY, figPos(3), figPos(4)]);
end