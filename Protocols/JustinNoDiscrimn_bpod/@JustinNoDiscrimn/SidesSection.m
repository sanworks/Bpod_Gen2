% [x, y] = SidesSection(obj, action, x, y)
%
% Section that takes care of choosing the next correct side and keeping
% track of a plot of sides and hit/miss history.
%
% PARAMETERS:
% -----------
%
% obj      Default object argument.
%
% action   One of:
%            'init'      To initialise the section and set up the GUI
%                        for it; also calls 'choose_next_side' and
%                        'update_plot' (see below)
%
%            'reinit'    Delete all of this section's GUIs and data,
%                        and reinit, at the same position on the same
%                        figure as the original section GUI was placed.
%
%            'choose_next_side'  Picks what will be the next correct
%                        side.
%
%            'get_next_side'  Returns either 'l' for left or 'r' for right.
%
%            'update_plot'    Update plot that reports on sides and hit
%                        history
%
% x, y     Relevant to action = 'init'; they indicate the initial
%          position to place the GUI at, in the current figure window
%
% RETURNS:
% --------
%
% [x, y]   When action == 'init', returns x and y, pixel positions on
%          the current figure, updated after placing of this section's GUI.
%
% x        When action = 'get_next_side', x will be either 'l' for
%          left or 'r' for right.
%

function [x, y, WaterDeliverySPH, RelevantSideSPH] = SidesSection(obj, action, x, y)

GetSoloFunctionArgs;

global Solo_rootdir;

