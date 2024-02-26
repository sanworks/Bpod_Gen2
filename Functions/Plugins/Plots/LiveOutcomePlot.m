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

% LiveOutcomePlot is an GUI to display trial outcomes by trial type.
% The GUI shows trial types in a 90-trial window surrounding the current trial.
% Correct trials are scored green o. Rewarded trials are filled in.
% Incorrect trials are scored red o. Punished trials are filled in.
% Incomplete previous trials are scored blue o. Future trials are filled in.
%
% Example usage:
% --- During trial setup ---
% trialTypes = ceil(rand(1,1000)*2); % Randomly interleave trial types [1, 2] for 1000 future trials
% outcomePlot = LiveOutcomePlot([1 2], {'Left', 'Right'}, trialTypes); % Create an instance of LiveOutcomePlot
% outcomePlot.CorrectStateNames = {'LeftRewardDelay', 'RightRewardDelay'}; % states where decision was correct
% outcomePlot.RewardStateNames = {'LeftReward', 'RightReward'}; % states where reward was delivered
% outcomePlot.PunishStateNames = {'PunishTimeout'}; % states where an incorrect decision was negatively reinforced
% --- After each trial ends ---
% scoreCard.update(trialTypes, BpodSystem.Data); % Update the GUI with a data struct returned by AddTrialEvents()

