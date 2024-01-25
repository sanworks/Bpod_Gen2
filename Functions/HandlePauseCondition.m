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

% HandlePauseCondition() halts execution if the user has pressed the 'pause'
% button on the Bpod console GUI to schedule a pause in the next inter-trial interval. 
% While halted, HandlePauseCondition idles in a loop and returns after the 'play' 
% button is pressed by the user. This feature can be used to manually adjust
% something on the rig if necessary before continuing the session.
% 
% Arguments: None
% Returns: None
% Example usage: HandlePauseCondition;

function HandlePauseCondition

global BpodSystem % Import the global BpodSystem object

if BpodSystem.Status.Pause == 1
    set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.GoButton, 'TooltipString', 'Press to resume');
    disp('Protocol paused. Press the "play" button to resume.')
    lastStateName = get(BpodSystem.GUIHandles.CurrentStateDisplay, 'String');
    set(BpodSystem.GUIHandles.CurrentStateDisplay, 'String', 'PAUSED', 'FontSize', 11);
    colorState = 0;
    while BpodSystem.Status.Pause == 1
        pause(.25);
        if colorState == 0
            colorState = 1;
            set(BpodSystem.GUIHandles.CurrentStateDisplay, 'ForegroundColor', [0 0 0]);
            set(BpodSystem.GUIHandles.CurrentStateDisplay, 'BackgroundColor', [1 0 0]);
        else
            colorState = 0;
            set(BpodSystem.GUIHandles.CurrentStateDisplay, 'ForegroundColor', [1 0 0]);
            set(BpodSystem.GUIHandles.CurrentStateDisplay, 'BackgroundColor', [0 0 0]);
        end
        
    end
    set(BpodSystem.GUIHandles.CurrentStateDisplay, 'ForegroundColor', [0 0 0]);
    set(BpodSystem.GUIHandles.CurrentStateDisplay, 'String', lastStateName, 'FontSize', 9, 'BackgroundColor', [.8 .8 .8]);
end
