%{
----------------------------------------------------------------------------

This file is part of the Bpod Project
Copyright (C) 2014 Joshua I. Sanders, Cold Spring Harbor Laboratory, NY, USA

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

function varargout = BpodParameterGUI(varargin)

% EnhancedBpodParameterGUI('init', ParamStruct) - initializes a GUI with edit boxes for every field in subfield ParamStruct.GUI
% EnhancedBpodParameterGUI('sync', ParamStruct) - updates the GUI with fields of
%       ParamStruct.GUI, if they have not been changed by the user. 
%       Returns a param struct. Fields in the GUI sub-struct are read from the UI.

% EnhancedBpodParameterGUI is based on BpodParameterGUI
% Written by F. Carnevale 02/16/2015

global BpodSystem
Op = varargin{1};
Params = varargin{2};
Op = lower(Op);
switch Op
    case 'addparam'
        GUI = varargin{2};
        ParamName = varargin{3};
        ParamType = varargin{4};
        String = varargin{5};
        if sum(strcmpi(ParamType, {'checkbox', 'popupmenu'}))
            Value = varargin{6};
            Panel = varargin{7};
        else
            Value = NaN;
            Panel = varargin{6};
        end
        GUI.(ParamName).string = String;
        GUI.(ParamName).value = Value;
        GUI.(ParamName).style = ParamType;
        GUI.(ParamName).panel = Panel;
        varargout{1} = GUI;
    case 'init'
        Params = Params.GUI;
        ParamNames = fieldnames(Params);
        nValues = length(ParamNames);
        ParamStyle = cell(1,nValues);
        ParamString = cell(1,nValues);
        ParamValues = cell(1,nValues);
        ParamPanel = cell(1,nValues);
        for x = 1:nValues
            ParamPanel{1,x} = Params.(ParamNames{x}).panel;
            ParamStyle{1,x} = Params.(ParamNames{x}).style;
            switch Params.(ParamNames{x}).style
                case 'text'
                    ParamString{1,x} = Params.(ParamNames{x}).string;
                    %ParamValues{1,x} = Params.(ParamNames{x}).string;
                    ParamValues{1,x} = 0;
                case 'edit'
                    ParamString{1,x} = Params.(ParamNames{x}).string;
                    ParamValues{1,x} = Params.(ParamNames{x}).string;
                    %ParamValues{1,x} = 0;
                case 'popupmenu'
                    ParamString{1,x} = Params.(ParamNames{x}).string;
                    ParamValues{1,x} = Params.(ParamNames{x}).value;
                case 'checkbox'
                    ParamString{1,x} = Params.(ParamNames{x}).string;
                    ParamValues{1,x} = Params.(ParamNames{x}).value;
            end
        end
        
        uniqueParamPanel = unique(ParamPanel);
        nPanels = length(unique(ParamPanel));
        
        Vsize = 20+(30*nValues)+70*(nPanels+1)+20+160;
        
        Width = 400;
        
        screensize = get(groot, 'Screensize');
        nColumns = ceil(Vsize/screensize(4));
        if nColumns>1
            Vsize = screensize(4)-100;            
        end
        
        
        BpodSystem.ProtocolFigures.BpodParameterGUI = figure('Position', [50 50 nColumns*Width+20 Vsize],'name',BpodSystem.CurrentProtocolName,'numbertitle','off', 'MenuBar', 'none', 'Resize', 'on');
        
        BpodSystem.GUIHandles.ParameterGUI = struct;
        BpodSystem.GUIHandles.ParameterGUI.ParamNames = ParamNames;
        BpodSystem.GUIHandles.ParameterGUI.LastParamValues = ParamValues;
        BpodSystem.GUIHandles.ParameterGUI.Labels = zeros(1,nValues);
        
        %BpodSystem.GUIHandles.ParameterGUI.SyncWithServer = uicontrol('Style', 'pushbutton', 'String', 'Sync with Server', 'Position', [30 Vsize-160 Width-50 60], 'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor','white', 'FontName', 'Arial','Callback', @SyncWithServer);

        column = 1;
        panel_y = Vsize-180;
        Pos = panel_y-70;
        for i=1:nPanels
                        
            % Elements in this panel
            indx_in_panel = find(strcmp(ParamPanel,uniqueParamPanel{i}));
            n_indx_in_panel = length(indx_in_panel);
            
            if panel_y-30*(n_indx_in_panel+2)<0
                column = column +1;
                panel_y = Vsize-100;
                Pos = panel_y-70;
            end
            
            panel(i) = uipanel('title', uniqueParamPanel{i},'FontSize',12, 'BackgroundColor','white','Units','Pixels', 'Position',[10+(column-1)*(Width+5) panel_y-30*(n_indx_in_panel+2) Width 30*(n_indx_in_panel+2)]);
            
            
            for j=1:length(indx_in_panel)
                
                x = indx_in_panel(j);
                BpodSystem.GUIHandles.ParameterGUI.Labels(x) = uicontrol('Style', 'text', 'String', ParamNames{x}, 'Position', [11+(column-1)*(Width+5) Pos 2/3*(Width) 25], 'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor','white', 'FontName', 'Arial','HorizontalAlignment','Center');
                BpodSystem.GUIHandles.ParameterGUI.ParamValues(x) = uicontrol('Style', ParamStyle{1,x}, 'String', ParamString{x},'Value',ParamValues{1,x}, 'Position', [(column-1)*(Width+5)+Width-(.4*Width) Pos+5 .35*Width 25], 'FontWeight', 'normal', 'FontSize', 12, 'FontName', 'Arial');
                
                Pos = Pos - 30;
            end            
            Pos = Pos - 70;
            panel_y = panel_y - 30*(n_indx_in_panel+2.5);
        end
        

    case 'sync'
        ParamNames = fieldnames(Params.GUI);
        nValues = length(BpodSystem.GUIHandles.ParameterGUI.LastParamValues);
        for x = 1:nValues            
            switch Params.GUI.(ParamNames{x}).style
                case 'text'
                    % text can only be changed from code
                    thisParamInputValue = Params.GUI.(ParamNames{x}).string;
                    set(BpodSystem.GUIHandles.ParameterGUI.ParamValues(x), 'String', thisParamInputValue);
                    thisParamGUIValue = thisParamInputValue;
                    Params.GUI.(BpodSystem.GUIHandles.ParameterGUI.ParamNames{x}).string = thisParamGUIValue;
                case 'edit'
                    thisParamGUIValue = str2double(get(BpodSystem.GUIHandles.ParameterGUI.ParamValues(x), 'String'));
                    thisParamLastValue = BpodSystem.GUIHandles.ParameterGUI.LastParamValues{x};
                    thisParamInputValue = Params.GUI.(ParamNames{x}).string;
                    if thisParamGUIValue == thisParamLastValue % If the user didn't change the GUI, the GUI can be changed from the input.
                        set(BpodSystem.GUIHandles.ParameterGUI.ParamValues(x), 'String', sprintf('%g',thisParamInputValue));
                        thisParamGUIValue = thisParamInputValue;
                    end
                    Params.GUI.(BpodSystem.GUIHandles.ParameterGUI.ParamNames{x}).string = thisParamGUIValue;
                case 'popupmenu'
                    thisParamGUIValue = get(BpodSystem.GUIHandles.ParameterGUI.ParamValues(x),'Value');
                    thisParamLastValue = BpodSystem.GUIHandles.ParameterGUI.LastParamValues{x};
                    thisParamInputValue = Params.GUI.(ParamNames{x}).value;
                    if thisParamGUIValue == thisParamLastValue % If the user didn't change the GUI, the GUI can be changed from the input.
                        set(BpodSystem.GUIHandles.ParameterGUI.ParamValues(x), 'Value', thisParamInputValue);
                        thisParamGUIValue = thisParamInputValue;
                    end
                    Params.GUI.(BpodSystem.GUIHandles.ParameterGUI.ParamNames{x}).value = thisParamGUIValue;
                case 'checkbox'
                    thisParamGUIValue = get(BpodSystem.GUIHandles.ParameterGUI.ParamValues(x),'Value');
                    thisParamLastValue = BpodSystem.GUIHandles.ParameterGUI.LastParamValues{x};
                    thisParamInputValue = Params.GUI.(ParamNames{x}).value;
                    if thisParamGUIValue == thisParamLastValue % If the user didn't change the GUI, the GUI can be changed from the input.
                        set(BpodSystem.GUIHandles.ParameterGUI.ParamValues(x), 'Value', thisParamInputValue);
                        thisParamGUIValue = thisParamInputValue;
                    end
                    Params.GUI.(BpodSystem.GUIHandles.ParameterGUI.ParamNames{x}).value = thisParamGUIValue;
            end

            if isfield(Params.GUI.(ParamNames{x}),'enable')
                set(BpodSystem.GUIHandles.ParameterGUI.ParamValues(x),'Enable', Params.GUI.(ParamNames{x}).enable);
            end
            
            BpodSystem.GUIHandles.ParameterGUI.LastParamValues{x} = thisParamGUIValue;
        end
    varargout{1} = Params;
end