classdef LiveOutcomePlot < handle
    properties
        TrialTypeManifest % An array of integers denoting possible trial types in the experiment.
        TrialTypeNames % A cell array of names, <15 char each, for the trial types in TrialTypeManifest
        TrialTypes % An array of precomputed trial types for each trial in the experiment.
        CorrectStateNames % A cell array of state names indicating correct decisions
        ErrorStateNames % A cell array of state names indicating incorrect decisions
        RewardStateNames % A cell array of state names indicating that a reward was delivered
        PunishStateNames % A cell array of state names indicating that negative reinforcement was
        % delivered (e.g. a punitive timeout)
        nTrialsToShow = 90 % Number of trials to show on the plot
    end

    properties (Access = private)
        FigureHandle
        AxesHandle
        GUIHandles
    end

    methods
        function obj = LiveOutcomePlot(newTrialTypeManifest, newTrialTypeNames, newTrialTypes, nTrialsToShow)
            % Class constructor

            global BpodSystem % Import the global BpodSystem object

            % Setup the figure
            obj.FigureHandle = figure('Position', [50 540 1000 250],'name','Outcome plot',...
                'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');

            % Register the fig with Bpod so it gets closed when the protocol ends / console GUI closes
            BpodSystem.ProtocolFigures.OutcomePlotFig = obj.FigureHandle;

            % Setup the axes
            obj.AxesHandle = axes('Position', [.075 .3 .89 .6]);

            % Process args
            obj.TrialTypeManifest = newTrialTypeManifest;
            obj.TrialTypeNames = newTrialTypeNames;
            obj.TrialTypes = newTrialTypes;
            obj.nTrialsToShow = nTrialsToShow;

            % Render the plot
            if ispc
                labelFontSize = 18;
            else
                labelFontSize = 15;
            end
            axes(obj.AxesHandle);
            maxTrialType = max(obj.TrialTypeManifest);
            xdata = 1:obj.nTrialsToShow;
            ydata = -obj.TrialTypes(xdata);
            obj.GUIHandles.FutureTrialLine = line([xdata,xdata],[ydata,ydata],...
                'LineStyle', 'none',...
                'Marker', 'o',...
                'MarkerEdge', 'b',...
                'MarkerFace', 'b',...
                'MarkerSize', 6);
            obj.GUIHandles.CurrentTrialCircle = line([0,0],[0,0],...
                'LineStyle','none',...
                'Marker', 'o',...
                'MarkerEdge', 'k',...
                'MarkerFace', [1 1 1],...
                'MarkerSize',6);
            obj.GUIHandles.CurrentTrialCross = line([0,0],[0,0],...
                'LineStyle','none',...
                'Marker','+',...
                'MarkerEdge','k',...
                'MarkerFace', [1 1 1],...
                'MarkerSize',6);
            obj.GUIHandles.UnpunishedErrorLine = line([0,0],[0,0],...
                'LineStyle', 'none',...
                'Marker', 'o',...
                'MarkerEdge', 'r',...
                'MarkerFace', [1 1 1],...
                'MarkerSize', 6);
            obj.GUIHandles.PunishedErrorLine = line([0,0],[0,0],...
                'LineStyle', 'none',...
                'Marker','o',...
                'MarkerEdge','r',...
                'MarkerFace','r',...
                'MarkerSize',6);
            obj.GUIHandles.RewardedCorrectLine = line([0,0],[0,0],...
                'LineStyle', 'none',...
                'Marker', 'o',...
                'MarkerEdge', 'g',...
                'MarkerFace', 'g',...
                'MarkerSize', 6);
            obj.GUIHandles.UnrewardedCorrectLine = line([0,0],[0,0],...
                'LineStyle', 'none',...
                'Marker', 'o',...
                'MarkerEdge','g',...
                'MarkerFace', [1 1 1],...
                'MarkerSize',6);
            obj.GUIHandles.NoResponseLine = line([0,0],[0,0],...
                'LineStyle', 'none',...
                'Marker', 'o',...
                'MarkerEdge','b',...
                'MarkerFace', [1 1 1],...
                'MarkerSize',6);
            set(obj.AxesHandle,'TickDir', 'out',...
                'YLim', [-maxTrialType-.75, -.25],...
                'YTick', -maxTrialType:1:-1,...
                'YTickLabel', obj.TrialTypeNames(end:-1:1),...
                'FontSize', 16);
            xlabel(obj.AxesHandle, 'Trial#', 'FontSize', labelFontSize);
            hold(obj.AxesHandle, 'on');
        end

        function set.TrialTypes(obj, newTrialTypes)
            obj.verifyTrialTypes(newTrialTypes);
            obj.TrialTypes = newTrialTypes;
        end

        function set.TrialTypeManifest(obj, newTrialTypes)
            obj.verifyTrialTypes(newTrialTypes);
            if numel(newTrialTypes) ~= numel(unique(newTrialTypes))
                error('TrialTypeManifest must be a vector of unique positive integers.')
            end
            obj.TrialTypeManifest = newTrialTypes;
        end

        function set.TrialTypeNames(obj, newNames)
            longestName = 0;
            for i = 1:length(newNames)
                if length(newNames{i}) > longestName
                    longestName = length(newNames{i});
                end
            end
            plotYOffset = longestName*0.012;
            set(obj.AxesHandle, 'Position', [.03+plotYOffset .3 0.93-plotYOffset .6])
            obj.TrialTypeNames = newNames;
        end

        function set.CorrectStateNames(obj, newStateNames)
            obj.verifyStateNames(newStateNames);
            obj.CorrectStateNames = newStateNames;
        end

        function set.ErrorStateNames(obj, newStateNames)
            obj.verifyStateNames(newStateNames);
            obj.ErrorStateNames = newStateNames;
        end

        function set.RewardStateNames(obj, newStateNames)
            obj.verifyStateNames(newStateNames);
            obj.RewardStateNames = newStateNames;
        end

        function set.PunishStateNames(obj, newStateNames)
            obj.verifyStateNames(newStateNames);
            obj.PunishStateNames = newStateNames;
        end

        function set.nTrialsToShow(obj, newValue)
            if newValue < 0 || newValue > length(obj.TrialTypes)
                error('nTrialsToShow must be in range [0, length(TrialTypes)]')
            end
            obj.nTrialsToShow = newValue;
        end

        function update(obj, trialTypeList, bpodData)
            % Compute scorecard
            outcomes = zeros(1,bpodData.nTrials);
            outcomes(1:bpodData.nTrials) = 3;
            for iTrial = 1:bpodData.nTrials
                % Compute correct trials
                for j = 1:length(obj.CorrectStateNames)
                    if ~isnan(bpodData.RawEvents.Trial{iTrial}.States.(obj.CorrectStateNames{j})(1))
                        outcomes(iTrial) = 2;
                    end
                end

                % Compute error trials
                for j = 1:length(obj.ErrorStateNames)
                    if ~isnan(bpodData.RawEvents.Trial{iTrial}.States.(obj.ErrorStateNames{j})(1))
                        outcomes(iTrial) = -1;
                    end
                end

                % Compute rewarded trials
                for j = 1:length(obj.RewardStateNames)
                    if ~isnan(bpodData.RawEvents.Trial{iTrial}.States.(obj.RewardStateNames{j})(1))
                        outcomes(iTrial) = 1;
                    end
                end

                % Compute punished trials (e.g. punitive timeout)
                for j = 1:length(obj.PunishStateNames)
                    if ~isnan(bpodData.RawEvents.Trial{iTrial}.States.(obj.PunishStateNames{j})(1))
                        outcomes(iTrial) = 0;
                    end
                end
            end
            currentTrial = bpodData.nTrials+1;
            maxTrialType = max(obj.TrialTypeManifest);
            set(obj.AxesHandle,'YLim', [-maxTrialType-.75, -.25],...
                               'YTick', -maxTrialType:1:-1,...
                               'YTickLabel', obj.TrialTypeNames(end:-1:1));
            trialTypeList  = -trialTypeList;

            % Recompute xlim
            [mn, mx] = obj.rescale_x(currentTrial, obj.nTrialsToShow);
            offset = mn-1;
                      
            if currentTrial <= length(trialTypeList)
                % Plot future trials
                futureTrialsIndx = currentTrial:mx;
                xdata = futureTrialsIndx; ydata = trialTypeList(xdata);
                displayXdata = xdata-offset;
                set(obj.GUIHandles.FutureTrialLine, 'xdata', [displayXdata,displayXdata],...
                    'ydata', [ydata,ydata]);

                % Plot current trial
                displayCurrentTrial = currentTrial-offset;
                set(obj.GUIHandles.CurrentTrialCircle, 'xdata', [displayCurrentTrial,displayCurrentTrial],...
                    'ydata', [trialTypeList(currentTrial),trialTypeList(currentTrial)]);
                set(obj.GUIHandles.CurrentTrialCross, 'xdata', [displayCurrentTrial,displayCurrentTrial],...
                    'ydata', [trialTypeList(currentTrial),trialTypeList(currentTrial)]);
            end

            % Plot past trials
            if ~isempty(outcomes)
                indxToPlot = mn:currentTrial-1;

                % Plot Error, unpunished
                earlyWithdrawalTrialsIndx =(outcomes(indxToPlot) == -1);
                xdata = indxToPlot(earlyWithdrawalTrialsIndx); ydata = trialTypeList(xdata);
                dispData = xdata-offset;
                set(obj.GUIHandles.UnpunishedErrorLine, 'xdata', [dispData,dispData], 'ydata', [ydata,ydata]);

                % Plot Error, punished
                inCorrectTrialsIndx = (outcomes(indxToPlot) == 0);
                xdata = indxToPlot(inCorrectTrialsIndx); ydata = trialTypeList(xdata);
                dispData = xdata-offset;
                set(obj.GUIHandles.PunishedErrorLine, 'xdata', [dispData,dispData], 'ydata', [ydata,ydata]);

                % Plot Correct, rewarded
                correctTrialsIndx = (outcomes(indxToPlot) == 1);
                xdata = indxToPlot(correctTrialsIndx); ydata = trialTypeList(xdata);
                dispData = xdata-offset;
                set(obj.GUIHandles.RewardedCorrectLine, 'xdata', [dispData,dispData], 'ydata', [ydata,ydata]);

                % Plot Correct, unrewarded
                unrewardedTrialsIndx = (outcomes(indxToPlot) == 2);
                xdata = indxToPlot(unrewardedTrialsIndx); ydata = trialTypeList(xdata);
                dispData = xdata-offset;
                set(obj.GUIHandles.UnrewardedCorrectLine, 'xdata', [dispData,dispData], 'ydata', [ydata,ydata]);

                % Plot DidNotChoose
                didNotChooseTrialsIndx = (outcomes(indxToPlot) == 3);
                xdata = indxToPlot(didNotChooseTrialsIndx); ydata = trialTypeList(xdata);
                dispData = xdata-offset;
                set(obj.GUIHandles.NoResponseLine, 'xdata', [dispData,dispData], 'ydata', [ydata,ydata]);
            end
        end

        function delete(obj)
            if isgraphics(obj.FigureHandle)
                close(obj.FigureHandle);
            end
        end
    end

    methods (Access = private)
        function verifyTrialTypes(obj, putativeTrialTypes)
            if min(putativeTrialTypes) < 1 || sum(mod(putativeTrialTypes,1)) > 0
                error(['Trial types must be a vector of positive integers.' char(10)...
                    'Each integer denotes a type of trial to measure a unique experimental condition.'])
            end
        end

        function verifyStateNames(obj, stateNames)
            if ~iscell(stateNames)
                error('State names must be given as a cell array of strings.')
            end
        end

        function [mn,mx] = rescale_x(obj, currentTrial, nTrialsToShow)
            % FractionWindowStickpoint: After this fraction of visible trials, the trial position in the window "sticks"
            % and the window begins to slide through trials.
            fractionWindowStickpoint = .75;
            mn = max(round(currentTrial - fractionWindowStickpoint*nTrialsToShow),1);
            mx = mn + nTrialsToShow - 1;
            tickLabels = sprintfc('%d',(mn-1:10:mx));
            set(obj.AxesHandle, 'Xtick', 0:10:nTrialsToShow, 'XtickLabel', tickLabels);
        end
    end
end