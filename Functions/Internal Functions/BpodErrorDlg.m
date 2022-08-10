%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2017 Sanworks LLC, Stony Brook, New York, USA

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
function BpodErrorDlg(Message, varargin)
global BpodSystem
generateError = 1;
if nargin > 1
    generateError = varargin{1};
end
try
    ErrorFigHandle = BpodSystem.GUIHandles.BpodErrorFig;
    close(ErrorFigHandle);
catch
end
BpodSystem.GUIHandles.BpodErrorFig = figure('Position', [650 480 397 150],...
    'name','Bpod Error','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('ErrorDlgBG.bmp');
image(BG); axis off; drawnow;
text(128, 20,'ERROR', 'FontName', 'OCRAStd', 'FontSize', 16, 'Color', [1 0 0]);
NewLinePos = find(Message == 10);
nSegments = 1;
if isempty(NewLinePos)
    messageLines = {Message};
else
    nSegments = length(NewLinePos)+1;
    NewLinePos = [NewLinePos length(Message)];
    Pos = 1;
    for i = 1:length(NewLinePos)
        messageLines{i} = Message(Pos:NewLinePos(i)-1);
        Pos = Pos + NewLinePos(i);
    end
end
Xpos = 45;
for i = 1:nSegments
    Ypos = 190-(length(messageLines{i})*4);
    text(Ypos, Xpos, messageLines{i}, 'FontName', 'OCRAStd', 'FontSize', 12, 'Color', [1 0 0]);
    Xpos = Xpos + 18;
end
BpodSystem.GUIHandles.BpodErrorBtn = uicontrol('Style', 'pushbutton', 'String', 'Ok',...
    'Position', [170 10 60 40], 'Callback', 'evalin(''base'', ''close(BpodSystem.GUIHandles.BpodErrorFig)'')',...
    'FontSize', 12,'Backgroundcolor',[0.7 0.1 0.1], 'FontName', 'OCRAStd');
if generateError ~= 0
    error(Message);
end