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

function PerformancePlot(op, varargin)

global BpodSystem % Import the global BpodSystem object

switch op
    case 'init'
        BpodSystem.ProtocolFigures.PerformancePlotFig = figure('Position', [100 100 1000 350],'name',...
            'Performance plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off', 'Units', 'Pixels');
        BpodSystem.GUIHandles.PerformancePlot = axes('Position', [.11 .27 .76 .73], 'Units', 'Pixels');
        trialTypeGroups = varargin{1};
        nTrialTypeGroups = length(trialTypeGroups);
        trialGroupNames = varargin{2};
        nTrialsToShow = 10; %default number of trials to display
        if nargin > 2
            windowSize = varargin{3};
        else
            windowSize = 30; % default window size (in trials)
        end
        BpodSystem.GUIData.PerformancePlot.WindowSize = windowSize;
        axes(BpodSystem.GUIHandles.PerformancePlot);
        BpodSystem.GUIHandles.PerformancePlotLines = zeros(1,nTrialTypeGroups+1);
        BpodSystem.GUIHandles.PerformancePlotLines(1) = line([0,0],[0,0],'Marker','s','MarkerEdge','k',...
                                                             'MarkerFace','k', 'LineStyle', 'none');
        BpodSystem.GUIData.PerformancePlot.AverageLineData = nan(1,10000);
        BpodSystem.GUIData.PerformancePlot.IncompleteLineData = nan(1,10000);
        BpodSystem.GUIData.PerformancePlot.LineData = nan(nTrialTypeGroups,10000);
        BpodSystem.GUIData.TrialTypeGroups = trialTypeGroups;
        BpodSystem.GUIData.nTrialTypeGroups = nTrialTypeGroups;
        trialGroupColors = {[1 .4 0], [0 .5 1], [0 .5 .5], [.5 .5 0], [.5 0 .5], [.5 1 .5]};
        for i = 1:nTrialTypeGroups
            BpodSystem.GUIHandles.PerformancePlotLines(i+1) = line([0,0],[0,0],'Marker', 's', 'MarkerEdge', 'k',... 
                                                                   'MarkerFace', trialGroupColors{i}, 'LineStyle', 'none');
        end
        BpodSystem.GUIHandles.PerformancePlotLines(i+2) = line([0,0],[0,0],'Marker','s','MarkerEdge','k',...
                                                               'MarkerFace','w', 'LineStyle', 'none');
        set(BpodSystem.GUIHandles.PerformancePlot,'TickDir', 'out','YLim', [0 1], 'YTick', [0 .5 1], ...
            'YTickLabel', {'0', '50', '100'}, 'XLim', [1 nTrialsToShow], 'FontSize', 16);
        xlabel(BpodSystem.GUIHandles.PerformancePlot, 'Trial#', 'FontSize', 18);
        ylabel(BpodSystem.GUIHandles.PerformancePlot, '% Correct', 'FontSize', 16);
        BpodSystem.GUIHandles.PerformancePlotText = text(250,100,['Insufficient data. ' num2str(windowSize) ' more trials...'],... 
                                                         'units', 'pixels', 'FontSize', 16);
        uicontrol('Position', [890 190 100 35], 'Style', 'text', 'FontSize', 16, 'String', 'View:');
        BpodSystem.GUIHandles.PerformancePlotnTrialsToShow = uicontrol('Position', [890 155 100 35], 'Style', 'edit',... 
                                                             'FontSize', 16, 'String', num2str(nTrialsToShow),... 
                                                             'BackgroundColor', 'white');
        uicontrol('Position', [890 120 100 35], 'Style', 'text', 'FontSize', 16, 'String', 'trials');
        trialTypeString = cell(1,nTrialTypeGroups+1);
        trialTypeString{1} = 'Average';
        for i = 2:nTrialTypeGroups+1
            trialTypeString{i} = trialGroupNames{i-1};
        end
        trialTypeString{i+1} = '%Incomplete';
        legend(trialTypeString,'Location','northoutside','Orientation','horizontal');
        
    case 'update'
        trialTypes = varargin{1};
        outcomes = varargin{2};
        nTrials = varargin{3};
        trialTypeGroups = BpodSystem.GUIData.TrialTypeGroups;
        nTrialTypeGroups = BpodSystem.GUIData.nTrialTypeGroups;
        windowSize = BpodSystem.GUIData.PerformancePlot.WindowSize;
        nTrialsToShow = get(BpodSystem.GUIHandles.PerformancePlotnTrialsToShow, 'String');
        testString = uint8(nTrialsToShow);
        if sum(testString>47 & testString<58) == length(testString)
            nTrialsToShow = str2double(nTrialsToShow);
        else
            nTrialsToShow = 200;
            set(BpodSystem.GUIHandles.PerformancePlotnTrialsToShow, 'String', '200');
        end
        if nTrials <= nTrialsToShow
            xData = 1:nTrialsToShow;
            set(BpodSystem.GUIHandles.PerformancePlot, 'XLim', [1 nTrialsToShow]);
        else
            xData = nTrials-nTrialsToShow+1:nTrials;
            set(BpodSystem.GUIHandles.PerformancePlot, 'XLim', [nTrials-nTrialsToShow+1 nTrials]);
        end
        if nTrials < windowSize
            set(BpodSystem.GUIHandles.PerformancePlotText, 'String', ['Insufficient data. ' num2str(windowSize-nTrials)... 
                                                                      ' more trials...']);
        else
            if nTrials == windowSize
                set(BpodSystem.GUIHandles.PerformancePlotText, 'String',' ');
            end
            trialTypes = trialTypes(1:nTrials);
            totalOutcomes = outcomes(nTrials-windowSize+1:nTrials);
            completedTrials = totalOutcomes>-1;
            for i = 1:nTrialTypeGroups
                thisGroupTrialTypes = trialTypeGroups{i};
                trialTypesInWindow = trialTypes(nTrials-windowSize+1:nTrials);
                thisGroupTrials = ismember(trialTypesInWindow, thisGroupTrialTypes);
                BpodSystem.GUIData.PerformancePlot.LineData(i,nTrials) = mean(totalOutcomes(completedTrials & thisGroupTrials));
                yData = BpodSystem.GUIData.PerformancePlot.LineData(i,:);
                yData = yData(xData);
                set(BpodSystem.GUIHandles.PerformancePlotLines(i+1), 'xdata', [xData,xData], 'ydata', [yData,yData]);
            end
            BpodSystem.GUIData.PerformancePlot.AverageLineData(nTrials) = mean(totalOutcomes(completedTrials));
            yData = BpodSystem.GUIData.PerformancePlot.AverageLineData;
            yData = yData(xData);
            set(BpodSystem.GUIHandles.PerformancePlotLines(1), 'xdata', [xData,xData], 'ydata', [yData,yData]);
            
            BpodSystem.GUIData.PerformancePlot.IncompleteLineData(nTrials) = sum(totalOutcomes==-1)/length(totalOutcomes);
            yData = BpodSystem.GUIData.PerformancePlot.IncompleteLineData;
            yData = yData(xData);
            set(BpodSystem.GUIHandles.PerformancePlotLines(i+2), 'xdata', [xData,xData], 'ydata', [yData,yData]);
        end
        
end