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

function [x, y] = MotorsSection_crap(obj, action, x, y)

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
            %    pole_motors=ZaberTCD1000(pole_motors_properties.port);
        end
        %serial_open(pole_motors);
        
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
        
        %make handles for the various ROIs
        SoloParamHandle(obj,'contour','value',[]); %for the face
        SoloParamHandle(obj,'vertices','value',[]); %for whiskers
        
        %make a param handle for the handle of the scatter plot of
        %locations and the selected location
        SoloParamHandle(obj,'locHandle','value',[]);
        SoloParamHandle(obj,'currentHandle','value',[]);
        
        
        %make param handles for the origin in motor and gui space
        SoloParamHandle(obj,'motor_origin_x','value',0);
        SoloParamHandle(obj,'motor_origin_y','value',0);
        SoloParamHandle(obj,'gui_origin_x','value',0);
        SoloParamHandle(obj,'gui_origin_y','value',0);
        
        %%%START GUI BUILDING HERE%%%
        
        % ---  Make new window for motor configuration
        SoloParamHandle(obj, 'motorfig', 'saveable', 0);
        motorfig.value = figure('Position', [3 500 940 420], 'Menubar', 'none',...
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
%         PushbuttonParam(obj, 'init_motors_serial_reset', x, y, 'label', 'Reset init serial port',...
%             'position',[x, y, 110, 20]);
%         set_callback(init_motors_serial_reset, {mfilename, 'init_motor_serial_reset'});
%         next_row(y);
%         
%         PushbuttonParam(obj, 'init_motors_home', x, y, 'label', 'Home init Motors',...
%             'position',[x, y, 110, 20]);
%         set_callback(init_motors_home, {mfilename, 'init_motors_home'});
%         next_row(y);
%         
%         PushbuttonParam(obj, 'init_motors_stop', x, y, 'label', 'Stop init Motors',...
%             'position',[x, y, 110, 20]);
%         set_callback(init_motors_stop, {mfilename, 'init_motor_axial_stop'});
%         next_row(y);
%         
%         PushbuttonParam(obj, 'init_motors_reset', x, y, 'label', 'Reset init Motors',...
%             'position',[x, y, 110, 20]);
%         set_callback(init_motors_reset, {mfilename, 'init_motors_reset'});
%         next_row(y);
%         next_row(y);
%         next_row(y);
%         
%         %%%%LICKPORT MOTOR/S
%         PushbuttonParam(obj, 'lickport_motors_serial_reset', x, y, 'label', 'Reset lickport serial port',...
%             'position',[x, y, 110, 20]);
%         set_callback(lickport_motors_serial_reset, {mfilename, 'lickport_motor_serial_reset'});
%         next_row(y);
%         
%         PushbuttonParam(obj, 'lickport_motors_home', x, y, 'label', 'Home lickport Motors',...
%             'position',[x, y, 110, 20]);
%         set_callback(lickport_motors_home, {mfilename, 'lickport_motors_home'});
%         next_row(y);
%         
%         PushbuttonParam(obj, 'lickport_motors_stop', x, y, 'label', 'Stop lickport Motors',...
%             'position',[x, y, 110, 20]);
%         set_callback(lickport_motors_stop, {mfilename, 'lickport_motor_axial_stop'});
%         next_row(y);
%         
%         PushbuttonParam(obj, 'lickport_motors_reset', x, y, 'label', 'Reset lickport Motors',...
%             'position',[x, y, 110, 20]);
%         set_callback(lickport_motors_reset, {mfilename, 'lickport_motors_reset'});
%         next_row(y);
%         
%         y=2;
%         x=x+10;

        %these are essentially default settings. Can reset this later
        %through a button.
        active_ids=1;
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
          
        %%%%%some buttons and SHIT
        
        %input the pole diameter in mm
        NumeditParam(obj, 'pole_diam', 0.5, 170, y,'label', 'Pole Diam. (mm)');
        set_callback(pole_diam,{mfilename, 'update_pole_diam'});
        next_row(y);
        
        %input the desired pole spacing in mm
        NumeditParam(obj, 'loc_spacing', value(pole_diam), 170, y,'label', 'Pole spacing (mm)');
        set_callback(loc_spacing,{mfilename, 'update_loc_spacing'});
        next_row(y);
        
        %input pixel size
        NumeditParam(obj, 'mmPerPix', 0.15, 170, y,'label', 'Pixel Size (mm)');
        set_callback(mmPerPix,{mfilename, 'set_mmPerPix'});
        next_row(y);
        
        %JPL - maybe move this somewhere else
        %display the current number of locations (
        %NumeditParam(obj, 'disp_num_locs', 0, 170, y, 'label', '# of Locations','position');
        %set_callback(disp_num_locs,{mfilename, 'update_loc_spacing'});
        
        x=x+240; y=2;
        
        %rectangle ROI to create location grid in
        PushbuttonParam(obj, 'location_grid_rect', x, y, 'label', 'Loc. Grid Rect.',...
            'position',[x, y, 110, 20]);
        set_callback(location_grid_rect, {mfilename, 'create_grid_rect'});
        next_row(y);
        
        %polygon ROI eliminate poles in face
        PushbuttonParam(obj, 'face_poly', x, y, 'label', 'Face Poly.',...
            'position',[x, y, 110, 20]);
        set_callback(face_poly, {mfilename, 'face_poly_def'});
        next_row(y);
        
        %ellipse ROI to define whisking boundaries
        PushbuttonParam(obj, 'whisk_ellipse', x, y, 'label', 'Whisk Ellipse',...
            'position',[x, y, 110, 20]);
        set_callback(whisk_ellipse, {mfilename, 'whisk_ellipse_def'});
        next_row(y);
        
        %JPL - import face image as SoloParamHandle
        pos = get(gcf, 'Position');
        SoloParamHandle(obj, 'myaxes', 'saveable', 0, 'value', axes);
        set(value(myaxes), 'Units', 'pixels');
        set(value(myaxes), 'Position', [175 100 300 300]);
        
        %enable mouse clicks on the graph
        set(value(myaxes),'ButtonDownFcn', [mfilename '(' class(obj) ',''buttonDownCallback'')']);
        
        %axes should be display in mm from 0,0 position
        %load and display the test image in this space
        direc='Z:\Justin\fpga_bkImgs';
        raws=dir([direc filesep '*.raw']);
        fname=[direc filesep raws(1).name];
        [param, bgImg] = readFileHeader(fname);
        testim=(bgImg(:,:,1));
        SoloParamHandle(obj,'faceIm','value',testim);
        imSize=size(testim);
        
        %MotorsSection(obj,'plot_grid')
        %plot or replot the face
        
        
        [imhandle]=imagesc([-1*(size(value(faceIm),1)*value(mmPerPix)) 0],...
            [-1*(size(value(faceIm),2)*value(mmPerPix)) 0], value(faceIm));
        
        axes(gca)
        myaxes.value=gca;
        set(gca,'YAxisLocation','right');
        colormap('gray');
        hold on;
        
        axes(value(myaxes));
        
        %plot or replot the grid of points and current point
        [locHandle.value]=scatter(value(myaxes),...
            cell2mat(active_locations.axial_positions),cell2mat(active_locations.radial_positions));
        
        ylim(gca,[-1*(size(value(faceIm),2)*value(mmPerPix)) 0]);
        set(gca,'ButtonDownFcn', [mfilename '(' class(obj) ',''buttonDownCallback'')']);
        axpos = get(value(myaxes),'Position');
        markerWidth =  (value(pole_diam)/value(mmPerPix))/diff(xlim)*axpos(3); % Calculate Marker width in points
        set(value(locHandle), 'SizeData', markerWidth^2)
        
        [currentHandle.value]=scatter(value(myaxes),...
            active_locations.axial_positions{value(current_location_index)},active_locations.radial_positions{value(current_location_index)});
        
        ylim(gca,[-1*(size(value(faceIm),2)*value(mmPerPix)) 0]);
        
        
        currentunits = get(value(myaxes),'Units');
        set(value(myaxes), 'Units', 'pixels');
        set(value(myaxes), 'Position', [175 100 300 300]);
        set(value(myaxes), 'Units', 'Points');
        set(value(myaxes), 'Units', currentunits);
        xlabel('Radial Position (mm)');
        ylabel('Axial Position (mm)');
        SoloParamHandle(obj, 'previous_plot', 'saveable', 0);
        
        %%%%%some controls and display for the selected pole position on the
        %figure
        
        %Set auditory cue properties for this position
        
        x=x+150;
        y=2;
        
        %JPL - this should eventually be populated automatically from what
        %has been defined in sound section
        cues = {'cue_1','cue_2','cue_3','cue_4','cue_5','cue_6','cue_7',...
            'cue_8','none'};
        
        %define marker colors for different cues
        cIndex1=1;
        cIndex2=0;
        cIndex3=1;
        stepSize = (1/numel(cues));
        counter=1;
        %basically, we start off with magenta and move through to cyan in
        %steps
        
        cue_colors.name{1} = [];
        cue_colors.color{1} = [];
        
        while g <= numel(cues)
            if strcmp('none',cues{g})
                cue_colors.color{counter} = 'none';
                cue_colors.name{counter} = 'none';
            else
                cue_colors.color{counter} = [cIndex1-(stepSize*(counter-1))...
                    cIndex2+(stepSize*(counter-1)) cIndex3];
                cue_colors.name{counter} = cues{g};
                counter=counter+1;
            end
            g=g+1;
        end
        
        SoloParamHandle(obj,'cue_colors','value',cue_colors);
        
        %Here we are going to add a large table with editable values. Rows
        %show each of the different pole positions, and columns show the
        %values of their various properies, which can be edited.
        
        tbl = axes('units', 'pixels','position', [x+120 y+100 400 300]);
        cell_data = {...
            'posn_1',  0, 0, 'go','cue_1', 1, 1, 0;...
            '', 0, 0, '', '', 1, 1, 0;...
            '', 0, 0, '', '', 1, 1, 0;...
            '', 0, 0, '', '', 1, 1, 0;...
            '', 0, 0, '', '', 1, 1, 0;...
            '', 0, 0, '', '', 1, 1, 0;...
            '', 0, 0, '', '', 1, 1, 0;...
            '', 0, 0, '', '', 1, 1, 0;...
            '', 0, 0, '', '', 1, 1, 0;...
            '', 0, 0, '', '', 1, 1, 0;...
            '', 0, 0, '', '', 1, 1, 0;...
            };
        
        columninfo.titles={'Name','Radial','Axial','Go-NoGo', 'Cue','Pr','Hit Pr.','Miss Pr.'};
        columninfo.formats = {'%4.6g','%4.6g','%4.6g','%4.6g', '%4.6g', '%4.6g', '%4.6g','%4.6g'};
        columninfo.weight =      [ 1, 1, 1, 1, 1, 1, 1, 1];
        columninfo.multipliers = [ 1, 1, 1, 1, 1, 1, 1, 1];
        columninfo.isEditable =  [ 0, 0, 0, 1, 1, 1, 0, 0];
        columninfo.isNumeric =   [ 0, 1, 1, 0, 0, 1, 1, 1];
        columninfo.withCheck = true; % optional to put checkboxes along left side
        columninfo.chkLabel = 'Use'; % optional col header for checkboxes
        rowHeight = 8;
        gFont.size=7;
        gFont.name='Helvetica';
        
        tabledata = mltable(gcf, tbl, 'CreateTable', columninfo, rowHeight, cell_data, gFont);
        
        %set table callbacks
        mltable(gcf, tbl, 'Action','SetDblClick'); %double click function
        
        
        x=x+350;
        PushbuttonParam(obj, 'load_face_image', x, y, 'label', 'Load Image',...
            'position',[x, y, 150, 50]);
        set_callback(load_face_image, {mfilename, 'load_face_image'});
        
        next_row(y);
        next_row(y); y=y+10;
        
        
        %PushbuttonParam(obj, 'def_origin', x, y, 'label', 'Define Origin',...
        %   'position',[x, y, 150, 50]);
        %set_callback(def_origin, {mfilename, 'def_origin'});
        
        % next_row(y);
        % next_row(y);
        %next_row(y); y=y+10;
        
        PushbuttonParam(obj, 'move_to_loc', x, y, 'label', 'Move to Loc.',...
            'position',[x, y, 150, 50]);
        set_callback(move_to_loc, {mfilename, 'move_test'});
        
        next_row(y);
        next_row(y); y=y+10;
        
        PushbuttonParam(obj, 'delete_all', x, y, 'label', 'Delete ALL',...
            'position',[x, y, 150, 50]);
        set_callback(delete_all, {mfilename, 'delete_all'});
        
        next_row(y);
        next_row(y); y=y+10;
        
        PushbuttonParam(obj, 'delete_loc', x, y, 'label', 'Delete Current',...
            'position',[x, y, 150, 50]);
        set_callback(delete_loc, {mfilename, 'delete_loc'});
        
        next_row(y);
        next_row(y); y=y+15;
        
        NumeditParam(obj,'axial_coord',0,x,y,'label','axial coord.', ...
            'TooltipString', 'Axial motor setting for this location',...
            'position',[x, y, 150, 20],'labelfraction',0.4);
        %set_callback(axial_pole_motor_position, {mfilename, 'axial_pole_motor_position'});
        next_row(y);
        
        NumeditParam(obj,'radial_coord',0,x,y,'label','radial coord.', ...
            'TooltipString', 'Axial motor setting for this location',...
            'position',[x, y, 150, 20],'labelfraction',0.4);
        %set_callback(radial_pole_motor_position, {mfilename, 'radial_pole_motor_position'});
        
        next_row(y); y=y+4;
        MenuParam(obj,'cue_id',cues,'cue_1',x,y,'label','cue', ...
            'TooltipString', 'Cue ID for this location',...
            'position',[x, y, 150, 20],'labelfraction',0.3);
        set_callback(cue_id, {mfilename, 'update_loc_data'});
        
        next_row(y);y=y+4;
        
        %set position as go or no go. NoGo positons are shown with
        PushbuttonParam(obj, 'make_go', x, y, 'label', 'Make Go',...
            'position',[x, y, 75, 50]);
        set_callback(make_go, {mfilename, 'make_go'});
        x=x+76;
        
        PushbuttonParam(obj, 'make_nogo', x, y, 'label', 'Make No-Go',...
            'position',[x, y, 75, 50]);
        set_callback(make_nogo, {mfilename, 'make_nogo'});
        
        next_row(y);
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
        %set(0,'CurrentFigure',value(myfig));
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
        currLocName = active_locations{value(current_location_index)}.name;
        
        %update the display of these settings in the GUI
        axial_position.value=active_locations{value(current_location_index)}.axial;
        radial_position.value=active_locations{value(current_location_index)}.radial;
        cue_id.value=active_locations{value(current_location_index)}.cue_id;
        
    case 'update_loc_data'
        
        currLocName = active_locations.name(value(current_location_index));
        %update the data for this location
        %these just show the location, cant edit!
        %active_locations.axial{currLocInd}=value(axial_position);
        %active_locations.radial{currLocInd}=value(radial_position);
        active_locations.cue_id(value(current_location_index))={value(cue_id)};
        
        MotorsSection(obj,'plot_grid');
        
    case 'make_go'
        if value(current_location_index) ~=0
            current_location.name(value(current_location_index)) = ...
                value(active_locations.name(value(current_location_index)));
            
            active_locations.go_nogo(value(current_location_index)) = {'go'};
        else
            error('First select a pole location!')
        end
        
        MotorsSection(obj,'plot_grid');
        
    case 'make_nogo'
        if value(current_location_index) ~=0
            current_location.name(value(current_location_index)) = ...
                value(active_locations.name(value(current_location_index)));
            
            active_locations.go_nogo(value(current_location_index)) = {'nogo'};
        else
            error('First select a pole location!')
        end
        
        MotorsSection(obj,'plot_grid');
        
    case 'move_test'
        if value(current_location_index) ~=0
            
            %move based on a click of the 'Move' button
            currLocName = value(active_locations.name{value(current_location_index)});
            currLocInd=value(current_location_index);
            currLocInd=value(current_location_index);
            radialPos=active_locations{currLocInd}.radial;
            axialPos=active_locations{currLocInd}.axial;
        else
            error('First select a pole location!')
            
        end
        
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
        
    case {'update_loc_spacing','update_bar_diam','set_mmPerPix'}
        %recreate the grid
        
        %doesnt live update at the moment. Need to redraw a grid to see
        %changes
        
    case 'plot_grid'
        
        %first define the color vector for the scattergroup object. go
        %positions get green, no-go positions get black, current position
        %gets bold and blue markers
        
        nogo_inds = find(strcmp('nogo',active_locations.go_nogo)==1);
        go_inds = find(strcmp('go',active_locations.go_nogo)==1);
        CData = zeros(numel(active_locations.name),3);
        
        if ~isempty(isempty(nogo_inds))
            CData(nogo_inds,:) = repmat([0 0 0],numel([nogo_inds]),1);
        end
        
        if isempty(isempty(go_inds))
            error('Need at least one go location!');
        else
            CData(go_inds,:) = repmat([0 1 0],numel([go_inds]),1);
        end
        
        %loop to create a seperate axis handle in the current figure for
        %each pole location. This way we can change the display properties
        %for each independently
        
        for g=1:1:numel(active_locations.name)
            
            %create scatter group handle for this location and set its
            %properties
            axes(value(myaxes));
            %if the handle name for this pole is 'none', it has been
            %eliminated for now
            
            %set its properties
            set(active_locations.handle_num{g},'xdata', active_locations.axial_positions{g});
            set(active_locations.handle_num{g},'ydata', active_locations.radial_positions{g});
            set(active_locations.handle_num{g},'ButtonDownFcn', [mfilename '(' class(obj) ',''buttonDownCallback'')']);
            axpos = get(value(myaxes),'Position');
            markerWidth =  (value(pole_diam)/value(mmPerPix))/diff(xlim)*axpos(3); % Calculate Marker width in points
            set(active_locations.handle_num{g}, 'SizeData', markerWidth^2);
            set(active_locations.handle_num{g}, 'MarkerFaceColor', CData(g,:));  %corresponds to go or no go
            
            if sum(strcmp(active_locations.cue_id{g},value(cue_colors.name))) > 0
                set(active_locations.handle_num{g}, 'MarkerEdgeColor',...
                    value(cue_colors.color{find(strcmp(active_locations.cue_id{g},...
                    value(cue_colors.name))==1)}));  %corresponds to cue type
            else
                set(active_locations.handle_num{g}, 'MarkerEdgeColor',[0 0 0]);  %corresponds to cue type
            end
            set(active_locations.handle_num{g}, 'LineWidth', 1.5);
            %if current location, make it bold
            if g == value(current_location_index)
                set(active_locations.handle_num{g}, 'LineWidth', 4);   %shows currently selected location
            end
            
        end
        
        %lscatter(cell2mat(active_locations.axial_positions),...
        %    cell2mat(active_locations.radial_positions),cell2mat(active_locations.id), ...
        %     'ButtonDownFcn', [mfilename '(' class(obj) ',''buttonDownCallback'')']);
        
        
    case 'face_poly_def'
        %draw face polygon
        face=impoly;
        contour.value = wait(face);
        
        %ellimnate points in tgrid that are outside of the ellipse
        %first test if they are in the ellipse
        
        invect_face = inpolygon(cell2mat(active_locations.axial_positions),cell2mat(active_locations.radial_positions),value(contour(:,1)),value(contour(:,2)));
        
        %make these handles invisible
        ind=find((invect_face == 1)==1);
        
        for g=1:1:numel(ind)
            active_locations.axial_positions(ind(g))={1};
            active_locations.radial_positions(ind(g))={1};
            active_locations.coords(ind(g),:)=[1 1];
            set(active_locations.handle_num{ind(g)},'Visible','off');
        end
        
        %clear the handle names
        active_locations.handle_name(ind) = {'none'};
        
        delete(face);
        %plot the grid
        MotorsSection(obj,'plot_grid');
        
    case 'def_origin'
        
        %click on the center of the pole in the image.
        [gui_origin_x.value,gui_origin_y.value] = ginput(1);
        
        %get the current motor position. Current position is read into
        %active_locations.current
        MotorsSection(obj,'read_pole_positions');
        
        motor_origin_x.value = value(active_locations.current(1));
        motor_origin_y.value = value(active_locations.current(2));
        
        
    case 'whisk_ellipse_def'
        %draw whisker ellipse
        whisk = imellipse;
        vertices.value = wait(whisk); %allows editing of the circle before returning
        
        %ellimnate points in tgrid that are outside of the ellipse
        %first test if they are in the ellipse
        invect_whisk = inpolygon(cell2mat(active_locations.axial_positions),cell2mat(active_locations.radial_positions),value(vertices(:,1)),value(vertices(:,2)));
        
        ind=find((invect_whisk == 0)==1);
        %make these handles invisible
        for g=1:1:numel(ind)
            active_locations.axial_positions(ind(g))={1};
            active_locations.radial_positions(ind(g))={1};
            active_locations.coords(ind(g),:)=[1 1];
            set(active_locations.handle_num{ind(g)},'Visible','off');
        end
        
        %clear the handle names
        
        active_locations.handle_name(ind) = {'none'};
        
        delete(whisk);
        %plot the grid
        MotorsSection(obj,'plot_grid');
        
    case 'create_grid_rect'
        %update date to hide these points. We will replot, then DELETE the
        %data, so it can be refilled
        for g=1:1:length(active_locations.axial_positions)
            active_locations.axial_positions{g}=[1];
            active_locations.radial_positions{g}=[1];
            active_locations.coords(g,:)=[1 1];
            set(active_locations.handle_num{g},'Visible','off');
        end
        
        %for clearing the old data from the plot
        MotorsSection(obj,'plot_grid');
        
        
        %now delete the data and handles
        active_locations.coords=[];
        for g=1:1:length(active_locations.axial_positions)
            active_locations.axial_positions{g}=[];
            active_locations.radial_positions{g}=[];
            active_locations.id{g}=[];
            active_locations.name{g}=[];
            active_locations.cue_id{g} = [];
            active_locations.go_nogo{g} = [];
            active_locations.handle_name{g}=[];
            delete(active_locations.handle_num{g});
            active_locations.handle_num{g}=[];
        end
        
        %draw rectangular region for location grid
        gridd = imrect;
        position = wait(gridd);
        
        %populate the grid with a hexagonaly spaced array of points. The spacing of
        %points and the point diam (in mm!) are the only input param.
        
        %draw triangular grid using the geom2d toolbox. Fills the entire rectangle
        %defined by 'position', store in active locations
        
        tgrid = triangleGrid([position(1) position(2) position(3)+position(1)...
            position(4)+position(2)], [position(1) position(2)], value(loc_spacing)/value(mmPerPix) + value(value(pole_diam))/value(mmPerPix));
        
        
        %add grid points to active locations
        %create ids and names for each of these points
        %default for a new grid is all cues = cue1, all go
        for g=1:1:length(tgrid)
            active_locations.axial_positions{g} = tgrid(g,1);
            active_locations.radial_positions{g} = tgrid(g,2);
            active_locations.coords(g,:)=[tgrid(g,1) tgrid(g,2)];
            active_locations.id{g}=g;
            active_locations.name{g}=['pos_' num2str(g)];
            active_locations.cue_id{g} = 'cue_1';
            active_locations.go_nogo{g} = 'go';
            active_locations.handle_name{g}=[active_locations.name{g} '_handle'];
            %scatter a point at 0,0 to get a handle number. We will change
            %the data of this point in the real plot function
            active_locations.handle_num{g} = scatter(value(myaxes),0,0);
            
            %here we add the data to the table as well
            %tabledata
        end
        
        delete(gridd);
        
        %plot the grid
        MotorsSection(obj,'plot_grid');
        
    case 'hide_show'
        if strcmpi(value(motor_show), 'hide')
            set(value(motorfig), 'Visible', 'off');
        elseif strcmpi(value(motor_show),'view')
            set(value(motorfig),'Visible','on');
        end;
        return;
        
    case 'buttonDownCallback'
        p = get(gca,'CurrentPoint');
        p = p(1,1:2);
        
        %find the pole location nearest to the click point
        distances=sqrt((active_locations.coords(:,1)-repmat(p(1),size(active_locations.coords,1),1)).^2 ...
            + (active_locations.coords(:,2)-repmat(p(2),size(active_locations.coords,1),1)).^2);
        
        %set this point as the current point
        current_location_index.value=find(distances==min(distances));
        
        %update the data display for the data on this pole
        radial_coord.value = active_locations.coords(value(current_location_index),1);
        axial_coord.value = active_locations.coords(value(current_location_index),2);
        
        %plot the grid
        MotorsSection(obj,'plot_grid');
        
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
    case 'update_table'
end
end



