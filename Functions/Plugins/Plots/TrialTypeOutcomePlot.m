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

% Plugin to Plot trial type and trial outcome.
% AxesHandle = handle of axes to plot on
% Action = specific action for plot, "init" - initialize OR "update" -  update plot

% Example usage:
% TrialTypeOutcomePlot(AxesHandle,'init',TrialTypes)
% TrialTypeOutcomePlot(AxesHandle,'init',TrialTypes,'ntrials',90)
% TrialTypeOutcomePlot(AxesHandle,'update',CurrentTrial,TrialTypes,OutcomeRecord)

% varargins:
% TrialTypes: Vector of trial types (integers)
% OutcomeRecord:  Vector of trial outcomes
%                 Simplest case: 
%                               1: correct trial (green)
%                               0: incorrect trial (red)
%                 Advanced case: 
%                               NaN: future trial (blue)
%                                -1: withdrawal (red circle)
%                                 0: incorrect choice (red dot)
%                                 1: correct choice (green dot)
%                                 2: did not choose (green circle)
% OutcomeRecord can also be empty
% Current trial: the current trial number

% Adapted from BControl (SidesPlotSection.m) 
% Kachi O. 2014.Mar.17
% J. Sanders. 2015.Jun.6 - adapted to display trial types instead of sides

function TrialTypeOutcomePlot(axesHandle, action, varargin)

global BpodSystem % Import the global BpodSystem object

