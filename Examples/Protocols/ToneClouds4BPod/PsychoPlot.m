function PsychoPlot(AxesHandle, Action, varargin)
%%
% Plug in to Plot Psychometric curve in real time
% AxesHandle = handle of axes to plot on
% Action = specific action for plot, "init" - initialize OR "update" -  update plot

%Example usage:
% PsychoPlot(AxesHandle,'init')
% PsychoPlot(AxesHandle,'update',TrialTypeSides,OutcomeRecord)

% varargins:
% TrialTypeSides: Vector of 0's (right) or 1's (left) to indicate reward side (0,1), or 'None' to plot trial types individually
% OutcomeRecord:  Vector of trial outcomes
% EvidenceStrength: Vector of evidence strengths

% Adapted from BControl (PsychCurvePlotSection.m)
% F.Carnevale 2015.Feb.17

%% Code Starts Here
global BpodSystem
bin_size = 0.1;
switch Action
    case 'init'
        axes(AxesHandle);
        %plot in specified axes
        Xdata = -1:bin_size:1; Ydata=nan(1,size(Xdata,2));
        BpodSystem.GUIHandles.PsychometricLine = line([Xdata,Xdata],[Ydata,Ydata],'LineStyle','none','Marker','o','MarkerEdge','k','MarkerFace','k', 'MarkerSize',6);
        BpodSystem.GUIHandles.PsychometricData = [Xdata',Ydata'];
        set(AxesHandle,'TickDir', 'out', 'XLim', [-1, 1],'YLim', [0, 1], 'FontSize', 15);
        xlabel(AxesHandle, 'Evidence Strength', 'FontSize', 15);
        ylabel(AxesHandle, 'P(Right)', 'FontSize', 15);
        hold(AxesHandle, 'on');
        
    case 'update'
        % Import variables
        CurrentTrial = varargin{1};
        SideList = varargin{2}(1:CurrentTrial);
        OutcomeRecord = varargin{3}(1:CurrentTrial);
        EvidenceStrength =  varargin{4}(1:CurrentTrial);
        SidedEvidenceStrength = EvidenceStrength;
        LeftTrials = (logical(SideList));
        SidedEvidenceStrength(LeftTrials) = EvidenceStrength(LeftTrials)*-1; % Convert to sided-evidence
        
        % Eliminate missed trials
        ValidTrials = OutcomeRecord > -1;
        SideList = SideList(ValidTrials);
        OutcomeRecord = OutcomeRecord(ValidTrials);
        SidedEvidenceStrength = SidedEvidenceStrength(ValidTrials);
        nTrials = sum(ValidTrials);
        LeftTrials = zeros(1,nTrials);
        LeftTrials((SideList == 0) & (OutcomeRecord == 1)) = 1;
        LeftTrials((SideList == 0) & (OutcomeRecord == 0)) = 0;
        LeftTrials((SideList == 1) & (OutcomeRecord == 1)) = 0;
        LeftTrials((SideList == 1) & (OutcomeRecord == 0)) = 1;
        
        Xdata = BpodSystem.GUIHandles.PsychometricData(:,1);
        Ydata = BpodSystem.GUIHandles.PsychometricData(:,2);
        nBins = length(Xdata);
        for i = 1:nBins
            Ydata(i) = mean(LeftTrials(SidedEvidenceStrength==Xdata(i)));
        end
        
        set(BpodSystem.GUIHandles.PsychometricLine, 'xdata', Xdata, 'ydata', Ydata);
        BpodSystem.GUIHandles.PsychometricData(:,1) = Xdata;
        BpodSystem.GUIHandles.PsychometricData(:,2) = Ydata;
        set(AxesHandle,'XLim',[-1 1], 'Ylim', [0 1]);
end

end

