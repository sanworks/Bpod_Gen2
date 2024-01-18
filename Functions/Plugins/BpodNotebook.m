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

% BpodNotebook() displays a "notebook" for taking notes on individual trials, 
% or marking them digitally for classification based on manual criteria.
% Data entered into the notebook is saved with the Bpod session dataset.
%
% Arguments:
% op: The operation. This must be one of:
%                    'init' to initialize the plugin
%                    'sync' to update sessionData
% sessionData: A Bpod session data struct
%
% Returns:
% sessionData, the session data struct with added notes

function sessionData = BpodNotebook(op, varargin)

global BpodSystem % Import the global BpodSystem object

op = lower(op);
switch op
    case 'init'
        % Initialize BpodSystem.GUIHandles.Notebook structure
        BpodSystem.GUIHandles.Notebook = struct();
        BpodSystem.GUIData.Notebook = struct();
        BpodSystem.GUIData.Notebook.Notes = cell(1);
        BpodSystem.GUIData.Notebook.MarkerCodes = zeros(1);
        % Creation of all uicontrols
        
        % --- FIGURE -------------------------------------
        BpodSystem.ProtocolFigures.Notebook = figure( ...
            'Tag', 'figure1', ...
            'Units', 'characters', ...
            'Position', [179 10 49.8 32.2307692307692], ...
            'Name', 'BpodNotebook', ...
            'MenuBar', 'none', ...
            'NumberTitle', 'off', ...
            'Color', get(0,'DefaultUicontrolBackgroundColor'));
        
        % --- STATIC TEXTS -------------------------------------
        BpodSystem.GUIHandles.Notebook.text1 = uicontrol( ...
            'Parent', BpodSystem.ProtocolFigures.Notebook, ...
            'Tag', 'text1', ...
            'Style', 'text', ...
            'Units', 'characters', ...
            'Position', [5.80000000000001 8.53846153846156 25 2.15384615384615], ...
            'FontSize', 12, ...
            'FontWeight', 'bold', ...
            'String', 'Editing trial#');
        
        % --- PUSHBUTTONS -------------------------------------
        BpodSystem.GUIHandles.Notebook.pushbutton3 = uicontrol( ...
            'Parent', BpodSystem.ProtocolFigures.Notebook, ...
            'Tag', 'pushbutton3', ...
            'Style', 'pushbutton', ...
            'Units', 'characters', ...
            'Position', [10.6 0.846153846153855 4.8 2.53846153846154], ...
            'FontSize', 14, ...
            'String', '<', ...
            'Callback', @pushbutton3_Callback);
        
        BpodSystem.GUIHandles.Notebook.pushbutton4 = uicontrol( ...
            'Parent', BpodSystem.ProtocolFigures.Notebook, ...
            'Tag', 'pushbutton4', ...
            'Style', 'pushbutton', ...
            'Units', 'characters', ...
            'Position', [34.0000000000001 1.00000000000001 4.8 2.53846153846154], ...
            'FontSize', 14, ...
            'String', '>', ...
            'Callback', @pushbutton4_Callback);
        
        BpodSystem.GUIHandles.Notebook.pushbutton5 = uicontrol( ...
            'Parent', BpodSystem.ProtocolFigures.Notebook, ...
            'Tag', 'pushbutton5', ...
            'Style', 'pushbutton', ...
            'Units', 'characters', ...
            'Position', [41.0000000000001 1.00000000000001 7 2.53846153846154], ...
            'FontSize', 14, ...
            'String', '>>', ...
            'Callback', @pushbutton5_Callback);
        
        BpodSystem.GUIHandles.Notebook.pushbutton6 = uicontrol( ...
            'Parent', BpodSystem.ProtocolFigures.Notebook, ...
            'Tag', 'pushbutton6', ...
            'Style', 'pushbutton', ...
            'Units', 'characters', ...
            'Position', [1.4 0.846153846153855 7 2.53846153846154], ...
            'FontSize', 14, ...
            'String', '<<', ...
            'Callback', @pushbutton6_Callback);
        
        % --- CHECKBOXES -------------------------------------
        BpodSystem.GUIHandles.Notebook.checkbox1 = uicontrol( ...
            'Parent', BpodSystem.ProtocolFigures.Notebook, ...
            'Tag', 'checkbox1', ...
            'Style', 'checkbox', ...
            'Units', 'characters', ...
            'Position', [12.6000000000001 6.69230769230771 25.8 1.76923076923077], ...
            'String', 'Mark trial with code:', ...
            'Callback', @checkbox1_Callback);
        
        % --- EDIT TEXTS -------------------------------------
        BpodSystem.GUIHandles.Notebook.edit2 = uicontrol( ...
            'Parent', BpodSystem.ProtocolFigures.Notebook, ...
            'Tag', 'edit2', ...
            'Style', 'edit', ...
            'Units', 'characters', ...
            'Position', [31.4000000000001 8.76923076923079 10.2 2.46153846153846], ...
            'FontSize', 14, ...
            'BackgroundColor', [1 1 1], ...
            'String', '1', ...
            'Callback', @edit2_Callback);
        
        BpodSystem.GUIHandles.Notebook.edit1 = uicontrol( ...
            'Parent', BpodSystem.ProtocolFigures.Notebook, ...
            'Tag', 'edit1', ...
            'Style', 'edit', ...
            'Units', 'characters', ...
            'Position', [2 12.1538461538462 45.4 18.6153846153846], ...
            'FontSize', 14, ...
            'BackgroundColor', [1 1 1], ...
            'String', '', ...
            'HorizontalAlignment', 'left', ...
            'Max', 100, ...
            'Callback', @edit1_Callback);
        
        % --- POPUP MENU -------------------------------------
        BpodSystem.GUIHandles.Notebook.popupmenu1 = uicontrol( ...
            'Parent', BpodSystem.ProtocolFigures.Notebook, ...
            'Tag', 'popupmenu1', ...
            'Style', 'popupmenu', ...
            'Units', 'characters', ...
            'Position', [11.0000000000001 4.23076923076925 27.4 2.07692307692308], ...
            'FontSize', 12, ...
            'BackgroundColor', [1 1 1], ...
            'String', {'1','2','3','4','5','6','7','8','9','10'}, ...
            'Callback', @popupmenu1_Callback);
        sessionData = 0;
    case 'sync'
        sessionData = varargin{1};
        nTrials = sessionData.nTrials+1;
        nTrialsLogged = length(BpodSystem.GUIData.Notebook.Notes);
        if nTrials > nTrialsLogged
            BpodSystem.GUIData.Notebook.Notes(nTrialsLogged+1:nTrials) = cell(1,nTrials-nTrialsLogged);
            BpodSystem.GUIData.Notebook.MarkerCodes(nTrialsLogged+1:nTrials) = zeros(1,nTrials-nTrialsLogged);
        end
        sessionData.Notes = BpodSystem.GUIData.Notebook.Notes;
        sessionData.MarkerCodes = BpodSystem.GUIData.Notebook.MarkerCodes;
