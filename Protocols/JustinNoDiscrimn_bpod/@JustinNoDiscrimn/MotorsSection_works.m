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
global init_motors_properties
global pole_motors;
global init_motors;

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

        %PushButtonParam(obj, 'serial_open', x, y, 'label', 'Open serial port');
        %set_callback(serial_open, {mfilename, 'serial_open'});
        %next_row(y);
        
        %PushButtonParam(obj, 'reset_motors_firmware', x, y, 'label', 'Reset Zaber firmware parameters',...
        %'TooltipString','Target acceleration, target speed, and microsteps/step');
        %set_callback(reset_motors_firmware, {mfilename, 'reset_motors_firmware'});
        %next_row(y);

        %%%%POLE MOTOR/S
        PushbuttonParam(obj, 'pole_motors_serial_reset', x, y, 'label', 'Reset pole serial port');
        set_callback(pole_motors_serial_reset, {mfilename, 'pole_motor_serial_reset'});
        next_row(y);

        PushbuttonParam(obj, 'pole_motors_home', x, y, 'label', 'Home Pole Motors');
        set_callback(pole_motors_home, {mfilename, 'pole_motors_home'});
        next_row(y);

        PushbuttonParam(obj, 'pole_motors_stop', x, y, 'label', 'Stop Pole Motors');
        set_callback(pole_motors_stop, {mfilename, 'pole_motor_axial_stop'});
        next_row(y);

        PushbuttonParam(obj, 'pole_motors_reset', x, y, 'label', 'Reset Pole Motors');
        set_callback(pole_motors_reset, {mfilename, 'pole_motors_reset'});
        
        next_row(y);
        next_row(y);
        next_row(y);
        next_row(y);
        next_row(y);
        next_row(y);
        next_row(y);
        next_row(y);
        next_row(y);

        SubheaderParam(obj,'title','Pole Positions Section',x,y,'width',600)
        
        next_row(y);
        
        %JPL - disabled for now, they dont exist           
        %%%%INIT MOTOR/S
        PushbuttonParam(obj, 'init_motors_serial_reset', x, y, 'label', 'Reset init serial port');
        set_callback(init_motors_serial_reset, {mfilename, 'init_motor_serial_reset'});
        next_row(y);

        %PushButtonParam(obj, 'reset_motors_firmware', x, y, 'label', 'Reset Zaber firmware parameters',...
        %'TooltipString','Target acceleration, target speed, and microsteps/step');
        %set_callback(reset_motors_firmware, {mfilename, 'reset_motors_firmware'});
        %next_row(y);

        PushbuttonParam(obj, 'init_motors_home', x, y, 'label', 'Home init Motors');
        set_callback(init_motors_home, {mfilename, 'init_motors_home'});
        next_row(y);

        PushbuttonParam(obj, 'init_motors_stop', x, y, 'label', 'Stop init Motors');
        set_callback(init_motors_stop, {mfilename, 'init_motor_axial_stop'});
        next_row(y);

        PushbuttonParam(obj, 'init_motors_reset', x, y, 'label', 'Reset init Motors');
        set_callback(init_motors_reset, {mfilename, 'init_motors_reset'});
        next_row(y);
        next_row(y);
        SubheaderParam(obj,'title','Init Pole Positions Section',x,y,'width',600)
        next_row(y);
   
        %%%%LICKPORT MOTOR/S
        PushbuttonParam(obj, 'lickport_motors_serial_reset', x, y, 'label', 'Reset lickport serial port');
        set_callback(lickport_motors_serial_reset, {mfilename, 'lickport_motor_serial_reset'});
        next_row(y);

        %PushButtonParam(obj, 'reset_motors_firmware', x, y, 'label', 'Reset Zaber firmware parameters',...
        %'TooltipString','Target acceleration, target speed, and microsteps/step');
        %set_callback(reset_motors_firmware, {mfilename, 'reset_motors_firmware'});
        %next_row(y);

        PushbuttonParam(obj, 'lickport_motors_home', x, y, 'label', 'Home lickport Motors');
        set_callback(lickport_motors_home, {mfilename, 'lickport_motors_home'});
        next_row(y);

        PushbuttonParam(obj, 'lickport_motors_stop', x, y, 'label', 'Stop lickport Motors');
        set_callback(lickport_motors_stop, {mfilename, 'lickport_motor_axial_stop'});
        next_row(y);

        PushbuttonParam(obj, 'lickport_motors_reset', x, y, 'label', 'Reset lickport Motors');
        set_callback(lickport_motors_reset, {mfilename, 'lickport_motors_reset'});
        next_row(y);
        
        y=2;
        next_column(x);
        %%%% SECTION FOR ASSOCIATING POLE POSITIONS WITH SOUND CUES
        %axial position names
        axialPos = {'axial_pos1','axial_pos2','axial_pos3','axial_pos4',...
            'axial_pos5','axial_pos6','axial_pos7','axial_pos8'};
     
        %axial cues
        axialCues = {'axial_pos1_cue','axial_pos2_cue','axial_pos3_cue',...
            'axial_pos4_cue','axial_pos5_cue','axial_pos6_cue',...
            'axial_pos7_cue','axial_pos8_cue'};
        
        %axial position sound balance
        axialBalance = {'axial_pos1_bal','axial_pos2_bal','axial_pos3_bal',...
            'axial_pos4_bal','axial_pos5_bal','axial_pos6_bal',...
            'axial_pos7_bal','axial_pos8_bal'};

        y1 = y;
        y2 = y+20;
        
        next_row(y);
        next_row(y);
        next_row(y);
        next_row(y);
        
        cueIdx=1;
        for i = 1:8 % 8 axial pole positions
            NumeditParam(obj, axialPos{i}, 0+1000.5*(i-1), x, y, 'position', [x+50*(i-1) y1 50 20],...
                'label','', 'labelfraction', 0.05);
            
            MenuParam(obj, axialCues{i}, value(PoleCueList),'cue_1', x, y, 'position', [x+50*(i-1), y2, 50, 20], ...
                    'label','','labelfraction',0.05);

            MenuParam(obj, axialBalance{i}, {'L','R','C'},'C', x, y, 'position', [x+50*(i-1) y2+20 50 20],...
                'label','', 'labelfraction', 0.05);

            %store position-cue map as solo param handle
            PolePosnList.axial.name{i}=axialPos{i};
            PolePosnList.axial.value{i}=value(eval([axialPos{i}]));
            PolePosnList.axial.cue{i}=value(eval([axialCues{i}]));
            PolePosnList.axial.bal{i}=value(eval([axialBalance{i}]));
            
            %pushbutton control and callback
            PushbuttonParam(obj, ['axial_go' axialPos{i}], x, y,'position', [x+50*(i-1) y2+40 50 20],'label', 'move to');    %pushbutton for pole move
            %         set_callback(move_pos1_axial, {mfilename, 'move_pos1_axial'});
      
            SubheaderParam(obj,'title',['Pos ' num2str(i)],x,y,'position',[x+50*(i-1) y2+60 50 20],...
                'label',['Pos ' num2str(i)]);

        end
        
        SubheaderParam(obj, 'title', 'Posn.',x+400, y1,'width',60);
        SubheaderParam(obj, 'title', 'Cue',x+400, y2,'width',60);
        SubheaderParam(obj, 'title', 'Cue Bal.',x+400, y2+20,'width',60);
   
        next_row(y);

        SubheaderParam(obj,'title','Axial Pole Positions Section',x,y,'width',460)

        %%%RADIAL
        %radial position names
        radialPos = {'radial_pos1','radial_pos2','radial_pos3',...
            'radial_pos4','radial_pos5','radial_pos6','radial_pos7','radial_pos8'};
     
        %radial cues
        radialCues = {'radial_pos1_cue','radial_pos2_cue','radial_pos3_cue','radial_pos4_cue',...
            'radial_pos5_cue','radial_pos6_cue','radial_pos7_cue','radial_pos8_cue'};
        
        %radial position sound balance
        radialBalance = {'radial_pos1_bal','radial_pos2_bal','radial_pos3_bal','radial_pos4_bal',...
            'radial_pos5_bal','radial_pos6_bal','radial_pos7_bal','radial_pos8_bal'};

        next_row(y);

        y1 = y;
        y2 = y+20;
        
        cueIdx=1;
        for i = 1:8 % 8 radial pole positions
            NumeditParam(obj, radialPos{i}, 0+1000.5*(i-1), x, y, 'position', [x+50*(i-1) y1 50 20],...
                'label','', 'labelfraction', 0.05);
            
            MenuParam(obj, radialCues{i}, value(PoleCueList),'none', x, y, 'position', [x+50*(i-1), y2, 50, 20], ...
                    'label','','labelfraction',0.05);

            MenuParam(obj, radialBalance{i}, {'L','R','C'},'C', x, y, 'position', [x+50*(i-1) y2+20 50 20],...
                'label','', 'labelfraction', 0.05);

            %store position-cue map as solo param handle
            PolePosnList.radial.name{i}=radialPos{i};
            PolePosnList.radial.value{i}=value(eval([radialPos{i}]));
            PolePosnList.radial.cue{i}=value(eval([radialCues{i}]));
            PolePosnList.radial.bal{i}=value(eval([radialBalance{i}]));
            
            %pushbutton control and callback
            PushbuttonParam(obj, ['radial_go' radialPos{i}], x, y,'position', [x+50*(i-1) y2+40 50 20],'label', ['move to ' radialPos{i}]);                 %pushbutton for pole move
            %         set_callback(move_pos1_axial, {mfilename, 'move_pos1_axial'});
            
            SubheaderParam(obj,'title',['Pos ' num2str(i)],x,y,'position',[x+50*(i-1) y2+60 50 20],...
                'label',['Pos ' num2str(i)]);

        end
      
        SubheaderParam(obj, 'title', 'Posn.',x+400, y1,'width',60);
        SubheaderParam(obj, 'title', 'Cue',x+400, y2,'width',60);
        SubheaderParam(obj, 'title', 'Cue Bal.',x+400, y2+20,'width',60);
        
        SubheaderParam(obj,'title','Radial Pole Positions',x,y2+80,'width',500)
        
        next_row(y);
        next_row(y);
        next_row(y);
        next_row(y);
        next_row(y);

        %%%Init
        initPos = {'initpos1','initpos2','initpos3','initpos4','initpos5','initpos6','initpos7','initpos8'};

        %JPL - this is uniform by default and can only be modified by
        %completeing deselecting certain positions, or though antibias
        next_row(y);
        next_row(y);
        
        y1 = y;
        y2 = y+20;

        cueIdx=1;
        for i = 1:8 % 8 axial pole positions
            NumeditParam(obj, initPos{i}, 0+1000.5*(i-1), x, y, 'position', [x+50*(i-1) y1 50 20],...
                'label','', 'labelfraction', 0.05);
            
            PolePosnList.init.name{i}=initPos{i};
            PolePosnList.init.value{i}=value(eval([initPos{i}]));

            PushbuttonParam(obj, 'init_go1', x, y,'position', [x+50*(i-1) y2+40 50 20],'label', 'move init (axial)');                 %pushbutton for pole move
            %         set_callback(move_pos1_init, {mfilename, 'move_pos1_axial'});

        end
        
        SubheaderParam(obj, 'title', 'Posn.',x+400, y1,'width',60);
        SubheaderParam(obj, 'title', 'Cue',x+400, y2,'width',60);
        SubheaderParam(obj, 'title', 'Cue Bal.',x+400, y2+20,'width',60);
        SubheaderParam(obj, 'title', 'Move to',x+400, y2+40,'width',60);

        next_row(y);
        next_row(y);
        next_row(y);
        next_row(y);
        next_row(y);
        next_row(y);
        next_row(y);
        
        %READ POSITION BUTTONS, POLE MOTORS
        x=2;
        y=100;
         
        PushbuttonParam(obj, 'read_pole_positions', x, y, 'label', 'Read position');
        set_callback(read_pole_positions, {mfilename, 'read_pole_positions'});
        next_row(y);

        NumeditParam(obj,'axial_pole_motor_position',0,x,y,'label',...
            'Axial motor pos.', ...
            'TooltipString', 'Absolute axial position in microsteps of motor');
        set_callback(axial_pole_motor_position, {mfilename, 'axial_pole_motor_position'});
        next_row(y);

        NumeditParam(obj,'radial_pole_motor_position',0,x,y,'label',...
            'Radial motor pos.', ...
            'TooltipString', 'Absolute radial position in microsteps of motor');
        set_callback(radial_pole_motor_position, {mfilename, 'radial_pole_motor_position'});
        next_row(y);

        SubheaderParam(obj, 'title', 'Read Motor Positions', x, y);

        next_row(y);
        

        %SET POSITIONS OF NO GO
        next_row(y);
        NumeditParam(obj, 'nogo_position', 45000, x, y, 'label', ...
            'No-go/ Right position','TooltipString','No-go or Right trial position in microsteps.');

        next_row(y);
        SubheaderParam(obj, 'title', 'Trial position', x, y);

        
        % Variables For debugging motor
        SoloParamHandle(obj, 'motor_move_time', 'value', 0);

        MotorsSection(obj,'hide_show');
        MotorsSection(obj,'read_positions');

        x = parentfig_x; y = parentfig_y;
        set(0,'CurrentFigure',value(myfig));
        return;

    case 'move_next_side', % --------- CASE MOVE_NEXT_SIDE -----

        %'next_side' imported from TrialStructureSection
        
        %all next pole positions  imported from TrialStructureSection as
        %well...This is so we can apply antibiasing to their positions

        
        %%%--------LICKPORT ZABERS--------%%%
        %JPL-CURRENTLY NOT SUPPORTED
        
        %%%--------INIT POLE ZABERS--------%%%
        %JPL-CURRENTLY NOT SUPPORTED
        
        %%%--------POLE ZABERS ----------%%%
        
        
        % Manually start pedestal at mid-point (90000).
        if strmatch(next_type,'nogo')
            position = value(nogo_position);
        end

        %JPL - DEPRECATED
        %halfpoint = abs(round((value(nogo_position)-value(go_position))/2)) + min(value(nogo_position),value(go_position));
        
        %JPL - new method, randomly choose a location
        %%AXIAL MOTOR
        minPos_axial=min(cell2mat(PolePosnList.axial.value));
        maxPos_axial=max(cell2mat(PolePosnList.axial.value));
        minPos_radial=min(cell2mat(PolePosnList.radial.value));
        maxPos_radial=max(cell2mat(PolePosnList.radial.value));
        
        rangePos_axial=maxPos_axial-minPos_axial;
        rangePos_radial=maxPos_radial-minPos_radial;
        
        prePoint_axial=minPos_axial+round(rand(1)*rangePos_axial);
        prePoint_radial=minPos_radial+round(rand(1)*rangePos_radial);
        
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
        
        axialInd=strcmp(next_axial_pos,PolePosnList.axial.name);
        radialInd=strcmp(next_radial_pos,PolePosnList.radial.name);
        
        %send axial command
        move_absolute_sequence(pole_motors,{prePoint_axial,...
            PolePosnList.axial.value{axialInd}},...
            pole_motors_properties.axial_motor_num);

        %send radial command
        move_absolute_sequence(pole_motors,{prePoint_radial,...
            PolePosnList.radial.value{radialInd}},...
            pole_motors_properties.radial_motor_num);

        %pause for ITI if necessary
        movetime = toc
        motor_move_time.value = movetime;
        
        %JPL - MinimumITI needs to be imprted form GUI!
        
        MinimumITI=4;
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
        p = get_position(pole_motors,pole_motors_properties.axial_motor_num);
        pole_axial_motor_position.value = p;

        p = get_position(pole_motors,pole_motors_properties.radial_motor_num);
        pole_motor_position.value = p;
        return;

        % --------- CASE HIDE_SHOW ---------------------------------

    case 'hide_show'
        if strcmpi(value(motor_show), 'hide')
            set(value(motorfig), 'Visible', 'off');
        elseif strcmpi(value(motor_show),'view')
            set(value(motorfig),'Visible','on');
        end;
        return;


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


