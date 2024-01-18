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

%   StateTiming is a plugin to Display the fraction of trial time spent in 
%   Bpod states during the most recent trial. It only has one optional 
%   parameter, T0, that can be used to shift the x-axis by a user-defined 
%   amount of seconds. This can be useful if you want to display the state 
%   timings relative to a specific event (e.g., the onset of a stimulus).

%   This plugin was contributed in its original form by Florian Rau / Poulet Lab
%   12/2022. See original version and copyright notice in StateTiming.m at 
%   https://github.com/poulet-lab/Bpod_Gen2

function StateTiming(t0)

global BpodSystem % Import the global BpodSystem object

% Obtain access to Bpod data, return if empty
if isempty(BpodSystem) || ~isstruct(BpodSystem.Data) || ...
        isempty(fieldnames(BpodSystem.Data))
    return
end

% Obtain axes handle for plots, prepare axes
persistent hAx
if isempty(hAx) || ~isvalid(hAx)
    if verLessThan('matlab','9.5')
        error('Error: the StateTiming plot requires MATLAB r2018b or newer');
    end
    BpodSystem.ProtocolFigures.StateTimingFig = figure( ...
        'Name',                 'State Timing', ...
        'NumberTitle',          'off', ...
        'MenuBar',              'none');
    hAx = axes(BpodSystem.ProtocolFigures.StateTimingFig, ...
        'YDir',                 'reverse', ...
        'XGrid',                'on', ...
        'YGrid',                'on', ...
        'Box',                  'off', ...
        'TickDir',              'out', ...
        'PickableParts',        'none', ...
        'HitTest',              'off', ...
        'TickLabelInterpreter', 'none', ...
        'NextPlot',             'add');
    xlabel(hAx,'Time [s]')
    xline(hAx,0,':');
    axis(hAx,'tight');
    set(BpodSystem.ProtocolFigures.StateTimingFig,'HandleVisibility', 'off')
end

ch = get(hAx, 'Children');
delete(ch(1:end-1)); % Clear the previous patches. Last item is always the xline

% If BpodSystem.Data has been initialized by the user but events have not been added
if ~isfield(BpodSystem.Data, 'RawEvents') 
    return
end

% some variables
trials  = BpodSystem.Data.RawEvents.Trial;  % trial structure
timings = struct2cell(trials{end}.States);  % the most recent state timings
names   = fieldnames(trials{end}.States);   % state names
nStates = numel(names);                     % number of states
nTrial  = numel(trials);                    % number of current trial
hBar    = .9;                               % height of bars
colors  = get(hAx, 'ColorOrder');           % a list of face colors

% Correct timings by t0 & indicate it
if exist('t0','var') && t0
    timings = cellfun(@(x) {x - t0},timings);
end


% Plot state timing
for idxState = 1:nStates
    x = [timings{idxState} fliplr(timings{idxState})]';
    y = repmat(idxState + hBar./[2;2;-2;-2],1,size(x,2));
    c = colors(mod(idxState - 1, size(colors,1)) + 1,:);
    patch(hAx,x,y,c)
end

% Format axes & labels
title(hAx,sprintf('State Timing, Trial %d',nTrial));
set(hAx, ...
    'YTick',      1:nStates, ...
    'YTickLabel', names, ...
    'YLim',       [.5 nStates+.5])
