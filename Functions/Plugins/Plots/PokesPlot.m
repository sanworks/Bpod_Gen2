function PokesPlot(varargin)

global BpodSystem
    
action = varargin{1};

switch action

    %% init    
    case 'init'
        
        state_colors = varargin{2};
        poke_colors = varargin{3};

        BpodSystem.ProtocolFigures.PokesPlot = figure('Position', [50 50 300 700],'name','PokesPlot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'on');

        BpodSystem.GUIHandles.PokesPlot.StateColors= state_colors;
        BpodSystem.GUIHandles.PokesPlot.PokeColors= poke_colors;

        
        BpodSystem.GUIHandles.PokesPlot.AlignOnLabel = uicontrol('Style', 'text','String','align on:', 'Position', [30 70 60 20], 'FontWeight', 'normal', 'FontSize', 10,'FontName', 'Arial');
        BpodSystem.GUIHandles.PokesPlot.AlignOnMenu = uicontrol('Style', 'popupmenu','Value',2, 'String', fields(state_colors), 'Position', [95 70 150 20], 'FontWeight', 'normal', 'FontSize', 10, 'BackgroundColor','white', 'FontName', 'Arial','Callback', {@PokesPlot, 'alignon'});
        
        BpodSystem.GUIHandles.PokesPlot.LeftEdgeLabel = uicontrol('Style', 'text','String','start', 'Position', [30 35 40 20], 'FontWeight', 'normal', 'FontSize', 10,'FontName', 'Arial');
        BpodSystem.GUIHandles.PokesPlot.LeftEdge = uicontrol('Style', 'edit','String',-0.25, 'Position', [75 35 40 20], 'FontWeight', 'normal', 'FontSize', 10, 'BackgroundColor','white', 'FontName', 'Arial','Callback', {@PokesPlot, 'time_axis'});
        
        BpodSystem.GUIHandles.PokesPlot.LeftEdgeLabel = uicontrol('Style', 'text','String','end', 'Position', [30 10 40 20], 'FontWeight', 'normal', 'FontSize', 10, 'FontName', 'Arial');
        BpodSystem.GUIHandles.PokesPlot.RightEdge = uicontrol('Style', 'edit','String',2, 'Position', [75 10 40 20], 'FontWeight', 'normal', 'FontSize', 10, 'BackgroundColor','white', 'FontName', 'Arial','Callback', {@PokesPlot, 'time_axis'});
         
        BpodSystem.GUIHandles.PokesPlot.LastnLabel = uicontrol('Style', 'text','String','N trials', 'Position', [130 33 50 20], 'FontWeight', 'normal', 'FontSize', 10, 'FontName', 'Arial');
        BpodSystem.GUIHandles.PokesPlot.Lastn = uicontrol('Style', 'edit','String',10, 'Position', [185 35 40 20], 'FontWeight', 'normal', 'FontSize', 10, 'BackgroundColor','white', 'FontName', 'Arial','Callback', {@PokesPlot, 'time_axis'});
        
        BpodSystem.GUIHandles.PokesPlot.PokesPlotAxis = axes('Position', [0.1 0.38 0.8 0.54],'Color', 0.3*[1 1 1]);

        
        fnames = fieldnames(state_colors);
        for j=1:str2double(get(BpodSystem.GUIHandles.PokesPlot.Lastn, 'String'))
            for i=1:length(fnames)
                BpodSystem.GUIHandles.PokesPlot.StateHandle(j).(fnames{i}) = fill([(i-1) (i-1)+2 (i-1) (i-1)],[(j-1) (j-1) (j-1)+1 (j-1)+1],state_colors.(fnames{i}),'EdgeColor','none');
                set(BpodSystem.GUIHandles.PokesPlot.StateHandle(j).(fnames{i}),'Visible','off');
                hold on;
            end
        end
        
        axis([str2double(get(BpodSystem.GUIHandles.PokesPlot.LeftEdge,'String')) str2double(get(BpodSystem.GUIHandles.PokesPlot.RightEdge,'String')) 0 length(fnames)-1])
        
        BpodSystem.GUIHandles.PokesPlot.ColorAxis = axes('Position', [0.15 0.29 0.7 0.03]);
         
        % plot reference colors
        fnames = fieldnames(state_colors);
        for i=1:length(fnames)
            fill([i-0.9 i-0.9 i-0.1 i-0.1], [0 1 1 0], state_colors.(fnames{i}),'EdgeColor','none');
            if length(fnames{i})< 10
                legend = fnames{i};
            else
                legend = fnames{i}(1:10);
            end
            hold on; t = text(i-0.5, -0.5, legend);
            set(t, 'Interpreter', 'none', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', 'Rotation', 90);
            set(gca, 'Visible', 'off');
        end
        ylim([0 1]); xlim([0 length(fnames)]);
        
        
  %% update    
  case 'update'
      
    figure(BpodSystem.ProtocolFigures.PokesPlot);axes(BpodSystem.GUIHandles.PokesPlot.PokesPlotAxis)
    current_trial = BpodSystem.Data.nTrials;
    last_n = str2double(get(BpodSystem.GUIHandles.PokesPlot.Lastn,'String'));
    
%    fnames = fieldnames(BpodSystem.Data.RawEvents.Trial{1,BpodSystem.Data.nTrials}.States);
        
    for j=1:last_n
        
        fnames = fieldnames(BpodSystem.Data.RawEvents.Trial{1,BpodSystem.Data.nTrials}.States);
        trial_toplot = current_trial-j+1;
        
        if trial_toplot>0
            thisTrialStateNames = get(BpodSystem.GUIHandles.PokesPlot.AlignOnMenu,'String');
            thisStateName = thisTrialStateNames{get(BpodSystem.GUIHandles.PokesPlot.AlignOnMenu, 'Value')};
            aligning_time = BpodSystem.Data.RawEvents.Trial{trial_toplot}.States.(thisStateName)(1);
            
            for i=1:length(fnames)
                
                t = BpodSystem.Data.RawEvents.Trial{trial_toplot}.States.(fnames{i})-aligning_time;
                x_vertices = [t(1) t(2) t(2) t(1)]';
                y_vertices = [repmat(last_n-j,1,2)+0.1 repmat(last_n-j+1,1,2)-0.1]';
                
                if size(BpodSystem.GUIHandles.PokesPlot.StateHandle,2)<last_n % if the number of trial to plot (last_n) is changed from the gui.
                    BpodSystem.GUIHandles.PokesPlot.StateHandle(last_n).(fnames{i}) = fill([0 0 0 0],[0 0 0 0],BpodSystem.GUIHandles.PokesPlot.StateColors.(fnames{i}),'EdgeColor','none');
                end        
                
                if ~isfield(BpodSystem.GUIHandles.PokesPlot.StateHandle(last_n-j+1),fnames{i}) %if the field was not initialized, paint it white
                    BpodSystem.GUIHandles.PokesPlot.StateHandle(last_n-j+1).(fnames{i}) = fill([0 0 0 0],[0 0 0 0],[1 1 1],'EdgeColor','none');
                    set(BpodSystem.GUIHandles.PokesPlot.StateHandle(last_n-j+1).(fnames{i}), 'Vertices', [x_vertices y_vertices]);
                end
                
                if isempty(BpodSystem.GUIHandles.PokesPlot.StateHandle(last_n-j+1).(fnames{i})) % if the number of trial to plot (last_n) is changed from the gui.
                    BpodSystem.GUIHandles.PokesPlot.StateHandle(last_n-j+1).(fnames{i}) = fill([0 0 0 0],[0 0 0 0],BpodSystem.GUIHandles.PokesPlot.StateColors.(fnames{i}),'EdgeColor','none');
                end                
                set(BpodSystem.GUIHandles.PokesPlot.StateHandle(last_n-j+1).(fnames{i}),'Vertices', [x_vertices y_vertices],'Visible', 'on');
            end
        end
    end
    
    set(BpodSystem.GUIHandles.PokesPlot.PokesPlotAxis, 'XLim', [str2double(get(BpodSystem.GUIHandles.PokesPlot.LeftEdge,'String')), str2double(get(BpodSystem.GUIHandles.PokesPlot.RightEdge,'String'))]);
    set(BpodSystem.GUIHandles.PokesPlot.PokesPlotAxis,'YLim', [0 last_n]);
end
