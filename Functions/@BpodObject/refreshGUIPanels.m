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

% BpodObject.refreshGUIPanels() is called by BpodObject.LoadModules() to
% update the console GUI tabs with the names of the connected modules

function obj = refreshGUIPanels(obj)
if obj.Status.BeingUsed == 0

    % Set default tab names
    moduleNames = {'<html>&nbsp;State<br>Machine', 'Serial 1', 'Serial 2', 'Serial 3', 'Serial 4', 'Serial 5'};

    % Format module names for display on tab buttons
    formattedModuleNames = moduleNames;
    nTabs = obj.HW.n.SerialChannels-obj.HW.n.USBChannels_External;
    obj.GUIData.DefaultPanel = ones(1,obj.HW.n.SerialChannels);
    for i = 2:nTabs
        if obj.Modules.Connected(i-1)
            thisModuleName = obj.Modules.Name{i-1};
            uCase = (thisModuleName > 64 & thisModuleName < 91);
            if sum(uCase) == 2 && length(uCase) > 5
                capPos = find(uCase);
                namePart1 = thisModuleName(1:capPos(2)-1);
                namePart2 = thisModuleName(capPos(2):end);
                bufferLength = 5-length(namePart2);
                if bufferLength < 1
                    bufferLength = 0;
                end
                buffer = ['<html>' repmat('&nbsp;', 1, bufferLength)];
                namePart2 = [buffer namePart2(1:end-1) ' ' namePart2(end)];
                formattedModuleNames{i} = ['<html>&nbsp;' namePart1 '<br>' namePart2];
            else
                thisModuleName = [thisModuleName(1:end-1) ' ' thisModuleName(end)];
                formattedModuleNames{i} = thisModuleName;
            end
        else
            thisModuleName = 'None';
        end

        % Update tab
        set(obj.GUIHandles.PanelButton(i), 'String', formattedModuleNames{i});

        % Clear panel contents
        set(obj.GUIHandles.OverridePanel(i), 'Visible', 'on');
        uistack(obj.GUIHandles.OverridePanel(i),'top');
        drawnow;
        axes(obj.GUIHandles.OverridePanelAxes(i)); % Make correct panel axes the current axes
        panelChildren = get(obj.GUIHandles.OverridePanel(i), 'Children');
        nChildren = length(panelChildren);
        for j = 1:nChildren
            deleteIt = 1;
            ud = get(panelChildren(j), 'UserData');
            if ischar(ud)
                if strcmp(ud, 'PrimaryPanelAxes')
                    deleteIt = 0;
                    axisChildren = get(panelChildren(j), 'Children');
                    nAxisChildren = length(axisChildren);
                    for k = 1:nAxisChildren
                        delete(axisChildren(k));
                    end
                end
            end
            if deleteIt
                delete(panelChildren(j));
            end
        end

        % Find module panel function and draw panel, otherwise draw default panel
        if ~strcmp(thisModuleName, 'None')
            moduleTypeString = thisModuleName(1:end-1);
            moduleFileName = [moduleTypeString '_Panel.m'];
            if exist(moduleFileName, 'file')
                moduleFunctionName = [moduleTypeString '_Panel'];
                eval([moduleFunctionName '(obj.GUIHandles.OverridePanel(' num2str(i) '), ''' thisModuleName ''');']);
                obj.GUIData.DefaultPanel(i) = 0;
            else % No override panel function exists for module
                DefaultBpodModule_Panel(obj.GUIHandles.OverridePanel(i), obj.Modules.Name{i-1});
            end

        else % Module did not respond
            DefaultBpodModule_Panel(obj.GUIHandles.OverridePanel(i), obj.Modules.Name{i-1});
        end
        set(obj.GUIHandles.OverridePanel(i), 'Visible', 'off');
    end

    for i = 2:nTabs
        set(obj.GUIHandles.PanelButton(i), 'BackgroundColor', [0.37 0.37 0.37]);
    end

    % Final formatting tasks
    set (obj.GUIHandles.PanelButton(1), 'BackgroundColor', [0.45 0.45 0.45]); % Set first button active
    set(obj.GUIHandles.OverridePanel(1), 'Visible', 'on');
    uistack(obj.GUIHandles.OverridePanel(1),'top');
    axes(obj.GUIHandles.Console);
    uistack(obj.GUIHandles.Console,'bottom');

    % Clear button borders
    if isempty(strfind(obj.HostOS, 'Linux')) && ~verLessThan('matlab', '8.0.0') && verLessThan('matlab', '9.5.0')
        for i = 1:nTabs
            jButton = findjobj(obj.GUIHandles.PanelButton(i));
            jButton.setBorderPainted(false);
        end
    end
end
end