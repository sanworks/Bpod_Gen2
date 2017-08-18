function PerformancePlot(op, varargin)
global BpodSystem
switch op
    case 'init'
        BpodSystem.ProtocolFigures.PerformancePlotFig = figure('Position', [100 100 1000 350],'name','Performance plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off', 'Units', 'Pixels');
        BpodSystem.GUIHandles.PerformancePlot = axes('Position', [.11 .27 .76 .73], 'Units', 'Pixels');
        TrialTypeGroups = varargin{1};
        nTrialTypeGroups = length(TrialTypeGroups);
        TrialGroupNames = varargin{2};
        nTrialsToShow = 10; %default number of trials to display
        if nargin > 2
            WindowSize = varargin{3};
        else
            WindowSize = 30; % default window size (in trials)
        end
        BpodSystem.GUIData.PerformancePlot.WindowSize = WindowSize;
        axes(BpodSystem.GUIHandles.PerformancePlot);
        BpodSystem.GUIHandles.PerformancePlotLines = zeros(1,nTrialTypeGroups+1);
        BpodSystem.GUIHandles.PerformancePlotLines(1) = line([0,0],[0,0],'Marker','s','MarkerEdge','k','MarkerFace','k', 'LineStyle', 'none');
        BpodSystem.GUIData.PerformancePlot.AverageLineData = nan(1,10000);
        BpodSystem.GUIData.PerformancePlot.IncompleteLineData = nan(1,10000);
        BpodSystem.GUIData.PerformancePlot.LineData = nan(nTrialTypeGroups,10000);
        BpodSystem.GUIData.TrialTypeGroups = TrialTypeGroups;
        BpodSystem.GUIData.nTrialTypeGroups = nTrialTypeGroups;
        TrialGroupColors = {[1 .4 0], [0 .5 1], [0 .5 .5], [.5 .5 0], [.5 0 .5], [.5 1 .5]};
        for i = 1:nTrialTypeGroups
            BpodSystem.GUIHandles.PerformancePlotLines(i+1) = line([0,0],[0,0],'Marker', 's', 'MarkerEdge', 'k', 'MarkerFace', TrialGroupColors{i}, 'LineStyle', 'none');
        end
        BpodSystem.GUIHandles.PerformancePlotLines(i+2) = line([0,0],[0,0],'Marker','s','MarkerEdge','k','MarkerFace','w', 'LineStyle', 'none');
        set(BpodSystem.GUIHandles.PerformancePlot,'TickDir', 'out','YLim', [0 1], 'YTick', [0 .5 1], ...
            'YTickLabel', {'0', '50', '100'}, 'XLim', [1 nTrialsToShow], 'FontSize', 16);
        xlabel(BpodSystem.GUIHandles.PerformancePlot, 'Trial#', 'FontSize', 18);
        ylabel(BpodSystem.GUIHandles.PerformancePlot, '% Correct', 'FontSize', 16);
        BpodSystem.GUIHandles.PerformancePlotText = text(250,100,['Insufficient data. ' num2str(WindowSize) ' more trials...'], 'units', 'pixels', 'FontSize', 16);
        uicontrol('Position', [890 190 100 35], 'Style', 'text', 'FontSize', 16, 'String', 'View:');
        BpodSystem.GUIHandles.PerformancePlotnTrialsToShow = uicontrol('Position', [890 155 100 35], 'Style', 'edit', 'FontSize', 16, 'String', num2str(nTrialsToShow), 'BackgroundColor', 'white');
        uicontrol('Position', [890 120 100 35], 'Style', 'text', 'FontSize', 16, 'String', 'trials');
        TrialTypeString = cell(1,nTrialTypeGroups+1);
        TrialTypeString{1} = 'Average';
        for i = 2:nTrialTypeGroups+1
            TrialTypeString{i} = TrialGroupNames{i-1};
        end
        TrialTypeString{i+1} = '%Incomplete';
        legend(TrialTypeString,'Location','northoutside','Orientation','horizontal','boxoff');
    case 'update'
        TrialTypes = varargin{1};
        Outcomes = varargin{2};
        nTrials = varargin{3};
        TrialTypeGroups = BpodSystem.GUIData.TrialTypeGroups;
        nTrialTypeGroups = BpodSystem.GUIData.nTrialTypeGroups;
        WindowSize = BpodSystem.GUIData.PerformancePlot.WindowSize;
        nTrialsToShow = get(BpodSystem.GUIHandles.PerformancePlotnTrialsToShow, 'String');
        TestString = uint8(nTrialsToShow);
        if sum(TestString>47 & TestString<58) == length(TestString)
            nTrialsToShow = str2double(nTrialsToShow);
        else
            nTrialsToShow = 200;
            set(BpodSystem.GUIHandles.PerformancePlotnTrialsToShow, 'String', '200');
        end
        if nTrials <= nTrialsToShow
            Xdata = 1:nTrialsToShow;
            set(BpodSystem.GUIHandles.PerformancePlot, 'XLim', [1 nTrialsToShow]);
        else
            Xdata = nTrials-nTrialsToShow+1:nTrials;
            set(BpodSystem.GUIHandles.PerformancePlot, 'XLim', [nTrials-nTrialsToShow+1 nTrials]);
        end
        if nTrials < WindowSize
            set(BpodSystem.GUIHandles.PerformancePlotText, 'String', ['Insufficient data. ' num2str(WindowSize-nTrials) ' more trials...']);
        else
            if nTrials == WindowSize
                set(BpodSystem.GUIHandles.PerformancePlotText, 'String',' ');
            end
            TrialTypes = TrialTypes(1:nTrials);
            TotalOutcomes = Outcomes(nTrials-WindowSize+1:nTrials);
            CompletedTrials = TotalOutcomes>-1;
            for i = 1:nTrialTypeGroups
                ThisGroupTrialTypes = TrialTypeGroups{i};
                TrialTypesInWindow = TrialTypes(nTrials-WindowSize+1:nTrials);
                ThisGroupTrials = ismember(TrialTypesInWindow, ThisGroupTrialTypes);
                BpodSystem.GUIData.PerformancePlot.LineData(i,nTrials) = mean(TotalOutcomes(CompletedTrials & ThisGroupTrials));
                Ydata = BpodSystem.GUIData.PerformancePlot.LineData(i,:);
                Ydata = Ydata(Xdata);
                set(BpodSystem.GUIHandles.PerformancePlotLines(i+1), 'xdata', [Xdata,Xdata], 'ydata', [Ydata,Ydata]);
            end
            BpodSystem.GUIData.PerformancePlot.AverageLineData(nTrials) = mean(TotalOutcomes(CompletedTrials));
            Ydata = BpodSystem.GUIData.PerformancePlot.AverageLineData;
            Ydata = Ydata(Xdata);
            set(BpodSystem.GUIHandles.PerformancePlotLines(1), 'xdata', [Xdata,Xdata], 'ydata', [Ydata,Ydata]);
            
            BpodSystem.GUIData.PerformancePlot.IncompleteLineData(nTrials) = sum(TotalOutcomes==-1)/length(TotalOutcomes);
            Ydata = BpodSystem.GUIData.PerformancePlot.IncompleteLineData;
            Ydata = Ydata(Xdata);
            set(BpodSystem.GUIHandles.PerformancePlotLines(i+2), 'xdata', [Xdata,Xdata], 'ydata', [Ydata,Ydata]);
        end
        
end