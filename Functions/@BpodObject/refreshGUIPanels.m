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
function obj = refreshGUIPanels(obj)
    if obj.Status.BeingUsed == 0
        ModuleNames = {'<html>&nbsp;State<br>Machine', 'Serial 1', 'Serial 2', 'Serial 3', 'Serial 4', 'Serial 5'};
        FormattedModuleNames = ModuleNames;
        nTabs = obj.HW.n.SerialChannels-obj.HW.n.USBChannels_External;
        obj.GUIData.DefaultPanel = ones(1,obj.HW.n.SerialChannels);
        for i = 2:nTabs
            if obj.Modules.Connected(i-1)
                ThisModuleName = obj.Modules.Name{i-1};
                UCase = (ThisModuleName > 64 & ThisModuleName < 91);
                if sum(UCase) == 2 && length(UCase) > 5
                    CapPos = find(UCase);
                    NamePart1 = ThisModuleName(1:CapPos(2)-1);
                    NamePart2 = ThisModuleName(CapPos(2):end);
                    BufferLength = 5-length(NamePart2);
                    if BufferLength < 1
                        BufferLength = 0;
                    end
                    Buffer = ['<html>' repmat('&nbsp;', 1, BufferLength)];
                    NamePart2 = [Buffer NamePart2(1:end-1) ' ' NamePart2(end)];
                    FormattedModuleNames{i} = ['<html>&nbsp;' NamePart1 '<br>' NamePart2];
                else
                    ThisModuleName = [ThisModuleName(1:end-1) ' ' ThisModuleName(end)];
                    FormattedModuleNames{i} = ThisModuleName;
                end
            else
                ThisModuleName = 'None';
            end
            % Update tab
            set(obj.GUIHandles.PanelButton(i), 'String', FormattedModuleNames{i});
            % Clear panel contents
            set(obj.GUIHandles.OverridePanel(i), 'Visible', 'on');
            uistack(obj.GUIHandles.OverridePanel(i),'top');
            axes(obj.GUIHandles.OverridePanelAxes(i)); % Make correct panel axes the current axes
            PanelChildren = get(obj.GUIHandles.OverridePanel(i), 'Children');
            nChildren = length(PanelChildren);
            for j = 1:nChildren
                DeleteIt = 1;
                UD = get(PanelChildren(j), 'UserData');
                if ischar(UD)
                    if strcmp(UD, 'PrimaryPanelAxes')
                        DeleteIt = 0;
                        AxisChildren = get(PanelChildren(j), 'Children');
                        nAxisChildren = length(AxisChildren);
                        for k = 1:nAxisChildren
                            delete(AxisChildren(k));
                        end
                    end
                end
                if DeleteIt
                    delete(PanelChildren(j));
                end
            end
            % Find module panel function and draw panel, otherwise draw default panel
            if ~strcmp(ThisModuleName, 'None')
                ModuleTypeString = ThisModuleName(1:end-1);
                ModuleFileName = [ModuleTypeString '_Panel.m'];
                if exist(ModuleFileName, 'file')
                    ModuleFunctionName = [ModuleTypeString '_Panel'];
                    eval([ModuleFunctionName '(obj.GUIHandles.OverridePanel(' num2str(i) '), ''' ThisModuleName ''');']);
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
        set (obj.GUIHandles.PanelButton(1), 'BackgroundColor', [0.45 0.45 0.45]); % Set first button active
        set(obj.GUIHandles.OverridePanel(1), 'Visible', 'on');
        uistack(obj.GUIHandles.OverridePanel(1),'top');
        axes(obj.GUIHandles.Console);
        uistack(obj.GUIHandles.Console,'bottom');
        if isempty(strfind(obj.HostOS, 'Linux')) && ~verLessThan('matlab', '8.0.0') && verLessThan('matlab', '9.5.0')
            for i = 1:nTabs
                jButton = findjobj(obj.GUIHandles.PanelButton(i));
                jButton.setBorderPainted(false);
            end
        end
    end
end