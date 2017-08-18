
function StimulusPlot(AxesHandle, Action, varargin)
%% 
% Plug in to Plot Stimulus
% AxesHandle = handle of axes to plot on
% Action = specific action for plot, "init" - initialize OR "update" -  update plot

%Example usage:
% StimulusPlot(AxesHandle,'init',Stimulus)

% Fede

%% Code Starts Here
global BpodSystem

switch Action
    case 'init'
        %initialize pokes plot

        axes(AxesHandle);
        
        nStim = varargin{1};
        
        %plot in specified axes
        
        for i=1:nStim
            BpodSystem.GUIHandles.Stimulus(i) = line([0 0],[0 0]);
        end
        
        BpodSystem.GUIHandles.RTline = line([0/0 0/0],[0 18],'Color',[1 0 0]);
        
        ylabel(AxesHandle, 'Frequency', 'FontSize', 18);
        xlabel(AxesHandle, 'Time', 'FontSize', 18);
        hold(AxesHandle, 'on');
        
    case 'update'

        Stimulus = varargin{1};
        StimulusDetails = varargin{2};
        
        for i=1:size(BpodSystem.GUIHandles.Stimulus,2)
            set(BpodSystem.GUIHandles.Stimulus(i),'XData', (1:size(Stimulus,2))/1920);
            set(BpodSystem.GUIHandles.Stimulus(i),'YData',Stimulus(i,:));
            if length(varargin)>2
                tDeliverStimulus = varargin{3};
                set(BpodSystem.GUIHandles.RTline,'XData',[tDeliverStimulus tDeliverStimulus]);
            end
        end
        
        set(BpodSystem.GUIHandles.StimulusPlot,'YLim',[1 18],'XLim', [1 size(Stimulus,2)]/1920); 
        
        title_str = [];
        fnames = fields(StimulusDetails);
        for i=1:length(fnames)
            title_str = [title_str ' ' fnames{i} ': ' num2str(StimulusDetails.(fnames{i}),'%2.2f')];
        end
        set(get(BpodSystem.GUIHandles.StimulusPlot, 'Title'), 'String', title_str);
end

