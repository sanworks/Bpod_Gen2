% [x, y] = MotorsSection(obj, action, x, y)
%
% Section that takes care of controlling the stepper motors.
%
%
% PARAMETERS:
% -----------
%
% obj      Default object argument.
%
% action   One of:
%            'init'      To initialise the section and set up the GUI
%                        for it;
%
%            'reinit'    Delete all of this section's GUIs and data,
%                        and reinit, at the same position on the same
%                        figure as the original section GUI was placed.
%
%            Several other actions are available (see code of this file).
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

function [x, y] = MotorsSection(obj, action, x, y)

GetSoloFunctionArgs;

%%% Imported objects (see protocol constructor):
%%%  'RelevantSide'
%%%  'MaxTrials'
%%%  'PsychCurveMode'
%%% ' PoleCueList'
%%% ' PolePosnList' which is empty at init, and gets filled here

%global Solo_rootdir;
%global Solo_Try_Catch_Flag
global pole_motors_properties;
global init_motors_properties;
global pole_motors;
global init_motors;
global private_soloparam_list;

%JPL - motors section given access to sound section to see which cues are
%available

%JPL - above globals used to be setup in mystartup.m...now they are here
%for now

%pole motors
pole_motors_properties=[];
pole_motors_properties.type = '@ZaberTCD1000';
pole_motors_properties.port = 'COM1';
pole_motors_properties.axial_motor_num=2;
pole_motors_properties.radial_motor_num=1;

%lickport motors
%lickport_motors_properties=[];
%lickport_motors_properties.type = '@ZaberTCD1000';
%lickport_motors_properties.port = 'COM2';
%lickport_motors_properties.axial_motor_num=1;
%lickport_motors_properties.radial_motor_num=2;

%rear init motor
%init_motors_properties=[];
%init_motors_properties.type = '@ZaberTCD1000';
%init_motors_properties.port = 'COM3';
%nit_motors_properties.num=1;

