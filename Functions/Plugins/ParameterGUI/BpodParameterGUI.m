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

function varargout = ParameterGUI(varargin)

% EnhancedParameterGUI('init', ParamStruct) - initializes a GUI with edit boxes for every field in subfield ParamStruct.GUI
% EnhancedParameterGUI('sync', ParamStruct) - updates the GUI with fields of
%       ParamStruct.GUI, if they have not been changed by the user. 
%       Returns a param struct. Fields in the GUI sub-struct are read from the UI.

% This version of ParameterGUI includes improvements 
% from EnhancedParameterGUI, contributed by F. Carnevale

global BpodSystem
Op = varargin{1};
Params = varargin{2};
Op = lower(Op);
switch Op
    case 'init'
        ParamNames = fieldnames(Params.GUI);
        nParams = length(ParamNames);
        BpodSystem.GUIData.ParameterGUI.ParamNames = cell(1,nParams);
        BpodSystem.GUIData.ParameterGUI.nParams = nParams;
        BpodSystem.GUIHandles.ParameterGUI.Labels = zeros(1,nParams);
        BpodSystem.GUIHandles.ParameterGUI.Params = zeros(1,nParams);
        BpodSystem.GUIData.ParameterGUI.LastParamValues = cell(1,nParams);
        if isfield(Params, 'GUIMeta')
            Meta = Params.GUIMeta;
        else
            Meta = struct;
        end
        if isfield(Params, 'GUIPanels')
            Panels = Params.GUIPanels;
            PanelNames = fieldnames(Panels);
            nPanels = length(PanelNames);
        else
            Panels = struct;
            Panels.Parameters = ParamNames;
            PanelNames = {'Parameters'};
            nPanels = 1;
        end
        Params = Params.GUI;
        PanelNames = PanelNames(end:-1:1);
        GUIHeight = 650;
        VPos = 10;
        HPos = 10;
        MaxVPos = 0;
        BpodSystem.ProtocolFigures.ParameterGUI = figure('Position', [50 50 450 GUIHeight],'name','Parameter GUI','numbertitle','off', 'MenuBar', 'none', 'Resize', 'on');
        ParamNum = 1;
        for p = 1:nPanels
            ThisPanelParamNames = Panels.(PanelNames{p});
            ThisPanelParamNames = ThisPanelParamNames(end:-1:1);
            nParams = length(ThisPanelParamNames);
            ThisPanelHeight = (45*nParams)+5;
            uipanel('title', PanelNames{p},'FontSize',12, 'FontWeight', 'Bold', 'BackgroundColor','white','Units','Pixels', 'Position',[HPos VPos 430 ThisPanelHeight]);
            InPanelPos = 10;
            for i = 1:nParams
                ThisParamName = ThisPanelParamNames{i};
                ThisParam = Params.(ThisParamName);
                BpodSystem.GUIData.ParameterGUI.ParamNames{ParamNum} = ThisParamName;
                if ischar(ThisParam)
                    BpodSystem.GUIData.ParameterGUI.LastParamValues{ParamNum} = NaN;
                else
                    BpodSystem.GUIData.ParameterGUI.LastParamValues{ParamNum} = ThisParam;
                end
                if isfield(Meta, ThisParamName)
                    if isstruct(Meta.(ThisParamName))
                        if isfield(Meta.(ThisParamName), 'Style')
                            ThisParamStyle = Meta.(ThisParamName).Style;
                            if isfield(Meta.(ThisParamName), 'String')
                                ThisParamString = Meta.(ThisParamName).String;
                            else
                                ThisParamString = '';
                            end
                        else
                            error(['Style not specified for parameter ' ThisParamName '.'])
                        end
                    else
                        error(['GUIMeta entry for ' ThisParamName ' must be a struct.'])
                    end
                else
                    ThisParamStyle = 'edit';
                    ThisParamValue = NaN;
                end
                BpodSystem.GUIHandles.ParameterGUI.Labels(ParamNum) = uicontrol('Style', 'text', 'String', ThisParamName, 'Position', [HPos+5 VPos+InPanelPos 200 25], 'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor','white', 'FontName', 'Arial','HorizontalAlignment','Center');
                switch lower(ThisParamStyle)
                    case 'edit'
                        BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 1;
                        BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = uicontrol('Style', 'edit', 'String', num2str(ThisParam), 'Position', [HPos+220 VPos+InPanelPos+2 200 25], 'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor','white', 'FontName', 'Arial','HorizontalAlignment','Center');
                    case 'text'
                        BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 2;
                        BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = uicontrol('Style', 'text', 'String', num2str(ThisParam), 'Position', [HPos+220 VPos+InPanelPos+2 200 25], 'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor','white', 'FontName', 'Arial','HorizontalAlignment','Center');
                    case 'checkbox'
                        BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 3;
                        BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = uicontrol('Style', 'checkbox', 'Value', ThisParam, 'String', '   (check to activate)', 'Position', [HPos+220 VPos+InPanelPos+4 200 25], 'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor','white', 'FontName', 'Arial','HorizontalAlignment','Center');
                    case 'popupmenu'
                        BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 4;
                        BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = uicontrol('Style', 'popupmenu', 'String', ThisParamString, 'Value', ThisParam, 'Position', [HPos+220 VPos+InPanelPos+2 200 25], 'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor','white', 'FontName', 'Arial','HorizontalAlignment','Center');
                    case 'pushbutton'
                        BpodSystem.GUIData.ParameterGUI.Styles(ParamNum) = 5;
                        BpodSystem.GUIHandles.ParameterGUI.Params(ParamNum) = uicontrol('Style', 'pushbutton', 'String', ThisParamName, 'Position', [HPos+220 VPos+InPanelPos+2 200 25], 'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor','white', 'FontName', 'Arial','HorizontalAlignment','Center', 'Callback', ThisParam);
                    otherwise
                        error('Invalid parameter style specified. Valid parameters are: ''edit'', ''text'', ''checkbox'', ''popupmenu'', ''button''');
                end
                InPanelPos = InPanelPos + 35;
                ParamNum = ParamNum + 1;
            end
            % Check next panel to see if it will fit, otherwise start new column
            Wrap = 0;
            if p < nPanels
                NextPanelParams = Panels.(PanelNames{p+1});
                NextPanelSize = (length(NextPanelParams)*45) + 5;
                if VPos + NextPanelSize > GUIHeight
                    Wrap = 1;
                end
            end
            VPos = VPos + ThisPanelHeight + 10;
            if Wrap
                HPos = HPos + 450;
                if VPos > MaxVPos
                    MaxVPos = VPos;
                end
                VPos = 10;
            else
                if VPos > MaxVPos
                    MaxVPos = VPos;
                end
            end
        end
        set(BpodSystem.ProtocolFigures.ParameterGUI, 'Position', [900 100 HPos+450 MaxVPos+10]);
    case 'sync'
        ParamNames = BpodSystem.GUIData.ParameterGUI.ParamNames;
        nParams = BpodSystem.GUIData.ParameterGUI.nParams;
        for p = 1:nParams
            ThisParamName = ParamNames{p};
            ThisParamStyle = BpodSystem.GUIData.ParameterGUI.Styles(p);
            ThisParamHandle = BpodSystem.GUIHandles.ParameterGUI.Params(p);
            ThisParamLastValue = BpodSystem.GUIData.ParameterGUI.LastParamValues{p};
            switch ThisParamStyle
                case 1 % Edit
                    GUIParam = str2double(get(ThisParamHandle, 'String'));
                    if GUIParam ~= ThisParamLastValue
                        Params.GUI.(ThisParamName) = GUIParam;
                    elseif Params.GUI.(ThisParamName) ~= ThisParamLastValue
                        set(ThisParamHandle, 'String', num2str(GUIParam));
                    end
                case 2 % Text
                    GUIParam = Params.GUI.(ThisParamName);
                    Text = GUIParam;
                    if ~ischar(Text)
                        Text = num2str(Text);
                    end
                    set(ThisParamHandle, 'String', Text);
                case 3 % Checkbox
                    GUIParam = get(ThisParamHandle, 'Value');
                    if GUIParam ~= ThisParamLastValue
                        Params.GUI.(ThisParamName) = GUIParam;
                    elseif Params.GUI.(ThisParamName) ~= ThisParamLastValue
                        set(ThisParamHandle, 'Value', GUIParam);
                    end
                case 4 % Popupmenu
                    GUIParam = get(ThisParamHandle, 'Value');
                    if GUIParam ~= ThisParamLastValue
                        Params.GUI.(ThisParamName) = GUIParam;
                    elseif Params.GUI.(ThisParamName) ~= ThisParamLastValue
                        set(ThisParamHandle, 'Value', GUIParam);
                    end
            end
            if ThisParamStyle ~= 5
                BpodSystem.GUIData.ParameterGUI.LastParamValues{p} = GUIParam;
            end
        end
    otherwise
    error('ParameterGUI must be called with a valid op code: ''init'' or ''sync''');
end
varargout{1} = Params;
