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

% BpodParameterGUI() launches a GUI for direct interaction with task
% parameters in a parameter struct. All parameters contained in the subfield 'GUI'
% are displayed. Optional subfield 'GUIMeta' indicates the type of UIcontrol for
% parameters in GUI. Optional subfield 'GUIPanels' indicates which UIpanel
% to assign each parameter to. 

% Usage examples:
% BpodParameterGUI('init', paramStruct) - initializes a GUI with edit boxes for every field 
%                                         in subfield paramStruct.GUI
% BpodParameterGUI('sync', paramStruct) - updates the GUI with fields of ParamStruct.GUI, 
%                                         if they have not been changed by the user. 

% This version of BpodParameterGUI includes improvements 
% from EnhancedParameterGUI, contributed by F. Carnevale

function paramStructOut = BpodParameterGUI(op, paramStructIn)

global BpodSystem % Import the global BpodSystem object

op = lower(op);
switch op
    case 'init'
        paramNames = fieldnames(paramStructIn.GUI);
        nParams = length(paramNames);
        BpodSystem.GUIData.ParameterGUI.ParamNames = cell(1,nParams);
        BpodSystem.GUIData.ParameterGUI.nParams = nParams;
        BpodSystem.GUIHandles.ParameterGUI.Labels = zeros(1,nParams);
        BpodSystem.GUIHandles.ParameterGUI.Params = zeros(1,nParams);
        BpodSystem.GUIData.ParameterGUI.LastParamValues = cell(1,nParams);
        if isfield(paramStructIn, 'GUIMeta')
            meta = paramStructIn.GUIMeta;
        else
            meta = struct;
        end
        if isfield(paramStructIn, 'GUIPanels')
            panels = paramStructIn.GUIPanels;
            panelNames = fieldnames(panels);
            nPanels = length(panelNames);
            paramNames = fieldnames(paramStructIn.GUI);
            nParameters = length(paramNames);

            % Find any params not assigned a panel and assign to new 'Parameters' panel
            paramsInPanels = {}; 
            for i = 1:nPanels
                paramsInPanels = [paramsInPanels panels.(panelNames{i})];
            end
            paramsInDefaultPanel = {};
            
            for i = 1:nParameters
                if ~strcmp(paramNames{i}, paramsInPanels)
                    paramsInDefaultPanel = [paramsInDefaultPanel paramNames{i}];
                end
            end
            if ~isempty(paramsInDefaultPanel)
                panels.Parameters = cell(1,length(paramsInDefaultPanel));
                for i = 1:length(paramsInDefaultPanel)
                    panels.Parameters{i} = paramsInDefaultPanel{i};
                end
                panelNames{nPanels+1} = 'Parameters';
            end
            nPanels = length(panelNames);
        else
            panels = struct;
            panels.Parameters = paramNames;
            panelNames = {'Parameters'};
            nPanels = 1;
        end
        paramStructIn = paramStructIn.GUI;
        panelNames = panelNames(end:-1:1);
        guiHeight = 650;
        vPos = 10;
        hPos = 10;
        maxVPos = 0;
        BpodSystem.ProtocolFigures.ParameterGUI = figure('Position', [50 50 450 guiHeight],'name', 'Parameter GUI',...
            'numbertitle', 'off', 'MenuBar', 'none', 'Resize', 'on');
        paramNum = 1;
        for p = 1:nPanels
            thisPanelParamNames = panels.(panelNames{p});
            thisPanelParamNames = thisPanelParamNames(end:-1:1);
            nParams = length(thisPanelParamNames);
            thisPanelHeight = (40*nParams)+15;
            uipanel('title', panelNames{p},'FontSize',12, 'FontWeight', 'Bold', 'BackgroundColor', 'white',...
                'Units', 'Pixels', 'Position',[hPos vPos 430 thisPanelHeight]);
            inPanelPos = 10;
            for i = 1:nParams
                thisParamName = thisPanelParamNames{i};
                thisParam = paramStructIn.(thisParamName);
                BpodSystem.GUIData.ParameterGUI.ParamNames{paramNum} = thisParamName;
                if ischar(thisParam)
                    BpodSystem.GUIData.ParameterGUI.LastParamValues{paramNum} = NaN;
                else
                    BpodSystem.GUIData.ParameterGUI.LastParamValues{paramNum} = thisParam;
                end
                if isfield(meta, thisParamName)
                    if isstruct(meta.(thisParamName))
                        if isfield(meta.(thisParamName), 'Style')
                            thisParamStyle = meta.(thisParamName).Style;
                            if isfield(meta.(thisParamName), 'String')
                                thisParamString = meta.(thisParamName).String;
                            else
                                thisParamString = '';
                            end
                        else
                            error(['Style not specified for parameter ' thisParamName '.'])
                        end
                    else
                        error(['GUIMeta entry for ' thisParamName ' must be a struct.'])
                    end
                else
                    thisParamStyle = 'edit';
                    thisParamValue = NaN;
                end
                BpodSystem.GUIHandles.ParameterGUI.Labels(paramNum) = uicontrol('Style', 'text', 'String', thisParamName,... 
                    'Position', [hPos+5 vPos+inPanelPos 200 25], 'FontWeight', 'normal', 'FontSize', 12,... 
                    'BackgroundColor','white', 'FontName', 'Arial','HorizontalAlignment','Center');
                switch lower(thisParamStyle)
                    case 'edit'
                        BpodSystem.GUIData.ParameterGUI.Styles(paramNum) = 1;
                        BpodSystem.GUIHandles.ParameterGUI.Params(paramNum) = uicontrol('Style', 'edit',... 
                            'String', num2str(thisParam), 'Position', [hPos+220 vPos+inPanelPos+2 200 25],... 
                            'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor','white', 'FontName',... 
                            'Arial','HorizontalAlignment','Center');
                    case 'text'
                        BpodSystem.GUIData.ParameterGUI.Styles(paramNum) = 2;
                        BpodSystem.GUIHandles.ParameterGUI.Params(paramNum) = uicontrol('Style', 'text',... 
                            'String', num2str(thisParam), 'Position', [hPos+220 vPos+inPanelPos+2 200 25],... 
                            'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor','white', 'FontName', 'Arial',...
                            'HorizontalAlignment','Center');
                    case 'checkbox'
                        BpodSystem.GUIData.ParameterGUI.Styles(paramNum) = 3;
                        BpodSystem.GUIHandles.ParameterGUI.Params(paramNum) = uicontrol('Style', 'checkbox',... 
                            'Value', thisParam, 'String', '   (check to activate)', 'Position', [hPos+220 vPos+inPanelPos+4 200 25],... 
                            'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor','white', 'FontName', 'Arial',...
                            'HorizontalAlignment','Center');
                    case 'popupmenu'
                        BpodSystem.GUIData.ParameterGUI.Styles(paramNum) = 4;
                        BpodSystem.GUIHandles.ParameterGUI.Params(paramNum) = uicontrol('Style', 'popupmenu',... 
                            'String', thisParamString, 'Value', thisParam, 'Position', [hPos+220 vPos+inPanelPos+2 200 25],... 
                            'FontWeight', 'normal', 'FontSize', 12, 'BackgroundColor','white', 'FontName', 'Arial',...
                            'HorizontalAlignment','Center');
                    case 'pushbutton'
                        BpodSystem.GUIData.ParameterGUI.Styles(paramNum) = 5;
                        BpodSystem.GUIHandles.ParameterGUI.Params(paramNum) = uicontrol('Style', 'pushbutton',... 
                            'String', thisParamName, 'Position', [hPos+220 vPos+inPanelPos+2 200 25], 'FontWeight', 'normal',... 
                            'FontSize', 12, 'BackgroundColor','white', 'FontName', 'Arial','HorizontalAlignment','Center',... 
                            'Callback', thisParam);
                    otherwise
                        error(['Invalid parameter style specified.' ...
                               'Valid parameters are: ''edit'', ''text'', ''checkbox'', ''popupmenu'', ''button''']);
                end
                inPanelPos = inPanelPos + 35;
                paramNum = paramNum + 1;
            end
            % Check next panel to see if it will fit, otherwise start new column
            wrap = 0;
            if p < nPanels
                nextPanelParams = panels.(panelNames{p+1});
                nextPanelSize = (length(nextPanelParams)*45) + 5;
                if vPos + nextPanelSize > guiHeight
                    wrap = 1;
                end
            end
            vPos = vPos + thisPanelHeight + 10;
            if wrap
                hPos = hPos + 450;
                if vPos > maxVPos
                    maxVPos = vPos;
                end
                vPos = 10;
            else
                if vPos > maxVPos
                    maxVPos = vPos;
                end
            end
        end
        set(BpodSystem.ProtocolFigures.ParameterGUI, 'Position', [900 100 hPos+450 maxVPos+10]);
    case 'sync'
        paramNames = BpodSystem.GUIData.ParameterGUI.ParamNames;
        nParams = BpodSystem.GUIData.ParameterGUI.nParams;
        for p = 1:nParams
            thisParamName = paramNames{p};
            thisParamStyle = BpodSystem.GUIData.ParameterGUI.Styles(p);
            thisParamHandle = BpodSystem.GUIHandles.ParameterGUI.Params(p);
            thisParamLastValue = BpodSystem.GUIData.ParameterGUI.LastParamValues{p};
            thisParamCurrentValue = paramStructIn.GUI.(thisParamName); % Use single precision to avoid problems with ==
            switch thisParamStyle
                case 1 % Edit
                    guiParam = str2double(get(thisParamHandle, 'String'));
                    if single(guiParam) ~= single(thisParamLastValue)
                        paramStructIn.GUI.(thisParamName) = guiParam;
                    elseif single(thisParamCurrentValue) ~= single(thisParamLastValue)
                        set(thisParamHandle, 'String', num2str(thisParamCurrentValue, 8));
                    end
                case 2 % Text
                    guiParam = thisParamCurrentValue;
                    text = guiParam;
                    if ~ischar(text)
                        text = num2str(text);
                    end
                    set(thisParamHandle, 'String', text);
                case 3 % Checkbox
                    guiParam = get(thisParamHandle, 'Value');
                    if guiParam ~= thisParamLastValue
                        paramStructIn.GUI.(thisParamName) = guiParam;
                    elseif thisParamCurrentValue ~= thisParamLastValue
                        set(thisParamHandle, 'Value', thisParamCurrentValue);
                    end
                case 4 % Popupmenu
                    guiParam = get(thisParamHandle, 'Value');
                    if guiParam ~= thisParamLastValue
                        paramStructIn.GUI.(thisParamName) = guiParam;
                    elseif thisParamCurrentValue ~= thisParamLastValue
                        set(thisParamHandle, 'Value', thisParamCurrentValue);
                    end
            end
            if thisParamStyle ~= 5
                BpodSystem.GUIData.ParameterGUI.LastParamValues{p} = paramStructIn.GUI.(thisParamName);
            end
        end
    otherwise
    error('ParameterGUI must be called with a valid op code: ''init'' or ''sync''');
end
if verLessThan('MATLAB', '8.4')
    drawnow;
end
paramStructOut = paramStructIn;