switch action

    case 'init',   % ------------ CASE INIT ----------------

        %initialize the pole motor/s
        if strcmp(pole_motors_properties.type,'@FakeZaberTCD1000')
            pole_motors=FakeZaberTCD1000;
        else
            pole_motors=ZaberTCD1000(pole_motors_properties.port);
        end
        serial_open(pole_motors);

        %         %JPL - other motors disabled for now...since they dont exist!
        %         %initialize the lickport motor/s
        %         if strcmp(lickport_motors_properties.type,'@FakeZaberTCD1000')
        %             lickport_motors=FakeZaberTCD1000;
        %         else
        %             lickport_motors=ZaberTCD1000(pole_motors_properties.port);
        %         end
        %         serial_open(lickport_motors);
        %
        %         %initialize the init pole motor/s
        %         if strcmp(init_motors_properties.type,'@FakeZaberTCD1000')
        %             init_motors=FakeZaberTCD1000;
        %         else
        %             init_motors=ZaberTCD1000(init_motors_properties.port);
        %         end
        %         serial_open(init_motors_axial);


        % Save the figure and the position in the figure where we are
        % going to start adding GUI elements:
        SoloParamHandle(obj, 'my_gui_info', 'value', [x y gcf]); next_row(y,1.5);

        % Set limits in microsteps for actuator. Range of actuator is greater than range of
        % our  sliders, so must limit to prevent damage.  This limit is also coded into Zaber
        % TCD1000 firmware, but exists here to keep GUI in range. If a command outside this range (0-value)
        % motor driver gives error and no movement is made.
        SoloParamHandle(obj, 'motor_max_position', 'value', 195000);
        SoloParamHandle(obj, 'trial_ready_times', 'value', 0);

        MenuParam(obj, 'motor_show', {'view', 'hide'}, 'view', x, y, 'label', 'Motor Control', 'TooltipString', 'Control motors');
        set_callback(motor_show, {mfilename,'hide_show'});

        next_row(y);
        SubheaderParam(obj,'sectiontitle','Motor Control',x,y);

        parentfig_x=x;parentfig_y=y;


        % ---  Make new window for motor configuration
        SoloParamHandle(obj, 'motorfig', 'saveable', 0);
        motorfig.value = figure('Position', [3 500 660 420], 'Menubar', 'none',...
            'Toolbar', 'none','Name','Motor Control','NumberTitle','off');

        x = 1; y = 1;
        %%%%POLE MOTOR/S
        PushbuttonParam(obj, 'pole_motors_serial_reset', x, y, 'label', 'Reset pole serial port',...
            'position',[x, y, 110, 20]);
        set_callback(pole_motors_serial_reset, {mfilename, 'pole_motor_serial_reset'});
        next_row(y);

        PushbuttonParam(obj, 'pole_motors_home', x, y, 'label', 'Home Pole Motors',...
            'position',[x, y, 110, 20]);
        set_callback(pole_motors_home, {mfilename, 'pole_motors_home'});
        next_row(y);

        PushbuttonParam(obj, 'pole_motors_stop', x, y, 'label', 'Stop Pole Motors',...
            'position',[x, y, 110, 20]);
        set_callback(pole_motors_stop, {mfilename, 'pole_motor_axial_stop'});
        next_row(y);

        PushbuttonParam(obj, 'pole_motors_reset', x, y, 'label', 'Reset Pole Motors',...
            'position',[x, y, 110, 20]);
        set_callback(pole_motors_reset, {mfilename, 'pole_motors_reset'});

        next_row(y);
        next_row(y);
        next_row(y);
        next_row(y);
        next_row(y);
        next_row(y);
        next_row(y);

        %JPL - disabled for now, they dont exist
        %%%%INIT MOTOR/S
        PushbuttonParam(obj, 'init_motors_serial_reset', x, y, 'label', 'Reset init serial port',...
            'position',[x, y, 110, 20]);
        set_callback(init_motors_serial_reset, {mfilename, 'init_motor_serial_reset'});
        next_row(y);

        PushbuttonParam(obj, 'init_motors_home', x, y, 'label', 'Home init Motors',...
            'position',[x, y, 110, 20]);
        set_callback(init_motors_home, {mfilename, 'init_motors_home'});
        next_row(y);

        PushbuttonParam(obj, 'init_motors_stop', x, y, 'label', 'Stop init Motors',...
            'position',[x, y, 110, 20]);
        set_callback(init_motors_stop, {mfilename, 'init_motor_axial_stop'});
        next_row(y);

        PushbuttonParam(obj, 'init_motors_reset', x, y, 'label', 'Reset init Motors',...
            'position',[x, y, 110, 20]);
        set_callback(init_motors_reset, {mfilename, 'init_motors_reset'});
        next_row(y);
        next_row(y);
        SubheaderParam(obj,'title','Init Pole Positions Section',x,y,'width',600)
        next_row(y);

        %%%%LICKPORT MOTOR/S
        PushbuttonParam(obj, 'lickport_motors_serial_reset', x, y, 'label', 'Reset lickport serial port',...
            'position',[x, y, 110, 20]);
        set_callback(lickport_motors_serial_reset, {mfilename, 'lickport_motor_serial_reset'});
        next_row(y);

        PushbuttonParam(obj, 'lickport_motors_home', x, y, 'label', 'Home lickport Motors',...
            'position',[x, y, 110, 20]);
        set_callback(lickport_motors_home, {mfilename, 'lickport_motors_home'});
        next_row(y);

        PushbuttonParam(obj, 'lickport_motors_stop', x, y, 'label', 'Stop lickport Motors',...
            'position',[x, y, 110, 20]);
        set_callback(lickport_motors_stop, {mfilename, 'lickport_motor_axial_stop'});
        next_row(y);

        PushbuttonParam(obj, 'lickport_motors_reset', x, y, 'label', 'Reset lickport Motors',...
            'position',[x, y, 110, 20]);
        set_callback(lickport_motors_reset, {mfilename, 'lickport_motors_reset'});
        next_row(y);

        y=2;
        x=x+120;

        %%%% SECTION FOR ASSOCIATING POLE POSITIONS WITH SOUND CUES
        %axial position names
        axialPos = {'axial_pos1','axial_pos2','axial_pos3','axial_pos4',...
            'axial_pos5','axial_pos6','axial_pos7','axial_pos8'};


        y1 = y;
        y2 = y1+20;
        initposvec=[5 6 7 8 9 10 11 12];

        cueIdx=1;
        for i = 1:8 % 8 axial pole positions
            NumeditParam(obj, axialPos{i}, initposvec(i), x, y, 'position', [x+30*(i-1) y1 35 20],...
                'label','', 'labelfraction', 0.05);
            set_callback(eval(['axial_pos' num2str(i)]),{mfilename, 'update_active_locs'});

            PolePosnList.axial.name{i}=axialPos{i};
            PolePosnList.axial.value{i}=value(eval([axialPos{i}]));

        end

        next_row(y);

        SubheaderParam(obj,'title','Axial Position',x,y,'width',240)

        %%%RADIAL
        %radial position names
        radialPos = {'radial_pos1','radial_pos2','radial_pos3',...
            'radial_pos4','radial_pos5','radial_pos6','radial_pos7','radial_pos8'};
        initposvec=[14 14 16 16 18 18 20 20];
        next_row(y);

        for i = 1:8 % 8 radial pole positions
            NumeditParam(obj, radialPos{i}, initposvec(i), x, y, 'position', [x+30*(i-1) y 35 20],...
                'label','', 'labelfraction', 0.05);
            set_callback(eval(['radial_pos' num2str(i)]),{mfilename, 'update_active_locs'});

            PolePosnList.radial.name{i}=radialPos{i};
            PolePosnList.radial.value{i}=value(eval([radialPos{i}]));

        end

        SubheaderParam(obj,'title','Radial Pole Positions',x,y2+40,'width',240)

        %JPL - section for motor-cue associations---might be moved
        %eventually

        x=x+250;
        y=2;

        %cues - eventuallyget this from the cues that are currently enabled
        %in the sound section
        cues = {'cue_1','cue_2','cue_3','cue_4','cue_5','cue_6','cue_7',...
            'cue_8','none'};

        balances = {'C','L','R'};

        %active axial locations for poles
        axialVals=cell2num(PolePosnList.axial.value);
        axialActiveInd=~isnan(axialVals);
        axialActive=axialVals(axialActiveInd);

        %active radial locations for  poles
        radialVals=cell2num(PolePosnList.radial.value);
        radialActiveInd=~isnan(radialVals);
        radialActive=radialVals(radialActiveInd);

        %make 2xN matrix of active pole locations. 1st col is axial, scond
        %col is radial
        axialActive_temp=repmat(axialActive,[numel(radialActive) 1]);
        radialActive_temp=repmat(radialActive,1,numel(axialActive));

        active_locations.positions=[axialActive_temp(:) radialActive_temp'];
        active_ids=1:1:length(active_locations.positions);

        %these are essentially default settings. Can reset this later
        %through a button.
        for g=1:1:numel(active_ids)
            active_locations.id{g}=g;
            active_locations.name{g} = ['pos_' num2str(g)];
            active_locations.axial{g}=active_locations.positions(g,1);
            active_locations.radial{g}=active_locations.positions(g,2);
            active_locations.cue_id{g} = 'cue_1';
            active_locations.cue_balance{g} = 'C';
            active_locations.cue_volume{g} = 0.001;
            active_locations.go_nogo{g} = 'go';
        end
        currentPolePosition = [ ];
        currentPoleId = [ ];
        currentPoleCueId = '';
        %make this a SoloParamHAndle
        SoloParamHandle(obj,'active_locations','value',active_locations);
        
        SoloParamHandle(obj,'currentPolePosition','value',[]);
        SoloParamHandle(obj,'currentPoleId','value',[]);
        SoloParamHandle(obj,'currentPoleCueId','value',[]);
        
        MenuParam(obj, 'Positions', value(active_locations.name(:)), 'pos_1', ...
            x, y,'position', [x y 120 20], 'TooltipString', 'Select active position');
        set_callback(Positions, {mfilename, 'update_loc_data_display'});

        x=x+121;

        %toggle the display of a table of current active positions and
        %their properties (cue associations, cue properties, probability of
        %occurance, etc)

        ToggleParam(obj, 'Position_Cue_list', 0, x, y, 'OnString', 'Loc. Props.', ...
            'position', [x, y, 100, 20],'OffString', 'Loc. Props. hidden', 'TooltipString', 'Show/Hide Pole-Cue list window');
        set_callback(Position_Cue_list, {mfilename, 'show_hide_positions'});

        parentfig_x=x;parentfig_y=y;

        %         %JPL - doesnt really work yet
        %         % ---  Make new window for pole position configuration
        %         SoloParamHandle(obj, 'posfig', 'saveable', 0);
        %         posfig.value = figure('Position', [3 500 300 300], 'Menubar', 'none',...
        %             'Toolbar', 'none','Name','Pole Position Settings','NumberTitle','off');
        %
        %         %TextBoxParam(obj, 'pos_props_list', active_locations, x, y,...
        %         %    'nlines',numel(active_locations.id));
        %
        %         x = 1; y = 1;
        %
        %         %close the position list
        %         set(value(posfig), 'Visible', 'off');
        %
        %         x=parentfig_x;
        %         y=parentfig_y;

        %%%%%%%back to main motor figure %%%%%%%%%%%%
        x=x-122;
        next_row(y);
        y=y+1;

        NumeditParam(obj,'axial_position',cell2num(active_locations.axial(find(strcmpi(value(Positions)...
            ,active_locations.name(:))==1))),...
            x,y,'label','axial', ...
            'TooltipString', 'Axial motor setting for this location',...
            'position',[x, y, 70, 20],'labelfraction',0.4);
        %set_callback(axial_pole_motor_position, {mfilename, 'axial_pole_motor_position'});
        x=x+75;

        NumeditParam(obj,'radial_position',cell2num(active_locations.radial(find(strcmpi(value(Positions)...
            ,active_locations.name(:))==1))),...
            x,y,'label','radial', ...
            'TooltipString', 'Axial motor setting for this location',...
            'position',[x, y, 70, 20],'labelfraction',0.4);
        %set_callback(radial_pole_motor_position, {mfilename, 'radial_pole_motor_position'});
        x=x+72;

        PushbuttonParam(obj, 'move_to_loc', x, y, 'label', 'Move',...
            'position',[x, y, 70, 20]);
        set_callback(move_to_loc, {mfilename, 'move_test'});


        x=x-147;
        next_row(y);
        y=y+1;
        MenuParam(obj,'cue_id',cues,'cue_1',x,y,'label','cue', ...
            'TooltipString', 'Cue ID for this location',...
            'position',[x, y, 75, 20],'labelfraction',0.3);
        set_callback(cue_id, {mfilename, 'update_loc_data'});
        x=x+75;
        MenuParam(obj,'cue_bal',balances,'C',x,y,'label','bal.', ...
            'TooltipString', 'Cue balance for this location',...
            'position',[x, y, 75, 20],'labelfraction',0.3);
        set_callback(cue_bal, {mfilename, 'update_loc_data'});
        x=x+72;
        NumeditParam(obj,'cue_vol',0.001,x,y,'label','vol.', ...
            'TooltipString', 'Cue volume for this location',...
            'position',[x, y, 75, 20],'labelfraction',0.3);
        set_callback(cue_vol, {mfilename, 'update_loc_data'});

        x=x-150;
        next_row(y);
        y=y+1;

        PushbuttonParam(obj, 'make_go', x, y, 'label', 'Make Go',...
            'position',[x, y, 75, 20]);
        set_callback(make_go, {mfilename, 'make_go'});
        x=x+76;

        PushbuttonParam(obj, 'make_nogo', x, y, 'label', 'Make No-Go',...
            'position',[x, y, 75, 20]);
        set_callback(make_nogo, {mfilename, 'make_nogo'});
        x=x+76;

        PushbuttonParam(obj, 'default_set', x, y, 'label', 'Default All',...
            'position',[x, y, 75, 20]);
        set_callback(default_set, {mfilename, 'default_set'});


        %
        %         %%%Init
        %         initPos = {'initpos1','initpos2','initpos3','initpos4','initpos5','initpos6','initpos7','initpos8'};
        %
        %         %JPL - this is uniform by default and can only be modified by
        %         %completeing deselecting certain positions, or though antibias
        %         next_row(y);
        %         next_row(y);
        %
        %         y1 = y;
        %         y2 = y+20;
        %
        %         cueIdx=1;
        %         for i = 1:8 % 8 axial pole positions
        %             NumeditParam(obj, initPos{i}, 0+1000.5*(i-1), x, y, 'position', [x+50*(i-1) y1 50 20],...
        %                 'label','', 'labelfraction', 0.05);
        %
        %             PolePosnList.init.name{i}=initPos{i};
        %             PolePosnList.init.value{i}=value(eval([initPos{i}]));
        %
        %             PushbuttonParam(obj, 'init_go1', x, y,'position', [x+50*(i-1) y2+40 50 20],'label', 'move init (axial)');                 %pushbutton for pole move
        %             %         set_callback(move_pos1_init, {mfilename, 'move_pos1_axial'});
        %
        %         end
        %
        %         SubheaderParam(obj, 'title', 'Posn.',x+400, y1,'width',60);
        %         SubheaderParam(obj, 'title', 'Cue',x+400, y2,'width',60);
        %         SubheaderParam(obj, 'title', 'Cue Bal.',x+400, y2+20,'width',60);
        %         SubheaderParam(obj, 'title', 'Move to',x+400, y2+40,'width',60);
        %
        %         next_row(y);
        %         next_row(y);
        %         next_row(y);
        %         next_row(y);
        %         next_row(y);
        %         next_row(y);

        %READ POSITION BUTTONS, POLE MOTORS
        x=2;
        y=80;

        PushbuttonParam(obj, 'read_pole_positions', x, y, 'label', 'Read position',...
            'position',[x, y, 110, 20]);
        set_callback(read_pole_positions, {mfilename, 'read_pole_positions'});
        next_row(y);

        NumeditParam(obj,'axial_pole_motor_position',0,x,y,'label',...
            'Axial motor pos.', ...
            'TooltipString', 'Absolute axial position in microsteps of motor',...
            'position',[x, y, 110, 20],...
            'labelfraction',0.75);
        set_callback(axial_pole_motor_position, {mfilename, 'axial_pole_motor_position'});
        next_row(y);

        NumeditParam(obj,'radial_pole_motor_position',0,x,y,'label',...
            'Radial motor pos.', ...
            'TooltipString', 'Absolute radial position in microsteps of motor',...
            'position',[x, y, 110, 20],...
            'labelfraction',0.75);
        set_callback(radial_pole_motor_position, {mfilename, 'radial_pole_motor_position'});
        next_row(y);

        SubheaderParam(obj, 'title', 'Read Current Positions', x, y,...
            'position',[x y 110 20]);


        % Variables For debugging motor
        SoloParamHandle(obj, 'motor_move_time', 'value', 0);

        MotorsSection(obj,'hide_show');
        MotorsSection(obj,'read_positions');

        x = parentfig_x; y = parentfig_y;
        set(0,'CurrentFigure',value(myfig));
        return;

    case 'update_active_locs'

        %update PolePosn Handle
        for b=1:1:numel(PolePosnList.radial.value)
            PolePosnList.radial.value{b}=eval(['value(radial_pos' num2str(b) ')']);
        end

        for b=1:1:numel(PolePosnList.axial.value)
            PolePosnList.axial.value{b}=eval(['value(axial_pos' num2str(b) ')']);
        end

        %active axial locations for poles
        axialVals=cell2num(PolePosnList.axial.value);
        axialActiveInd=~isnan(axialVals);
        axialActive=axialVals(axialActiveInd);

        %active radial locations for  poles
        radialVals=cell2num(PolePosnList.radial.value);
        radialActiveInd=~isnan(radialVals);
        radialActive=radialVals(radialActiveInd);

        %make 2xN matrix of active pole locations. 1st col is axial, scond
        %col is radial
        axialActive_temp=repmat(axialActive,[numel(radialActive) 1]);
        radialActive_temp=repmat(radialActive,1,numel(axialActive));

        active_locations.positions=[axialActive_temp(:) radialActive_temp'];
        active_ids=1:1:length(active_locations.positions);

        %these are essentially default settings. Can reset this later
        %through a button.
        for g=1:1:numel(active_ids)
            active_locations.axial{g}=active_locations.positions(g,1);
            active_locations.radial{g}=active_locations.positions(g,2);
        end

        %update display
        MotorsSection(obj,'update_loc_data_display');

    case 'update_loc_data_display'
        currLocName = value(Positions);
        currLocInd=find(strcmpi(currLocName,active_locations.name(:))==1);

        %update the display of these settings in the GUI
        axial_position.value=active_locations.axial{currLocInd};
        radial_position.value=active_locations.radial{currLocInd};
        cue_id.value=active_locations.cue_id{currLocInd};
        cue_bal.value=active_locations.cue_balance{currLocInd};
        cue_vol.value=active_locations.cue_volume{currLocInd};

    case 'update_loc_data'
        currLocName = value(Positions);
        currLocInd=find(strcmpi(currLocName,active_locations.name(:))==1);

        %update the data for this location
        %these just show the location, cant edit!
        %active_locations.axial{currLocInd}=value(axial_position);
        %active_locations.radial{currLocInd}=value(radial_position);
        active_locations.cue_id{currLocInd}=value(cue_id);
        active_locations.cue_balance{currLocInd}=value(cue_bal);
        active_locations.cue_volume{currLocInd}=value(cue_vol);

    case 'make_go'
        currLocName = value(Positions);
        currLocInd=find(strcmpi(currLocName,active_locations.name(:))==1);
        active_locations.go_nogo{currLocInd} = 'go';

    case 'make_nogo'
        currLocName = value(Positions);
        currLocInd=find(strcmpi(currLocName,active_locations.name(:))==1);
        active_locations.go_nogo{currLocInd} = 'nogo';

    case 'move_test'
        %move based on a click of the 'Move' button
        currLocName = value(Positions);
        currLocInd=find(strcmpi(currLocName,active_locations.name(:))==1);
        radialPos=active_locations.radial{currLocInd};
        axialPos=active_locations.axial{currLocInd};

        %send axial command
        %move_absolute(pole_motors,axialPos*10000,...
        %    pole_motors_properties.axial_motor_num);

        %send radial command
      %  move_absolute(pole_motors,radialPos*10000,...
      %      pole_motors_properties.radial_motor_num);

        move_absolute_mult(pole_motors,[radialPos*10000 axialPos*10000],...
            [pole_motors_properties.radial_motor_num pole_motors_properties.axial_motor_num]);     
        
    case 'move_next_side', % --------- CASE MOVE_NEXT_SIDE -----

        %'next_side' imported from TrialStructureSection

        %all next pole positions  imported from TrialStructureSection as
        %well...This is so we can apply antibiasing to their positions

        %%%--------LICKPORT ZABERS--------%%%
        %JPL-CURRENTLY NOT SUPPORTED

        %%%--------INIT POLE ZABERS--------%%%
        %JPL-CURRENTLY NOT SUPPORTED

        %%%--------POLE ZABERS ----------%%%

        %only move motors if we have to to avoid errors

        switch SessionType
            case {'Water_Valve_Calibration','Beam-Break-Indicator','Licking',...
                    'Flash_LED','Sound_Calibration','Touch_Test'}
                movetime=0;
            otherwise %we are using motors
                %send axial command
                nogo_position=[];
                if strmatch(next_type,'nogo')
                    if isempty(nogo_position)
                        position = value(nogo_position);
                        warning('nogo position has not been defined!')
                    else
                        position=[0 0];
                    end
                end
                %         if Solo_Try_Catch_Flag == 1
                %             try
                %                 move_absolute_sequence(motors,{90000,position},value(right_motor_num));
                %             catch
                %                 pause(1)
                %                 warning('Error in move_absolute_sequence, forcing state 35...');
                %                 SMControlSection(obj,'force_state_35');
                %                 return
                %             end
                %         else
                tic

                %get index of nexct position
                ind=strmatch(next_pos_id,active_locations.name,'exact');


                %JPL - new method, randomly choose a location from the active
                %if the prepoint is the same as the next location, try
                %again
                %locations
                t=0;
                while t==0
                    prePoint=active_locations.positions(randsample(length(active_locations.positions),1),:);

                    if sum(active_locations.positions(ind,:)-prePoint)==0
                        t=0;
                    else
                        t=1;
                    end
                end

                %save the current pole position data

                set_history(currentPolePosition,[value(currentPolePosition);...
                    [active_locations.positions(ind,1)*10000 active_locations.positions(ind,2)*10000]]);
                
                currentPolePosition.value = [value(currentPolePosition); active_locations.positions(ind,1)*10000 active_locations.positions(ind,2)*10000];
                currentPoleId.value = [value(currentPoleId); active_locations.id{ind}];
                currentPoleCueId.value = [value(currentPoleCueId); active_locations.cue_id];
               
                %move motors to prepoint
                move_absolute_mult(pole_motors,[prePoint(2)*10000,prePoint(1)*10000], ...
                    [pole_motors_properties.radial_motor_num pole_motors_properties.axial_motor_num]);

                %move motors to next location
                move_absolute_mult(pole_motors,[active_locations.positions(ind,2)*10000 active_locations.positions(ind,1)*10000], ...
                    [pole_motors_properties.radial_motor_num pole_motors_properties.axial_motor_num]);

                %move_absolute_sequence(pole_motors,{prePoint(1)*10000,...
                %    active_locations.positions(ind,1)*10000},...
                %    pole_motors_properties.axial_motor_num);

                %send radial command
                %move_absolute_sequence(pole_motors,{prePoint(2)*10000,...
                %    active_locations.positions(ind,2)*10000},...
                %    pole_motors_properties.radial_motor_num);

                %pause for ITI if necessary
                movetime = toc
                motor_move_time.value = movetime;
        end

        if movetime<value(MinimumITI)
            pause(value(MinimumITI) - movetime);
        end

        MotorsSection(obj,'read_positions');
        %        trial_ready_times.value = clock;

        %         %store the history of positions of each motor
        %
        %         %%POLE MOTORS%%
        %         %JPL - I believe this history comes also from TrialStuctureSection
        %         pph=pole_position_history(:);
        %         pph(n_started_trials)=position;
        %         if size(pph,1)==1
        %             pph=pph';
        %         end
        %         %store command position, dont rely on MotorsSection.position
        %         pole_position_history.value=position;

        %         %%INIT MOTORS%%
        %         %JPL - I believe this history comes also from TrialStuctureSection
        %         pph=pole_position_history(:);
        %         pph(n_started_trials)=position;
        %         if size(pph,1)==1
        %             pph=pph'
        %         end
        %         %store command position, dont rely on MotorsSection.position
        %         pole_position_history.value=position;
        %
        %         %%LICK MOTORS%%
        %         %JPL - I believe this history comes also from TrialStuctureSection
        %         pph=pole_position_history(:);
        %         pph(n_started_trials)=position;
        %         if size(pph,1)==1
        %             pph=pph'
        %         end
        %         %store command position, dont rely on MotorsSection.position
        %         pole_position_history.value=position;



        return;

    case 'pole_motor_home',
        move_home(pole_motor);
        return;

    case 'pole_serial_reset',
        close_and_cleanup(pole_motor);

        global pole_motors_properties;
        global pole_motors;

        if strcmp(pole_motors_properties.type,'@FakeZaberTCD1000')
            pole_motors = FakeZaberTCD1000;
        else
            pole_motors = ZaberTCD1000;
        end

        serial_open(pole_motors);
        return;

    case 'pole_radial_motor_stop',
        stop(pole_motors);
        return;

    case 'pole_radial_motor_reset',
        reset(pole_motors);
        return;

        %%init(axial) cases
    case 'init_motor_home',
        move_home(init_radial_motor);
        return;

    case 'init_serial_reset',
        close_and_cleanup(init_radial_motor);

        global init_motors_properties;
        global init_motors;

        if strcmp(init_motors_properties.type,'@FakeZaberTCD1000')
            init_motors = FakeZaberTCD1000;
        else
            init_motors = ZaberTCD1000;
        end

        serial_open(init_motors);
        return;

    case 'init_motor_stop',
        stop(init_motors);
        return;

    case 'init_motor_reset',
        reset(init_motors);
        return;

        %general motor stuff
    case 'serial_open',
        serial_open(motors);
        return;

    case 'reset_motors_firmware',
        set_initial_parameters(motors)
        display('Reset speed, acceleration, and motor bus ID numbers.')
        return;

    case 'motor_position',
        position = value(motor_position);
        if position > value(motor_max_position) | position < 0
            p = get_position(motors,value(motor_num));
            motor_position.value = p;
        else
            move_absolute(motors,position,value(motor_num));
        end
        return;

    case 'read_pole_positions'
        p1 = get_position(pole_motors,pole_motors_properties.axial_motor_num);
        pole_axial_motor_position.value = p1;

        p2 = get_position(pole_motors,pole_motors_properties.radial_motor_num);
        pole_radial_motor_position.value = p2;

        %store current location for other classes
        active_locations.current=[p1 p2];

        return;

        % --------- CASE HIDE_SHOW ---------------------------------

    case 'hide_show'
        if strcmpi(value(motor_show), 'hide')
            set(value(motorfig), 'Visible', 'off');
        elseif strcmpi(value(motor_show),'view')
            set(value(motorfig),'Visible','on');
        end;
        return;

        %% CASE show_hide
    case 'show_hide_positions'
        if strcmpi(value(Position_Cue_list), 'hide')
            set(value(posfig), 'Visible', 'off');
        elseif strcmpi(value(Position_Cue_list),'view')
            set(value(posfig),'Visible','on');
        end;


    case 'reinit',   % ------- CASE REINIT -------------
        currfig = gcf;

        % Get the original GUI position and figure:
        x = my_gui_info(1); y = my_gui_info(2); figure(my_gui_info(3));

        delete(value(myaxes));

        % Delete all SoloParamHandles who belong to this object and whose
        % fullname starts with the name of this mfile:
        delete_sphandle('owner', ['^@' class(obj) '$'], ...
            'fullname', ['^' mfilename]);

        % Reinitialise at the original GUI position and figure:
        [x, y] = feval(mfilename, obj, 'init', x, y);

        % Restore the current figure:
        figure(currfig);
        return;
end