end
end

%% ---------------------------------------------------------------------------
function pushbutton3_Callback(~,~)
global BpodSystem
currentTrialViewing = str2double(get(BpodSystem.GUIHandles.Notebook.edit2, 'String'));
if currentTrialViewing > 1
    currentTrialViewing = currentTrialViewing - 1;
end
set(BpodSystem.GUIHandles.Notebook.edit1, 'String', BpodSystem.GUIData.Notebook.Notes{currentTrialViewing});
set(BpodSystem.GUIHandles.Notebook.edit2, 'String', num2str(currentTrialViewing));
set(BpodSystem.GUIHandles.Notebook.checkbox1, 'Value', BpodSystem.GUIData.Notebook.MarkerCodes(currentTrialViewing) > 0)
if BpodSystem.GUIData.Notebook.MarkerCodes(currentTrialViewing) > 0
    set(BpodSystem.GUIHandles.Notebook.popupmenu1, 'Value', BpodSystem.GUIData.Notebook.MarkerCodes(currentTrialViewing))
else
    set(BpodSystem.GUIHandles.Notebook.popupmenu1, 'Value', 1)
end
drawnow;
end

%% ---------------------------------------------------------------------------
function pushbutton4_Callback(~,~)
global BpodSystem
currentTrialViewing = str2double(get(BpodSystem.GUIHandles.Notebook.edit2, 'String'));
maxTrials = length(BpodSystem.GUIData.Notebook.Notes);
if currentTrialViewing < maxTrials
    currentTrialViewing = currentTrialViewing + 1;
end
set(BpodSystem.GUIHandles.Notebook.edit1, 'String', BpodSystem.GUIData.Notebook.Notes{currentTrialViewing});
set(BpodSystem.GUIHandles.Notebook.edit2, 'String', num2str(currentTrialViewing));
set(BpodSystem.GUIHandles.Notebook.checkbox1, 'Value', BpodSystem.GUIData.Notebook.MarkerCodes(currentTrialViewing) > 0)
if BpodSystem.GUIData.Notebook.MarkerCodes(currentTrialViewing) > 0
    set(BpodSystem.GUIHandles.Notebook.popupmenu1, 'Value', BpodSystem.GUIData.Notebook.MarkerCodes(currentTrialViewing))
