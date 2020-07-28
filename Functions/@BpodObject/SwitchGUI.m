%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2019 Sanworks LLC, Stony Brook, New York, USA

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
function obj = SwitchGUI(obj)

    if ~isfield(obj.GUIHandles, 'MainFig')

        obj.InitializeGUI();
        BpodSystem.ShowGUI = 1;

    else

        if obj.GUIHandles.MainFig.Visible == "on"

            set(obj.GUIHandles.MainFig, 'Visible', 'off');
            BpodSystem.ShowGUI = 0;

        else

            set(obj.GUIHandles.MainFig, 'Visible', 'on');
            BpodSystem.ShowGUI = 1;
    
        end

    end

end