switch action
    case 'init'
        % Initialize pokes plot
        trialTypeList = varargin{1};
        BpodSystem.GUIData.TTOPnTrialsToShow = 90; %default number of trials to display
        
        if nargin > 3 % Custom number of trials
            BpodSystem.GUIData.TTOPnTrialsToShow =varargin{3};
        end
        if ispc
            labelFontSize = 18;
        else
            labelFontSize = 15;
        end
        axes(axesHandle);
        maxTrialType = max(trialTypeList);

        % Plot in specified axes
        xdata = 1:BpodSystem.GUIData.TTOPnTrialsToShow; ydata = -trialTypeList(xdata);
        BpodSystem.GUIHandles.FutureTrialLine = line([xdata,xdata],[ydata,ydata],'LineStyle','none','Marker','o',...
            'MarkerEdge','b','MarkerFace','b', 'MarkerSize',6);
        BpodSystem.GUIHandles.CurrentTrialCircle = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','k',...
            'MarkerFace',[1 1 1], 'MarkerSize',6);
        BpodSystem.GUIHandles.CurrentTrialCross = line([0,0],[0,0], 'LineStyle','none','Marker','+','MarkerEdge','k',...
            'MarkerFace',[1 1 1], 'MarkerSize',6);
        BpodSystem.GUIHandles.UnpunishedErrorLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','r',...
            'MarkerFace',[1 1 1], 'MarkerSize',6);
        BpodSystem.GUIHandles.PunishedErrorLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','r',...
            'MarkerFace','r', 'MarkerSize',6);
        BpodSystem.GUIHandles.RewardedCorrectLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','g',...
            'MarkerFace','g', 'MarkerSize',6);
        BpodSystem.GUIHandles.UnrewardedCorrectLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','g',...
            'MarkerFace',[1 1 1], 'MarkerSize',6);
        BpodSystem.GUIHandles.NoResponseLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','b',...
            'MarkerFace',[1 1 1], 'MarkerSize',6);
        if verLessThan('matlab','8.0') % Use optimal split function if possible
            BpodSystem.GUIHandles.TTOP_Ylabel = split(num2str(maxTrialType:-1:-1));
        else
            BpodSystem.GUIHandles.TTOP_Ylabel = strsplit(num2str(maxTrialType:-1:-1));
        end
        set(axesHandle,'TickDir', 'out','YLim', [-maxTrialType-.5, -.5], 'YTick', -maxTrialType:1:-1,'YTickLabel',... 
            BpodSystem.GUIHandles.TTOP_Ylabel, 'FontSize', 16);
        xlabel(axesHandle, 'Trial#', 'FontSize', labelFontSize);
        ylabel(axesHandle, 'Trial Type', 'FontSize', 16);
        hold(axesHandle, 'on');
        
    case 'update'
        % Import args
        currentTrial = varargin{1};
        trialTypeList = varargin{2};
        outcomeRecord = varargin{3};
        maxTrialType = max(trialTypeList);
        set(axesHandle,'YLim',[-maxTrialType-.5, -.5], 'YTick', -maxTrialType:1:-1,'YTickLabel', BpodSystem.GUIHandles.TTOP_Ylabel);
        if currentTrial<1
            currentTrial = 1;
        end
        trialTypeList  = -trialTypeList;
        
        % Recompute xlim
        [mn, mx] = rescale_x(axesHandle,currentTrial,BpodSystem.GUIData.TTOPnTrialsToShow);
        
        % Plot future trials
        offset = mn-1;
        futureTrialsIndx = currentTrial:mx;
        xdata = futureTrialsIndx; ydata = trialTypeList(xdata);
        displayXdata = xdata-offset;
        set(BpodSystem.GUIHandles.FutureTrialLine, 'xdata', [displayXdata,displayXdata], 'ydata', [ydata,ydata]);

        % Plot current trial
        displayCurrentTrial = currentTrial-offset;
        set(BpodSystem.GUIHandles.CurrentTrialCircle, 'xdata', [displayCurrentTrial,displayCurrentTrial],... 
            'ydata', [trialTypeList(currentTrial),trialTypeList(currentTrial)]);
        set(BpodSystem.GUIHandles.CurrentTrialCross, 'xdata', [displayCurrentTrial,displayCurrentTrial],... 
            'ydata', [trialTypeList(currentTrial),trialTypeList(currentTrial)]);
        
        % Plot past trials
        if ~isempty(outcomeRecord)
            indxToPlot = mn:currentTrial-1;

            % Plot Error, unpunished
            earlyWithdrawalTrialsIndx =(outcomeRecord(indxToPlot) == -1);
            xdata = indxToPlot(earlyWithdrawalTrialsIndx); ydata = trialTypeList(xdata);
            dispData = xdata-offset;
            set(BpodSystem.GUIHandles.UnpunishedErrorLine, 'xdata', [dispData,dispData], 'ydata', [ydata,ydata]);

            % Plot Error, punished
            inCorrectTrialsIndx = (outcomeRecord(indxToPlot) == 0);
            xdata = indxToPlot(inCorrectTrialsIndx); ydata = trialTypeList(xdata);
            dispData = xdata-offset;
            set(BpodSystem.GUIHandles.PunishedErrorLine, 'xdata', [dispData,dispData], 'ydata', [ydata,ydata]);

            % Plot Correct, rewarded
            correctTrialsIndx = (outcomeRecord(indxToPlot) == 1);
            xdata = indxToPlot(correctTrialsIndx); ydata = trialTypeList(xdata);
            dispData = xdata-offset;
            set(BpodSystem.GUIHandles.RewardedCorrectLine, 'xdata', [dispData,dispData], 'ydata', [ydata,ydata]);

            % Plot Correct, unrewarded
            unrewardedTrialsIndx = (outcomeRecord(indxToPlot) == 2);
            xdata = indxToPlot(unrewardedTrialsIndx); ydata = trialTypeList(xdata);
            dispData = xdata-offset;
            set(BpodSystem.GUIHandles.UnrewardedCorrectLine, 'xdata', [dispData,dispData], 'ydata', [ydata,ydata]);

            % Plot DidNotChoose
            didNotChooseTrialsIndx = (outcomeRecord(indxToPlot) == 3);
            xdata = indxToPlot(didNotChooseTrialsIndx); ydata = trialTypeList(xdata);
            dispData = xdata-offset;
            set(BpodSystem.GUIHandles.NoResponseLine, 'xdata', [dispData,dispData], 'ydata', [ydata,ydata]);
        end
end

end

function [mn,mx] = rescale_x(axesHandle,currentTrial,nTrialsToShow)
    % FractionWindowStickpoint: After this fraction of visible trials, the trial position in the window "sticks" 
    % and the window begins to slide through trials.
    fractionWindowStickpoint = .75; 
    mn = max(round(currentTrial - fractionWindowStickpoint*nTrialsToShow),1);
    mx = mn + nTrialsToShow - 1;
    tickLabels = sprintfc('%d',(mn-1:10:mx));
    set(axesHandle, 'Xtick', 0:10:nTrialsToShow, 'XtickLabel', tickLabels);
end

function splitString = split(s)
    w = isspace(s);            
    if any(w)
        % Decide the positions of terms        
        dw = diff(w);
        sp = [1, find(dw == -1) + 1];     % start positions of terms
        ep = [find(dw == 1), length(s)];  % end positions of terms

        % Extract the terms        
        nt = numel(sp);
        splitString = cell(1, nt);
        for i = 1 : nt
            splitString{i} = s(sp(i):ep(i));
        end                
    else
        splitString = {s};
    end
end
