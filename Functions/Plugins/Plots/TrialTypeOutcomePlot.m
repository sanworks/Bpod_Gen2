%{
----------------------------------------------------------------------------

This file is part of the Bpod Project
Copyright (C) 2015 Joshua I. Sanders, Cold Spring Harbor Laboratory, NY, USA

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
% function OutcomePlot(AxesHandle,TrialTypeSides, OutcomeRecord, CurrentTrial)
function TrialTypeOutcomePlot(AxesHandle, Action, varargin)
%% 
% Plug in to Plot trial type and trial outcome.
% AxesHandle = handle of axes to plot on
% Action = specific action for plot, "init" - initialize OR "update" -  update plot

%Example usage:
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

%% Code Starts Here
global nTrialsToShow %this is for convenience
global BpodSystem

switch Action
    case 'init'
        %initialize pokes plot
        TrialTypeList = varargin{1};
        nTrialsToShow = 90; %default number of trials to display
        
        if nargin > 3 %custom number of trials
            nTrialsToShow =varargin{3};
        end
        axes(AxesHandle);
        MaxTrialType = max(TrialTypeList);
        %plot in specified axes
        Xdata = 1:nTrialsToShow; Ydata = -TrialTypeList(Xdata);
        BpodSystem.GUIHandles.FutureTrialLine = line([Xdata,Xdata],[Ydata,Ydata],'LineStyle','none','Marker','o','MarkerEdge','b','MarkerFace','b', 'MarkerSize',6);
        BpodSystem.GUIHandles.CurrentTrialCircle = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','k','MarkerFace',[1 1 1], 'MarkerSize',6);
        BpodSystem.GUIHandles.CurrentTrialCross = line([0,0],[0,0], 'LineStyle','none','Marker','+','MarkerEdge','k','MarkerFace',[1 1 1], 'MarkerSize',6);
        BpodSystem.GUIHandles.UnpunishedErrorLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','r','MarkerFace',[1 1 1], 'MarkerSize',6);
        BpodSystem.GUIHandles.PunishedErrorLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','r','MarkerFace','r', 'MarkerSize',6);
        BpodSystem.GUIHandles.RewardedCorrectLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','g','MarkerFace','g', 'MarkerSize',6);
        BpodSystem.GUIHandles.UnrewardedCorrectLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','g','MarkerFace',[1 1 1], 'MarkerSize',6);
        BpodSystem.GUIHandles.NoResponseLine = line([0,0],[0,0], 'LineStyle','none','Marker','o','MarkerEdge','b','MarkerFace',[1 1 1], 'MarkerSize',6);
        if verLessThan('matlab','8.0'); % Use optimal split function if possible
            BpodSystem.GUIHandles.TTOP_Ylabel = Split(num2str(MaxTrialType:-1:-1));
        else
            BpodSystem.GUIHandles.TTOP_Ylabel = strsplit(num2str(MaxTrialType:-1:-1));
        end
        set(AxesHandle,'TickDir', 'out','YLim', [-MaxTrialType-.5, -.5], 'YTick', -MaxTrialType:1:-1,'YTickLabel', BpodSystem.GUIHandles.TTOP_Ylabel, 'FontSize', 16);
        xlabel(AxesHandle, 'Trial#', 'FontSize', 18);
        ylabel(AxesHandle, 'Trial Type', 'FontSize', 16);
        hold(AxesHandle, 'on');
        
    case 'update'
        CurrentTrial = varargin{1};
        TrialTypeList = varargin{2};
        OutcomeRecord = varargin{3};
        MaxTrialType = max(TrialTypeList);
        set(AxesHandle,'YLim',[-MaxTrialType-.5, -.5], 'YTick', -MaxTrialType:1:-1,'YTickLabel', BpodSystem.GUIHandles.TTOP_Ylabel);
        if CurrentTrial<1
            CurrentTrial = 1;
        end
        TrialTypeList  = -TrialTypeList;
        
        % recompute xlim
        [mn, mx] = rescaleX(AxesHandle,CurrentTrial,nTrialsToShow);
        
        %plot future trials
        offset = mn-1;
        FutureTrialsIndx = CurrentTrial:mx;
        Xdata = FutureTrialsIndx; Ydata = TrialTypeList(Xdata);
        DisplayXdata = Xdata-offset;
        set(BpodSystem.GUIHandles.FutureTrialLine, 'xdata', [DisplayXdata,DisplayXdata], 'ydata', [Ydata,Ydata]);
        %Plot current trial
        displayCurrentTrial = CurrentTrial-offset;
        set(BpodSystem.GUIHandles.CurrentTrialCircle, 'xdata', [displayCurrentTrial,displayCurrentTrial], 'ydata', [TrialTypeList(CurrentTrial),TrialTypeList(CurrentTrial)]);
        set(BpodSystem.GUIHandles.CurrentTrialCross, 'xdata', [displayCurrentTrial,displayCurrentTrial], 'ydata', [TrialTypeList(CurrentTrial),TrialTypeList(CurrentTrial)]);
        
        %Plot past trials
        if ~isempty(OutcomeRecord)
            indxToPlot = mn:CurrentTrial-1;
            %Plot Error, unpunished
            EarlyWithdrawalTrialsIndx =(OutcomeRecord(indxToPlot) == -1);
            Xdata = indxToPlot(EarlyWithdrawalTrialsIndx); Ydata = TrialTypeList(Xdata);
            DispData = Xdata-offset;
            set(BpodSystem.GUIHandles.UnpunishedErrorLine, 'xdata', [DispData,DispData], 'ydata', [Ydata,Ydata]);
            %Plot Error, punished
            InCorrectTrialsIndx = (OutcomeRecord(indxToPlot) == 0);
            Xdata = indxToPlot(InCorrectTrialsIndx); Ydata = TrialTypeList(Xdata);
            DispData = Xdata-offset;
            set(BpodSystem.GUIHandles.PunishedErrorLine, 'xdata', [DispData,DispData], 'ydata', [Ydata,Ydata]);
            %Plot Correct, rewarded
            CorrectTrialsIndx = (OutcomeRecord(indxToPlot) == 1);
            Xdata = indxToPlot(CorrectTrialsIndx); Ydata = TrialTypeList(Xdata);
            DispData = Xdata-offset;
            set(BpodSystem.GUIHandles.RewardedCorrectLine, 'xdata', [DispData,DispData], 'ydata', [Ydata,Ydata]);
            %Plot Correct, unrewarded
            UnrewardedTrialsIndx = (OutcomeRecord(indxToPlot) == 2);
            Xdata = indxToPlot(UnrewardedTrialsIndx); Ydata = TrialTypeList(Xdata);
            DispData = Xdata-offset;
            set(BpodSystem.GUIHandles.UnrewardedCorrectLine, 'xdata', [DispData,DispData], 'ydata', [Ydata,Ydata]);
            %Plot DidNotChoose
            DidNotChooseTrialsIndx = (OutcomeRecord(indxToPlot) == 3);
            Xdata = indxToPlot(DidNotChooseTrialsIndx); Ydata = TrialTypeList(Xdata);
            DispData = Xdata-offset;
            set(BpodSystem.GUIHandles.NoResponseLine, 'xdata', [DispData,DispData], 'ydata', [Ydata,Ydata]);
        end
end

end

function [mn,mx] = rescaleX(AxesHandle,CurrentTrial,nTrialsToShow)
FractionWindowStickpoint = .75; % After this fraction of visible trials, the trial position in the window "sticks" and the window begins to slide through trials.
mn = max(round(CurrentTrial - FractionWindowStickpoint*nTrialsToShow),1);
mx = mn + nTrialsToShow - 1;
%set(AxesHandle,'XLim',[mn-1 mx+1]); Replaced this with a trimmed "display" copy of the data for speed - JS 2017
end

function SplitString = Split(s)
    w = isspace(s);            
    if any(w)
        % decide the positions of terms        
        dw = diff(w);
        sp = [1, find(dw == -1) + 1];     % start positions of terms
        ep = [find(dw == 1), length(s)];  % end positions of terms

        % extract the terms        
        nt = numel(sp);
        SplitString = cell(1, nt);
        for i = 1 : nt
            SplitString{i} = s(sp(i):ep(i));
        end                
    else
        SplitString = {s};
    end
end