switch action

    case 'init',   % ------------ CASE INIT ----------------
        % Save the figure and the position in the figure where we are
        % going to start adding GUI elements:

        SoloParamHandle(obj, 'my_gui_info', 'value', [x y gcf]);

        % List of intended correct sides
        SoloParamHandle(obj, 'previous_sides', 'value', []);

        % Give read-only access to AnalysisSection.m:
        SoloFunctionAddVars('AnalysisSection', 'ro_args', 'previous_sides');

        %JPL - COULD BE USEFUL FOR NULLING OUT MEAN POLE POSITION
        %PREDICTION
        % -- Anti-bias method --
        MenuParam(obj, 'AntiBiasMethod', {'none','repeat mistake','null predict'}, 'none', ...
            x, y, 'TooltipString', 'Method for reducing bias');
        next_row(y);

        % -- Reward method --
        MenuParam(obj, 'WaterDeliverySPH',...
            {'nextLick', 'nextTouch',}, 2, x, y,...
            'label','WaterDelivery','TooltipString', 'Type of delivery');
        next_row(y);

        % --- Max times same pole position ---
        MenuParam(obj, 'MaxSame', {'1', '2', '3', '4', '5', '6', '7', 'Inf'}, 4, ...
            x, y, 'TooltipString', 'Maximum number of times the same position can appear sequentially');
        set_callback(MaxSame, {mfilename, 'update_rewardsides'});
        next_row(y);

        % --- Prob of choosing matched prediction trial ---
        NumeditParam(obj, 'predictProb', 1.0, x, y,...
            'label','predictProb'); next_row(y);
        set_callback(predictProb, {mfilename, 'updatePredictProb'});

        NumeditParam(obj, 'mismatchProb', 0, x, y,...
            'label','mismatchProb'); next_row(y);
        set_callback(mismatchProb, {mfilename, 'updateMismatchProb'});

        MenuParam(obj, 'RelevantSideSPH', {'left' 'right'}, 'left', x, y,...
            'label','RelevantSide');

        SidesSection(obj, 'choose_next_side');
        %SidesSection(obj, 'update_plot');

        % -- Fill RewardSideList (l: Left  r: Right) --
        SidesSection(obj,'update_rewardsides');



        %PLOTTING
        %JPL - moving this functionality into SidesPLotSection so it can exist as
        %a seperate figure

        %         %plot touches and no touches
        %         pos = get(gcf, 'Position');
        %         SoloParamHandle(obj, 'myaxes', 'saveable', 0, 'value', axes);
        %         set(value(myaxes), 'Units', 'pixels');
        %         set(value(myaxes), 'Position', [90 pos(4)-140 pos(3)-130 100]);
        %         set(value(myaxes), 'YTick', [1 2], 'YLim', [0.5 2.5], 'YTickLabel', ...
        %             {'Touch', 'No Touch'});

        %     NumeditParam(obj, 'ntrials', 100, x, y, ...
        %    'position', [5 pos(4)-100 40 40], 'labelpos', 'top', ...
        %    'TooltipString', 'How many trials to show in plot');
        %set_callback(ntrials, {mfilename, 'update_plot'});

        %xlabel('trial number');
        %SoloParamHandle(obj, 'previous_plot', 'saveable', 0);
        next_row(y);
        MenuParam(obj, 'sides_plot_show', {'view', 'hide'}, 'view', x, y, 'label', 'Show Sides Plot', 'TooltipString', 'Control motors');
        set_callback(sides_plot_show, {mfilename,'hide_show'});

        parentfig_x=x;parentfig_y=y;

        % ---  Make new window for sides plot
        %SidesPlotSection(obj, 'init',x,y,SidesList);

        SoloParamHandle(obj, 'sidesplotfig', 'saveable', 0);
        sidesplotfig.value = figure('Position', [500 500 660 420], 'Menubar', 'none',...
            'Toolbar', 'none','Name','Sides Plot','NumberTitle','off');

        x = 1; y = 1;
        %add code here for the plot...


        %hide tghe plot
        SidesSection(obj,'hide_show');


        x = parentfig_x; y = parentfig_y;
        set(0,'CurrentFigure',value(myfig));
        return;



    case 'apply_antibias'
        % -- If antibias, check if last response was a mistake --

        if(strcmp(value(AntiBiasMethod), 'repeat mistake'))
            if(~isempty(parsed_events.states.errortrial) |...
                    ~isempty(parsed_events.states.misstrial))
                NextTrial = n_done_trials;
                RewardSideList(NextTrial) = RewardSideList(NextTrial-1);
            end
        elseif (strcmp(value(AntiBiasMethod), 'null predict'))

            %JPL - seeks to null out any adaption of set point by using @antibias
            %plugin to constantly shift the running 'best estimate' of the
            %mean pole position. Needs three args: prob of a current pole
            %positions prediction probability, the hit history, and the
            %history of pole positions.

            [x, y, w, h] = AntibiasSection(obj, 'update',...
                predictProb, hitHistory, poleHistory);

        end
    case 'update_rewardsides'
        % -- Applying LeftProb (probability of left reward) --
        FutureIndexes = (n_done_trials+1:value(MaxTrials));
        %FutureLeftSides = rand(length(FutureIndexes),1)<value(LeftProb);

        %JPL - using 'left' as the port when only one port
        FutureLeftSides = rand(length(FutureIndexes),1)<value(predictProb)+value(mismatchProb);

        % -- Applying MaxSame (change trial if last N trials are the same) --
        if ~strcmp(value(MaxSame), 'inf')
            for ind=value(MaxSame)+1:length(FutureLeftSides)
                SumLastSides = sum(FutureLeftSides(ind-MaxSame:ind));
                if(SumLastSides==value(MaxSame)+1)
                    FutureLeftSides(ind)=0;
                elseif(SumLastSides==0)
                    FutureLeftSides(ind)=1;
                end
            end
        end

        SideLabels = 'rl';
        RewardSideList(FutureIndexes) = SideLabels(FutureLeftSides+1);

        SidesSection(obj,'updatePredictProb');
        SidesSection(obj,'updateMismatchProb');

        %JPL set a fraction of trials that a pole posn is predictable. Will
        %apply to ALL pole posns!

        %also sets the mismatch prob to the reciprocal of this value
        %automatically
    case 'updatePredictProb'

        updatePredictProb = value(predictProb);
        updateMismatchProb = 1-updatePredictProb;

        mismatchProb.value=updateMismatchProb;
        %SidesPlotSection(obj, 'update', n_done_trials, value(RewardSideList),[],...
        %    value(predictProb));

    case 'updateMismatchProb'

        updateMismatchProb = value(mismatchProb);
        updatePredictProb = 1-mismatchProb;

        predictProb.value=updatePredictProb;

        %SidesPlotSection(obj, 'update', n_done_trials, value(RewardSideList),[],...
        %    value(ProbingContextTrialsList));


    case 'hide_show'

        if strcmpi(value(sides_plot_show), 'hide')
            set(value(sidesplotfig), 'Visible', 'off');
        elseif strcmpi(value(sides_plot_show),'view')
            set(value(sidesplotfig),'Visible','on');
        end;
        return;

    case 'update'


    case 'reinit',
        currfig = gcf;

        % Get the original GUI position and figure:
        x = my_gui_info(1); y = my_gui_info(2); figure(my_gui_info(3));

        % Delete all SoloParamHandles who belong to this object and whose
        % fullname starts with the name of this mfile:
        delete_sphandle('owner', ['^@' class(obj) '$'], ...
            'fullname', ['^' mfilename]);

        % Reinitialise at the original GUI position and figure:
        [x, y] = feval(mfilename, obj, 'init', x, y);

        % Restore the current figure:
        figure(currfig);
end;


