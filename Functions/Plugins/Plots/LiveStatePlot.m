% Plugin for drawing a live update of trial
% obj = LiveStatePlot(_)
% 
% Arguments
% ---------
% BpodSystem : BpodObject
%     BpodSystem, optional (defaults)
%
% Keyword Arguments
% -----------------
% darkmode : bool
%     Make the plot dark mode, default true
% autoclose : bool
%     Close the figure window at the end of session, default true

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

classdef LiveStatePlot < handle
properties
    GUIHandles
    BpodSystem
    lastTic % The last time of update
    trialStartTic
    lastNEvents
    timeDiff

    settings
    maxDrawHz
end
methods
    function obj = LiveStatePlot(varargin)
        p = inputParser();
        p.addOptional('BpodSystem', [])
        p.addParameter('darkmode', true)
        p.addParameter('autoclose', true)
        p.parse(varargin{:})
        if isempty(p.Results.BpodSystem)
            global BpodSystem
        else
            BpodSystem = p.Results.BpodSystem;
        end
        obj.settings = struct();
        obj.settings.darkmode = p.Results.darkmode;
        obj.settings.defaultMaxTime = [];
        obj.settings.leadTime = 3;

        % Build axes
        obj.BpodSystem = BpodSystem;
        obj.GUIHandles.Figure = figure('Name', 'LivePlot', 'MenuBar', 'none', 'NumberTitle', 'off');
        if p.Results.autoclose
            obj.BpodSystem.ProtocolFigures.LivePlot = obj;
        else
            obj.BpodSystem.GUIHandles.LivePlot = obj;
        end
        xpos = 0.2;
        obj.GUIHandles.AxesState = axes(obj.GUIHandles.Figure, 'Position', [xpos, .5, 1-xpos-.1, .2]);
        obj.GUIHandles.AxesEvent = axes(obj.GUIHandles.Figure, 'Position', [xpos, 0, 1-xpos-.1, .2]);
        obj.GUIHandles.PlotState = stairs(obj.GUIHandles.AxesState, 0, 0); % if stairs initialises with [] data then it won't update
        obj.GUIHandles.PlotEvent = scatter(obj.GUIHandles.AxesEvent, [], []);
        obj.apply_style()
        
        obj.lastTic = tic;
        obj.lastNEvents = [];
        obj.timeDiff = 0;
        obj.maxDrawHz = 60;
    end

    function apply_style(obj)
        % Sets axes and plot styling

        xpos = .2;
        set(obj.GUIHandles.AxesState,...
            'Position', [xpos, .5, 1-xpos, .5]);
        set(obj.GUIHandles.AxesEvent,...
            'Position', [xpos, .1, 1-xpos, .4]);
        
        % -- Set colors
        if obj.settings.darkmode
            color = 'w';
        else
            color = 'k';
        end
        set(obj.GUIHandles.PlotState,...
            'Color', color, ...
            'Marker', '.')
        set(obj.GUIHandles.PlotEvent,...
            'Color', color,...
            'Marker', '|')
        grid(obj.GUIHandles.AxesState, 'on')
        grid(obj.GUIHandles.AxesEvent, 'on')

        for ax = {obj.GUIHandles.AxesState, obj.GUIHandles.AxesEvent}
            if obj.settings.darkmode
                BpodLib.ui.utils.setDarkMode(ax{1})
            end
        end

        % Y labels (states and events) are set in obj.newTrial()
        
    end

    function close(obj)
        close(obj.GUIHandles.Figure);
    end

    function update(obj, operation)
        switch operation
            case 'trial_start'
                obj.newTrial()
                return
            case 'trial_end'
                return
        end

        % Limit rate the plot update
        if toc(obj.lastTic) < 1/obj.maxDrawHz
            return
        end

        if ~isvalid(obj.GUIHandles.Figure)
            assert(obj.BpodSystem.Status.BeingUsed == 0)
            return
        end

        % Calculate the time offset between the machine and computer
        eventTimes = obj.BpodSystem.Status.liveEventTimestamps(obj.BpodSystem.Status.liveEventTimestamps ~= 0);
        if obj.BpodSystem.EmulatorMode == 0
            eventTimes = eventTimes / 1000;
        else
            eventTimes = cumsum(eventTimes);
        end
        
        currentTime = toc(obj.trialStartTic);
        if numel(eventTimes) > obj.lastNEvents  % If there is a new event
            obj.lastNEvents = numel(eventTimes);
            % Calculate difference between machine's time and toc() time
            obj.timeDiff = eventTimes(end) - currentTime;
        end
        
        % -- Build state index and times
        currentTime = currentTime + obj.timeDiff;

        stateindices = obj.BpodSystem.Status.states(obj.BpodSystem.Status.states ~= 0);

        stateChangeIndexes = obj.BpodSystem.Status.stateChangeIndexes(obj.BpodSystem.Status.stateChangeIndexes ~= 0);
        stateTimes = eventTimes(stateChangeIndexes);

        % Build stairs-compatible x/y data
        stateTimes = [0 stateTimes currentTime];
        stateindices = [stateindices stateindices(end)];

        % if ~isempty(obj.settings.defaultMaxTime)
        %     if (currentTime + obj.settings.leadTime) > obj.settings.defaultMaxTime
        %         xLimMax = currentTime + obj.settings.leadTime;
        %     else
        %         xLimMax = obj.settings.defaultMaxTime;
        %     end
        % else
        %     xLimMax = currentTime + obj.settings.leadTime;
        % end
        % Update plot
        set(obj.GUIHandles.PlotState, ...
            'XData', stateTimes, ...
            'YData', stateindices);
        % set(obj.GUIHandles.AxesState,...
            % 'XLim', [0, xLimMax]);
        obj.update_events(eventTimes, obj.BpodSystem.Status.events(obj.BpodSystem.Status.events ~= 0))

        obj.lastTic = tic;
    end

    function update_events(obj, eventTimes, eventIndexes)
        times = eventTimes;
        ydata = eventIndexes;
        % todo: enable custom specification of focus events
        % todo: build pulse traces for port events

        set(obj.GUIHandles.PlotEvent,...
            'XData', times,...
            'YData', ydata)
        set(obj.GUIHandles.AxesEvent,...
            'XLim', get(obj.GUIHandles.AxesState, 'XLim'));
    end

    function newTrial(obj)
        obj.lastNEvents = 0;
        obj.trialStartTic = tic;

        % -- Prepare state axes
        stateNames = obj.BpodSystem.StateMatrix.StateNames; % initialised only when SendStateMatrix() is used...
        set(obj.GUIHandles.AxesState,...
            'YTick', 1:numel(stateNames), ...
            'YTickLabel', stateNames,...
            'YLim', [-0.5, numel(stateNames) + .5])
        % obj.timeDiff = % todo: this could be calculated from trialStartTimestamp ?

        % -- Prepare event axes
        % Determine which events are even valid?
        
    end
end
end