else
    set(BpodSystem.GUIHandles.Notebook.popupmenu1, 'Value', 1)
end
drawnow;
end

%% ---------------------------------------------------------------------------
function pushbutton5_Callback(~,~)
global BpodSystem
currentTrialViewing = length(BpodSystem.GUIData.Notebook.Notes);
set(BpodSystem.GUIHandles.Notebook.edit1, 'String', BpodSystem.GUIData.Notebook.Notes{currentTrialViewing});
set(BpodSystem.GUIHandles.Notebook.edit2, 'String', num2str(currentTrialViewing));
set(BpodSystem.GUIHandles.Notebook.checkbox1, 'Value', BpodSystem.GUIData.Notebook.MarkerCodes(currentTrialViewing) > 0)
if BpodSystem.GUIData.Notebook.MarkerCodes(currentTrialViewing) > 0
    set(BpodSystem.GUIHandles.Notebook.popupmenu1, 'Value', BpodSystem.GUIData.Notebook.MarkerCodes(currentTrialViewing))
else
    set(BpodSystem.GUIHandles.Notebook.popupmenu1, 'Value', 1)
end
drawnow;
end

%% ---------------------------------------------------------------------------
function pushbutton6_Callback(~,~)
global BpodSystem
currentTrialViewing = 1;
set(BpodSystem.GUIHandles.Notebook.edit1, 'String', BpodSystem.GUIData.Notebook.Notes{currentTrialViewing});
set(BpodSystem.GUIHandles.Notebook.edit2, 'String', num2str(currentTrialViewing));
set(BpodSystem.GUIHandles.Notebook.checkbox1, 'Value', BpodSystem.GUIData.Notebook.MarkerCodes(currentTrialViewing) > 0)
if BpodSystem.GUIData.Notebook.MarkerCodes(currentTrialViewing) > 0
    set(BpodSystem.GUIHandles.Notebook.popupmenu1, 'Value', BpodSystem.GUIData.Notebook.MarkerCodes(currentTrialViewing))
else
    set(BpodSystem.GUIHandles.Notebook.popupmenu1, 'Value', 1)
end
drawnow;
end

%% ---------------------------------------------------------------------------
function checkbox1_Callback(~,~)
global BpodSystem
currentTrialViewing = str2double(get(BpodSystem.GUIHandles.Notebook.edit2, 'String'));
cbval = get(BpodSystem.GUIHandles.Notebook.checkbox1, 'Value');
if cbval == 1
    BpodSystem.GUIData.Notebook.MarkerCodes(currentTrialViewing) = get(BpodSystem.GUIHandles.Notebook.popupmenu1, 'Value');
else
    BpodSystem.GUIData.Notebook.MarkerCodes(currentTrialViewing) = 0;
end
drawnow;
end

%% ---------------------------------------------------------------------------
function edit2_Callback(~,~)
global BpodSystem
maxTrials = length(BpodSystem.GUIData.Notebook.Notes);
num = ceil(str2double(get(BpodSystem.GUIHandles.Notebook.edit2, 'String')));
if ~isnan(num)
    if num < 1
        msgbox('Invalid trial number.')
        BpodErrorSound
        num = 1;
    elseif num > maxTrials
        msgbox('Invalid trial number.')
        BpodErrorSound
        num = maxTrials;
    end
else
    msgbox('Invalid trial number.')
    BpodErrorSound
    num = maxTrials;
end
str = BpodSystem.GUIData.Notebook.Notes{num};
set(BpodSystem.GUIHandles.Notebook.edit2, 'String', num2str(num));
set(BpodSystem.GUIHandles.Notebook.edit1, 'String', str);
drawnow;
end

%% ---------------------------------------------------------------------------
function edit1_Callback(~,~)
global BpodSystem
    currentTrialViewing = str2double(get(BpodSystem.GUIHandles.Notebook.edit2, 'String'));
    BpodSystem.GUIData.Notebook.Notes{currentTrialViewing} = get(BpodSystem.GUIHandles.Notebook.edit1, 'String');
    drawnow;
end

%% ---------------------------------------------------------------------------
function popupmenu1_Callback(~,~)
global BpodSystem
currentTrialViewing = str2double(get(BpodSystem.GUIHandles.Notebook.edit2, 'String'));
if get(BpodSystem.GUIHandles.Notebook.checkbox1, 'Value')
    BpodSystem.GUIData.Notebook.MarkerCodes(currentTrialViewing) = get(BpodSystem.GUIHandles.Notebook.popupmenu1, 'Value');
end
drawnow;
end
