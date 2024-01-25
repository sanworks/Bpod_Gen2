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

% OutcomePlot() is a plugin to plot reward side and trial outcome.
% Note: For non-sided trial types, use the TrialTypeOutcomePlot() plugin.
%
% Usage:
% function OutcomePlot(AxesHandle, Action, TrialTypeSides, OutcomeRecord, CurrentTrial)
%
% Arguments:
% AxesHandle = handle of axes to plot on
% Action = specific action for plot, "init" - initialize OR "update" -  update plot
%
% Optional Arguments:
% TrialTypeSides: Vector of 0's (right) or 1's (left) to indicate reward side (0,1), or 'None' to plot trial types individually
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
% CurrentTrial: the current trial number
%
% Example usage:
% SideOutcomePlot(AxesHandle,'init',TrialTypeSides)
% SideOutcomePlot(AxesHandle,'init',TrialTypeSides,'ntrials',90)
% SideOutcomePlot(AxesHandle,'update',CurrentTrial,TrialTypeSides,OutcomeRecord)

% Adapted from BControl (SidesPlotSection.m) 
% Port contributed by Kachi Odomene, 2014.Mar.17

function SideOutcomePlot(AxesHandle, Action, varargin)

global BpodSystem % Import the global BpodSystem object

switch Action
    case 'init'
        SideList = varargin{1};

        % Set #Trials to show
        BpodSystem.GUIData.SOPnTrialsToShow = 90; %default number of trials to display
        if nargin > 3 %custom number of trials
            BpodSystem.GUIData.SOPnTrialsToShow = varargin{3};
        end

        % Set label font size
        if ispc
            labelFontSize = 18;
        else
            labelFontSize = 15;
        end
        axes(AxesHandle);

        % Plot in specified axes
        Xdata = 1:BpodSystem.GUIData.SOPnTrialsToShow; Ydata = SideList(Xdata);
        BpodSystem.GUIHandles.FutureTrialLine = line([Xdata,Xdata],[Ydata,Ydata],'LineStyle','none','Marker','o','MarkerEdge','b','MarkerFace','b', 'MarkerSize',6);
        BpodSystem.GUIHandles.CurrentTrialCircle = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','k','MarkerFace',[1 1 1], 'MarkerSize',6);
        BpodSystem.GUIHandles.CurrentTrialCross = line([0,0],[0,0], 'LineStyle','none','Marker','+','MarkerEdge','k','MarkerFace',[1 1 1], 'MarkerSize',6);
        BpodSystem.GUIHandles.UnpunishedErrorLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','r','MarkerFace',[1 1 1], 'MarkerSize',6);
        BpodSystem.GUIHandles.PunishedErrorLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','r','MarkerFace','r', 'MarkerSize',6);
        BpodSystem.GUIHandles.RewardedCorrectLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','g','MarkerFace','g', 'MarkerSize',6);
        BpodSystem.GUIHandles.UnrewardedCorrectLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','g','MarkerFace',[1 1 1], 'MarkerSize',6);
        BpodSystem.GUIHandles.NoResponseLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','b','MarkerFace',[1 1 1], 'MarkerSize',6);
        set(AxesHandle,'TickDir', 'out','YLim', [-1, 2], 'YTick', [0 1],'YTickLabel', {'Right','Left'}, 'FontSize', 16);
        xlabel(AxesHandle, 'Trial#', 'FontSize', labelFontSize);
        hold(AxesHandle, 'on');
        
    case 'update'
        % Import vars
        CurrentTrial = varargin{1};
        SideList = varargin{2};
        OutcomeRecord = varargin{3};
        if CurrentTrial<1
            CurrentTrial = 1;
        end

        % Recompute xlim
        [mn, mx] = rescale_x(AxesHandle,CurrentTrial,BpodSystem.GUIData.SOPnTrialsToShow);

        % Plot future trials
        FutureTrialsIndx = CurrentTrial:mx;
        Xdata = FutureTrialsIndx; Ydata = SideList(Xdata);
        set(BpodSystem.GUIHandles.FutureTrialLine, 'xdata', [Xdata,Xdata], 'ydata', [Ydata,Ydata]);
        %Plot current trial
        set(BpodSystem.GUIHandles.CurrentTrialCircle, 'xdata', [CurrentTrial,CurrentTrial], 'ydata', [SideList(CurrentTrial),SideList(CurrentTrial)]);
        set(BpodSystem.GUIHandles.CurrentTrialCross, 'xdata', [CurrentTrial,CurrentTrial], 'ydata', [SideList(CurrentTrial),SideList(CurrentTrial)]);
        
        % Plot past trials
        if ~isempty(OutcomeRecord)
            indxToPlot = mn:CurrentTrial-1;

            %Plot Error, unpunished
            EarlyWithdrawalTrialsIndx =(OutcomeRecord(indxToPlot) == -1);
            Xdata = indxToPlot(EarlyWithdrawalTrialsIndx); Ydata = SideList(Xdata);
            set(BpodSystem.GUIHandles.UnpunishedErrorLine, 'xdata', [Xdata,Xdata], 'ydata', [Ydata,Ydata]);

            %Plot Error, punished
            InCorrectTrialsIndx = (OutcomeRecord(indxToPlot) == 0);
            Xdata = indxToPlot(InCorrectTrialsIndx); Ydata = SideList(Xdata);
            set(BpodSystem.GUIHandles.PunishedErrorLine, 'xdata', [Xdata,Xdata], 'ydata', [Ydata,Ydata]);

            %Plot Correct, rewarded
            CorrectTrialsIndx = (OutcomeRecord(indxToPlot) == 1);
            Xdata = indxToPlot(CorrectTrialsIndx); Ydata = SideList(Xdata);
            set(BpodSystem.GUIHandles.RewardedCorrectLine, 'xdata', [Xdata,Xdata], 'ydata', [Ydata,Ydata]);

            %Plot Correct, unrewarded
            UnrewardedTrialsIndx = (OutcomeRecord(indxToPlot) == 2);
            Xdata = indxToPlot(UnrewardedTrialsIndx); Ydata = SideList(Xdata);
            set(BpodSystem.GUIHandles.UnrewardedCorrectLine, 'xdata', [Xdata,Xdata], 'ydata', [Ydata,Ydata]);

            %Plot DidNotChoose
            DidNotChooseTrialsIndx = (OutcomeRecord(indxToPlot) == 3);
            Xdata = indxToPlot(DidNotChooseTrialsIndx); Ydata = SideList(Xdata);
            set(BpodSystem.GUIHandles.NoResponseLine, 'xdata', [Xdata,Xdata], 'ydata', [Ydata,Ydata]);
        end
end

end

function [mn,mx] = rescale_x(axesHandle,currentTrial,nTrialsToShow)
    FractionWindowStickpoint = .75; % After this fraction of visible trials, the trial position in the window 
                                    % "sticks" and the window begins to slide through trials.
    mn = max(round(currentTrial - FractionWindowStickpoint*nTrialsToShow),1);
    mx = mn + nTrialsToShow - 1;
    set(axesHandle,'XLim',[mn-1 mx+1]);
end


