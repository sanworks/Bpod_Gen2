% [x, y] = MotorsSection(obj, action, x, y)
%
% Section that takes care of controlling the stepper motors.
%f
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

%query for updates to tab le, if this is not an init call
%if (strcmp(action, 'init'))==0
%    %check for table updates
%    MotorsSection(obj,'poll_table_and_update');
%end

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
global max_pos; %shoould be able to read this directly from the motor,
%but is a setting here for now
global min_pos; %shoould be able to read this directly from the motor,
%but is a setting here for now
max_pos=1000000000;
min_pos=-1000000000;

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
        
        active_locations_tmp=value(active_locations);
        
        %initialize the pole motor/s
        if strcmp(pole_motors_properties.type,'@FakeZaberTCD1000')
            pole_motors=FakeZaberTCD1000;
        else
            pole_motors=ZaberTCD1000(pole_motors_properties.port);
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
        SoloParamHandle(obj, 'my_gui_info', 'value', [x y get(gcf,'Number')]); next_row(y,1.5);
        
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
        %locations, the selected location, and the face image
        SoloParamHandle(obj,'locHandle','value',[]);
        SoloParamHandle(obj,'currentHandle','value',[]);
        SoloParamHandle(obj,'imHandle','value',[]);
        
        
        %make param handles for the origin in motor and gui space, also
        %theta calc point
        SoloParamHandle(obj,'motor_origin_x','value',0,'type','saveable_nonui');
        SoloParamHandle(obj,'motor_origin_y','value',0,'type','saveable_nonui');
        SoloParamHandle(obj,'gui_origin_x','value',0,'type','saveable_nonui');
        SoloParamHandle(obj,'gui_origin_y','value',0,'type','saveable_nonui');
        SoloParamHandle(obj,'theta_x','value',0,'type','saveable_nonui');
        SoloParamHandle(obj,'theta_y','value',0,'type','saveable_nonui');
        
        %%%START GUI BUILDING HERE%%%
        
        % ---  Make new window for motor configuration
        SoloParamHandle(obj, 'motorfig', 'saveable', 0);
        motorfig.value = figure('Position', [3 500 1800 450], 'Menubar', 'none',...
            'Toolbar', 'none','Name','Motor Control','NumberTitle','off');
        
        x = 1; y = 1;
        %%%%POLE MOTOR/S
        PushbuttonParam(obj, 'pole_motors_serial_reset', x, y, 'label', 'Reset pole serial port',...
            'position',[x, y, 130, 20]);
        set_callback(pole_motors_serial_reset, {mfilename, 'pole_serial_reset'});
        next_row(y);
        
        PushbuttonParam(obj, 'pole_motors_home', x, y, 'label', 'Home Pole Motors',...
            'position',[x, y, 130, 20]);
        set_callback(pole_motors_home, {mfilename, 'pole_motor_home'});
        next_row(y);
        
        PushbuttonParam(obj, 'pole_motors_stop', x, y, 'label', 'Stop Pole Motors',...
            'position',[x, y, 130, 20]);
        set_callback(pole_motors_stop, {mfilename, 'pole_motor_stop'});
        next_row(y);
        
        PushbuttonParam(obj, 'pole_motors_reset', x, y, 'label', 'Reset Pole Motors',...
            'position',[x, y, 130, 20]);
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
            'position',[x, y, 130, 20]);
        set_callback(init_motors_serial_reset, {mfilename, 'init_motor_serial_reset'});
        next_row(y);
        
        PushbuttonParam(obj, 'init_motors_home', x, y, 'label', 'Home init Motors',...
            'position',[x, y, 130, 20]);
        set_callback(init_motors_home, {mfilename, 'init_motors_home'});
        next_row(y);
        
        PushbuttonParam(obj, 'init_motors_stop', x, y, 'label', 'Stop init Motors',...
            'position',[x, y, 130, 20]);
        set_callback(init_motors_stop, {mfilename, 'init_motor_axial_stop'});
        next_row(y);
        
        PushbuttonParam(obj, 'init_motors_reset', x, y, 'label', 'Reset init Motors',...
            'position',[x, y, 130, 20]);
        set_callback(init_motors_reset, {mfilename, 'init_motors_reset'});
        next_row(y);
        next_row(y);
        next_row(y);
        
        %%%%LICKPORT MOTOR/S
        PushbuttonParam(obj, 'lickport_motors_serial_reset', x, y, 'label', 'Reset lickport serial port',...
            'position',[x, y, 130, 20]);
        set_callback(lickport_motors_serial_reset, {mfilename, 'lickport_motor_serial_reset'});
        next_row(y);
        
        PushbuttonParam(obj, 'lickport_motors_home', x, y, 'label', 'Home lickport Motors',...
            'position',[x, y, 130, 20]);
        set_callback(lickport_motors_home, {mfilename, 'lickport_motors_home'});
        next_row(y);
        
        PushbuttonParam(obj, 'lickport_motors_stop', x, y, 'label', 'Stop lickport Motors',...
            'position',[x, y, 130, 20]);
        set_callback(lickport_motors_stop, {mfilename, 'lickport_motor_axial_stop'});
        next_row(y);
        
        PushbuttonParam(obj, 'lickport_motors_reset', x, y, 'label', 'Reset lickport Motors',...
            'position',[x, y, 130, 20]);
        set_callback(lickport_motors_reset, {mfilename, 'lickport_motors_reset'});
        next_row(y);
        
        y=2;
        x=x+10;
        
        %%%%%some buttons and SHIT
        
        %input the pole diameter in mm
        NumeditParam(obj, 'pole_diam', 0.5, 170, y,'label', 'Pole Diam. (mm)');
        set_callback(pole_diam,{mfilename, 'update_pole_diam'});
        next_row(y);
        
        %input the desired pole spacing in mm
        NumeditParam(obj, 'loc_spacing', 2.0, 170, y,'label', 'Pole spacing (mm)');
        set_callback(loc_spacing,{mfilename, 'update_loc_spacing'});
        next_row(y);
        
        %input pixel size
        %0.039
        NumeditParam(obj, 'mmPerPix', 0.1, 170, y,'label', 'Pixel Size (mm)');
        set_callback(mmPerPix,{mfilename, 'set_mmPerPix'});
        next_row(y);
        
        
        x=x+350; y=2;
        
        %rectangle ROI to create location grid in
        PushbuttonParam(obj, 'location_grid_rect', x, y, 'label', 'Loc. Grid Rect.',...
            'position',[x, y, 110, 20]);
        set_callback(location_grid_rect, {mfilename, 'create_grid_rect'});
        next_row(y);
        
        %polygon ROI eliminate poles in face
        PushbuttonParam(obj, 'face_poly', x, y, 'label', 'Delete Within Poly.',...
            'position',[x, y, 110, 20]);
        set_callback(face_poly, {mfilename, 'face_poly_def'});
        next_row(y);
        
        %ellipse ROI to define whisking boundaries
        PushbuttonParam(obj, 'whisk_ellipse', x, y, 'label', 'Keep Within Ellipse',...
            'position',[x, y, 110, 20]);
        set_callback(whisk_ellipse, {mfilename, 'whisk_ellipse_def'});
        next_row(y);
        
        %%%%%AXES FOR PLOTTING FACE AND POLE POSITIONS%%%%%
        SoloParamHandle(obj, 'myaxes', 'saveable', 0, 'value', axes);
        set(value(myaxes), 'Units', 'pixels');
        set(value(myaxes), 'Position', [175 100 300 300]);
        
        %enable mouse clicks on the graph
        set(value(myaxes),'ButtonDownFcn', [mfilename '(' class(obj) ',''buttonDownCallback'')']);
        
        %axes should be display in mm from 0,0 position
        %load and display blank image for now
        %testim=zeros(512,544);
        %testim=zeros(448,488);
        testim=zeros(192,192);
        SoloParamHandle(obj,'faceIm','value',testim,'type','saveable_nonui');
        
        %plot and create handle for the face image
        [imHandle.value]=image([(size(value(faceIm),1)*value(mmPerPix)) 0],...
            [(size(value(faceIm),2)*value(mmPerPix)) 0], value(faceIm));
        
        axes(gca)
        myaxes.value=gca;
        set(gca,'YAxisLocation','right');
        set(gca,'XAxisLocation','top');
        set(gca,'Xdir','reverse');
        colormap('gray');
        hold on;
        
        axes(value(myaxes));
        %plot or replot the grid of points and current point
        [locHandle.value]=scatter(value(myaxes),...
            cell2mat(value(active_locations_tmp.axial_positions)),cell2mat(value(active_locations_tmp.radial_positions)));
        
        %ylim(gca,[-1*(size(value(faceIm),2).*value(mmPerPix)) 0]);
        set(gca,'ButtonDownFcn', [mfilename '(' class(obj) ',''buttonDownCallback'')']);
        axpos = get(value(myaxes),'Position');
        markerWidth =  (value(pole_diam).*value(mmPerPix))/diff(xlim)*axpos(3); % Calculate Marker width in points
        set(value(locHandle), 'SizeData', markerWidth^2)
        
        tmp1=value(active_locations_tmp.axial_positions);
        tmp2=value(active_locations_tmp.radial_positions);
        [currentHandle.value]=scatter(value(myaxes),...
            tmp1{value(current_location_index)},tmp2{value(current_location_index)});
        
        currentunits = get(value(myaxes),'Units');
        set(value(myaxes), 'Units', 'pixels');
        set(value(myaxes), 'Position', [175 100 300 300]);
        set(value(myaxes), 'Units', 'Points');
        set(value(myaxes), 'Units', currentunits);
        xlabel('Radial Position (mm)');
        ylabel('Axial Position (mm)');
        SoloParamHandle(obj, 'previous_plot', 'saveable', 0);
        
        x=x+30;
        y=2;
        
        %%%%POLE PROPERTIES TABLE AXIS
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
        
        g=1;
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
        
        %NOTE: this table is not a SoloParamHandle type. We will need to
        %make it one in order for it to be editable live like the other
        %GUIs
        
        tbl.value = axes('units', 'pixels','position', [x+150 y+100 1000 300]);
        empty_row= {'',[],[],'','','',[],'',[],[],[],[],[],[],[]};
        cell_data = {...
            'pos_1',  0, 0, 'go', 'none', 'lick', 0,'cue_1', 1, [0 0 0 0], 1, 1, 0, 0, 0;...
            };
        
        cell_data=[cell_data; repmat(empty_row,10,1)];
        
        columninfo.titles=       {'Name',  'Axial', 'Radial', 'Go-NoGo', 'Samp. Axn', 'Answ. Axn', 'Punish On', 'Cue',   'Pr',    'Mism. Pr.', 'RewXr',  'ThrshXr', '# Appear.','# Samp. Acts..','# Correct.'};
        columninfo.formats =     {'%4.4g', '%4.4g', '%4.4g',  '%4.4g',   '%4.4g',     '%4.4g',     '%4.4g',     '%4.4g', '%4.4g', '%4.4g',     '%4.4g',  '%4.4g',   '%4.4g',     '%4.4g',    '%4.4g' };
        columninfo.weight =      [ 1,       1,      1,        1,         1,            1,           1,          1,       1,       1,           1,        1,         1,           1,           1];
        columninfo.multipliers = [ 1,       1,      1,        1,         1,            1,           1,          1,       1,       1,           1,        1,         1,           1,           1];
        columninfo.isEditable =  [ 0,       0,      0,        1,         1,            1,           1,          1,       1,       1,           1,        1,         0,           0,           0];
        columninfo.isNumeric  =  [ 0,       1,      1,        0,         0,            0,           1,          0,       1,       1,           1,        1,         1,           1,           1];
        %JPL - these checkboxes will radio poles enabled and disabled, and
        %gray them out on the display
        %if poles are right clicked in the display and set to 'disable' or
        %'enable', the radio button will follow
        %....BUT NONE OF THIS IS IMPLEMENTED YET
        
        %Write now checks arent being done properly, disabling
        
        %columninfo.withCheck = true; % optional to put checkboxes along left side
        %columninfo.chkLabel = 'Use'; % optional col header for checkboxes
        rowHeight = 15;
        gFont.size=7;
        gFont.name='Helvetica';
                
        set(gcf,'CurrentAxes',value(tbl))
        tabledata = mltable(get(gcf,'Number'), get(gcf,'CurrentAxes'), 'CreateTable', columninfo, rowHeight, cell_data, gFont);
        
        %make this a soloParamHandle
        SoloParamHandle(obj,'tabledata','value',tabledata);
        
        %set table callbacks
        set(gcf,'CurrentAxes',value(tbl))
        mltable(get(gcf,'Number'), value(tbl), 'Action','SetDblClick'); %double click function
        
        %%%%SOME MORE BUTTONS%%%%%
        x=x+100;
        y=2;
        PushbuttonParam(obj, 'load_face_image', x, y, 'label', 'Load Image',...
            'position',[x, y, 110, 20]);
        set_callback(load_face_image, {mfilename, 'load_face_image'});
        
        next_row(y);
        
        PushbuttonParam(obj, 'def_origin', x, y, 'label', 'Define Origin',...
            'position',[x, y, 110, 20]);
        set_callback(def_origin, {mfilename, 'def_origin'});
        next_row(y);
        
        PushbuttonParam(obj, 'move_to_loc', x, y, 'label', 'Move to Selected',...
            'position',[x, y, 110, 20]);
        set_callback(move_to_loc, {mfilename, 'move_test'});
        x=x+111;y=2;
        
        PushbuttonParam(obj, 'delete_all', x, y, 'label', 'Delete ALL',...
            'position',[x, y, 110, 20]);
        set_callback(delete_all, {mfilename, 'delete_all'});
        
        next_row(y);
        
        PushbuttonParam(obj, 'delete_loc', x, y, 'label', 'Delete Current',...
            'position',[x, y, 110, 20]);
        set_callback(delete_loc, {mfilename, 'delete_loc'});
        
        next_row(y);
        
        PushbuttonParam(obj, 'load_poles', x, y, 'label', 'Load Poles',...
            'position',[x, y, 110, 20]);
        set_callback(load_poles, {mfilename, 'load_poles'});
        
        next_row(y);
        
        PushbuttonParam(obj, 'theta_point', x, y, 'label', 'Theta Point',...
            'position',[x, y, 110, 20]);
        set_callback(theta_point, {mfilename, 'choose_theta_point'});
        
        x=x+111;y=2;
        
        %move radial pole by +/- n mm
        NumeditParam(obj, 'move_rad', 0, x, y,'label', 'Move Radially (cm)');
        set_callback(move_rad,{mfilename, 'move_radial'});
        next_row(y);
        
        %move axial pole by +/- n mm
        NumeditParam(obj, 'move_ax', 0, x, y,'label', 'Move Axially (cm)');
        set_callback(move_ax,{mfilename, 'move_axial'});
        next_row(y);
        
        %JPL - this is a bit of a hack until I can figure out how to
        %highlight the table rows corresponding to the selected pole
        %position
        EditParam(obj, 'curr_pole_name', 'pos_1', x, y,'label', 'Current Position');
        %set_callback(curr_pole_name,{mfilename, 'curr_pole_name'});
        
        x=2;
        y=80;
        
        PushbuttonParam(obj, 'read_pole_positions', x, y, 'label', 'Read position',...
            'position',[x, y, 130, 20]);
        set_callback(read_pole_positions, {mfilename, 'read_pole_positions'});
        next_row(y);
        
        NumeditParam(obj,'axial_pole_motor_position',0,x,y,'label',...
            'Axial', ...
            'TooltipString', 'Absolute axial position in microsteps of motor',...
            'position',[x, y, 130, 20],...
            'labelfraction',0.3);
        set_callback(axial_pole_motor_position, {mfilename, 'axial_pole_motor_position'});
        next_row(y);
        
        NumeditParam(obj,'radial_pole_motor_position',0,x,y,'label',...
            'Radial', ...
            'TooltipString', 'Absolute radial position in microsteps of motor',...
            'position',[x, y, 130, 20],...
            'labelfraction',0.3);
        set_callback(radial_pole_motor_position, {mfilename, 'radial_pole_motor_position'});
        next_row(y);
        
        SubheaderParam(obj, 'title', 'Read Current', x, y,...
            'position',[x y 130 20]);
        
        % Variables For debugging motor
        SoloParamHandle(obj, 'motor_move_time', 'value', 0);
        
        MotorsSection(obj,'hide_show');
        MotorsSection(obj,'read_positions');
        
        x = parentfig_x; y = parentfig_y;
        %set(0,'CurrentFigure',value(myfig));
        
        
        active_locations.value=active_locations_tmp;
        
        return;
        
        
    case 'update_active_locs'
        
        active_locations_tmp=value(active_locations);
        
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
        
        active_locations_tmp.coords=[axialActive_temp(:) radialActive_temp'];
        active_ids=1:1:length(active_locations_tmp.coords);
        
        %these are essentially default settings. Can reset this later
        %through a button.
        for g=1:1:numel(active_ids)
            active_locations_tmp.axial{g}=active_locations_tmp.coords(g,1);
            active_locations_tmp.radial{g}=active_locations_tmp.coords(g,2);
        end
        
        active_locations.value=active_locations_tmp;
        
        %update display
        MotorsSection(obj,'update_loc_data_display');
        
    case 'update_loc_data_display'
        
        active_locations_tmp=value(active_locations);
        
        currLocName = active_locations_tmp{value(current_location_index)}.name;
        
        %update the display of these settings in the GUI
        axial_position.value=value(active_locations_tmp{value(current_location_index)}.axial);
        radial_position.value=value(active_locations_tmp{value(current_location_index)}.radial);
        cue_name.value=value(active_locations_tmp{value(current_location_index)}.cue_name);
        
    case 'update_loc_data'
        
        active_locations_tmp=value(active_locations);
        
        currLocName = value(active_locations_tmp.name(value(current_location_index)));
        %update the data for this location
        %these just show the location, cant edit!
        %active_locations_tmp.axial{currLocInd}=value(axial_position);
        %active_locations_tmp.radial{currLocInd}=value(radial_position);
        active_locations_tmp.cue_name(value(current_location_index))={value(cue_name)};
        
        MotorsSection(obj,'plot_grid');
        
    case 'load_face_image'
        [fname, fpath, findex]=uigetfile(...
            {'*.raw;*.tif;*.seq', 'All Image Files (*.raw, *.tif, *.seq)';
            '*.raw',  'Raw binary files (*.raw)'; ...
            '*.tif','Tif files (*.tif)'; ...
            '*.seq','Seq files (*.seq)'; ...
            '*.*',  'All Files (*.*)'}, ...
            'Pick a file');
        if strfind(fname,'.raw')%.raw image from fpga
            [param, bgImg] = readFileHeader([fpath filesep fname]);
            faceIm.value=flipud((bgImg(:,:,1)));
        elseif strfind(fname,'.tif')%tif image from somewhere else
            %not supported yet
            error('This file type is not supported (yet)')
        elseif strfind(fname,'.seq')%seq stack. turn it into an image
            %not supported yet
            error('This file type is not supported (yet)')
        else
            error('This file type is not supported (yet)')
        end
        
        %replot the face
        minval= min(min(value(faceIm)));
        maxval= max(max(value(faceIm)));
        cn=size(colormap,1);
        dmap=(maxval-minval)./cn;
        set(gca,'Clim',[minval-dmap maxval]);
        set(value(imHandle),'CDataMapping','scaled')
        set(value(imHandle),'CData',value(faceIm))
        
        %update plot
        MotorsSection(obj,'plot_grid');
        
    case 'load_poles'
        [fname, fpath, findex]=uigetfile(...
            {'*.mat', 'All .mat';
            '*.mat',  'mat files (*.mat)'; ...
            '*.*',  'All Files (*.*)'}, ...
            'Pick a file');
        
        load([fpath filesep fname]);
        %upodate table
        %tabledata_in= saved.MotorsSection_tabledata;
        %tabledata.data=tabledata_in.data;
        
        %update active location data
        actives_in=saved.JustinNoDiscrimn_active_locations;

        %mismatch_pr bug fix form previous versions...where did this come
        %from??
        if size(actives_in.id,2)~=size(actives_in.mismatch_pr,2)
            actives_in=rmfield(actives_in,'mismatch_pr');
            for v=1:1:numel(actives_in.id)
                actives_in.mismatch_pr{v}=[0 0 0 0];
            end
        end
        %same for handle num
        if size(actives_in.id,2)~=size( actives_in.handle_name,2)
            actives_in=rmfield(actives_in,'handle_name');
            for v=1:1:numel(actives_in.id)
                actives_in.handle_name{v}=['handle_' actives_in.name{v}];
            end
        end
        
        active_locations_tmp=actives_in;
        
        %active_location field name compatoabiliy checlk
        try
        [active_locations_tmp.mismatchId]=active_locations_tmp.mismatchID;
        active_locations_tmp=rmfield(active_locations_tmp, 'mismatchID');
        if numel(active_locations_tmp.mismatchId{1})<4
            for v=1:1:numel(active_locations_tmp.id)
                active_locations_tmp.mismatchId{v}=[0 0 0 0];
            end
        end
        catch
        end

        if ~isfield(active_locations_tmp,'stimEpochId')
            for v=1:1:numel(active_locations_tmp.id)
                active_locations_tmp.stimEpochId{v}=0;
            end  
        end
        
        for g=1:1:numel(actives_in.name)
            %scatter a point at 0,0 to get a handle number. We will change
            %the data of this point in the real plot function
            active_locations_tmp.handle_num{g} = scatter(value(myaxes),0,0);
        end
        %hack to implement backwards compatability
        %mismatch id
        if ~iscell(active_locations_tmp.coords)
            active_locations_tmp=rmfield(active_locations_tmp,'coords');
        end
        
        %make new table, AND fix any compatibility issues in
        %active_locations with current version of protocol
        for g=1:1:numel(active_locations_tmp.axial_positions)
            cell_data(g,1)=value(active_locations_tmp.name(g));
            cell_data(g,2)=value(active_locations_tmp.axial_positions(g));
            cell_data(g,3)=value(active_locations_tmp.radial_positions(g));
            
            %second half of a hack
            active_locations_tmp.coords{g}=[active_locations_tmp.axial_positions{g} active_locations_tmp.radial_positions{g}];
            
            cell_data(g,4)=value(active_locations_tmp.go_nogo(g));
            cell_data(g,5)=value(active_locations_tmp.sampleAction(g));
            cell_data(g,6)=value(active_locations_tmp.answerAction(g));
            cell_data(g,7)=value(active_locations_tmp.punishOn(g));
            cell_data(g,8)=value(active_locations_tmp.cue_name(g));
            cell_data(g,9)=value(active_locations_tmp.pr(g));
            %hack to implement backwards compatability
            if numel(active_locations_tmp.mismatch_pr(g)) ~= numel(active_locations.mismatch_pr{1})
                cell_data(g,10)={zeros(size(active_locations.mismatch_pr{1}))};
                active_locations_tmp.mismatch_pr(g)={zeros(size(active_locations.mismatch_pr{1}))};
            else
                cell_data(g,10)=value(active_locations_tmp.mismatch_pr(g));
            end
            cell_data(g,11)=value(active_locations_tmp.rewXr(g));
            try %another compatability hack
                cell_data(g,12)=value(active_locations_tmp.actionThreshXr(g));
            catch
                cell_data(g,12)=value(active_locations_tmp.threshXr(g));
            end
            cell_data(g,13)=value(active_locations_tmp.appearances(g));
            cell_data(g,14)=value(active_locations_tmp.touches(g));
            cell_data(g,15)={value(active_locations_tmp.hits{g}) + value(active_locations_tmp.CRs{g})};
            
        end
        
        prompt={'Do you want to load performance data (yes/no)?'};
        dlg_title='Input';
        num_lines=1;
        defaultans={'no'};
        answer=inputdlg(prompt,dlg_title,num_lines,defaultans);
        
        if strcmp(answer,'no')
            for g=13:1:15
                for v=1:numel(cell_data(:,g))
                    cell_data(v,g)={0};
                end
            end
               
        elseif strcmp(answer,'yes')
        else
            return
        end
        
        columninfo.titles=       {'Name',  'Axial', 'Radial', 'Go-NoGo', 'Samp. Axn', 'Answ. Axn', 'Punish On', 'Cue',   'Pr',    'Mism. Pr.', 'RewXr',  'ThrshXr', '# Appear.','# Samp. Acts..','# Correct.'};
        columninfo.formats =     {'%4.4g', '%4.4g', '%4.4g',  '%4.4g',   '%4.4g',     '%4.4g',     '%4.4g',     '%4.4g', '%4.4g', '%4.4g',     '%4.4g',  '%4.4g',   '%4.4g',     '%4.4g',    '%4.4g' };
        columninfo.weight =      [ 1,       1,      1,        1,         1,            1,           1,          1,       1,       1,           1,        1,         1,           1,           1];
        columninfo.multipliers = [ 1,       1,      1,        1,         1,            1,           1,          1,       1,       1,           1,        1,         1,           1,           1];
        columninfo.isEditable =  [ 0,       0,      0,        1,         1,            1,           1,          1,       1,       1,           1,        1,         0,           0,           0];
        columninfo.isNumeric  =  [ 0,       1,      1,        0,         0,            0,           1,          0,       1,       1,           1,        1,         1,           1,           1];
        %JPL - these checkboxes will radio poles enabled and disabled, and
        %gray them out on the display
        %if poles are right clicked in the display and set to 'disable' or
        %'enable', the radio button will follow
        %....BUT NONE OF THIS IS IMPLEMENTED YET
        
        %Write now checks arent being done properly, disabling
        
        %columninfo.withCheck = true; % optional to put checkboxes along left side
        %columninfo.chkLabel = 'Use'; % optional col header for checkboxes
        rowHeight = 15;
        gFont.size=7;
        gFont.name='Helvetica';
        
        set(gcf,'CurrentAxes',value(tbl))
        tabledata = mltable(get(gcf,'Number'), value(tbl), 'CreateTable', columninfo, rowHeight, cell_data, gFont);
        
        %load and plot the face, and shift axes via gui_origin
        faceIm.value=saved.MotorsSection_faceIm;
        minval=min(min(value(faceIm)));
        maxval=max(max(value(faceIm)));
        cn=size(colormap,1);
        dmap=(maxval-minval)./cn;
        if sum(sum(value(faceIm))) > 0
            set(gca,'Clim',[minval-dmap maxval]);
        end
        set(value(imHandle),'CDataMapping','scaled');
        set(value(imHandle),'CData',value(faceIm));
        
        axes(value(myaxes))
        
        set(gca,'YLim',[0-value(saved.MotorsSection_gui_origin_y) (size(value(faceIm),2).*value(saved.MotorsSection_mmPerPix))-(value(saved.MotorsSection_gui_origin_y))]);
        set(value(imHandle),'YData',[(size(value(faceIm),2).*value(saved.MotorsSection_mmPerPix))-(value(saved.MotorsSection_gui_origin_y)) 0-value(saved.MotorsSection_gui_origin_y) ]);
        
        set(gca,'XLim',[0-value(saved.MotorsSection_gui_origin_x) (size(value(faceIm),2).*value(saved.MotorsSection_mmPerPix))-(value(saved.MotorsSection_gui_origin_x))]);
        set(value(imHandle),'XData',[(size(value(faceIm),2).*value(saved.MotorsSection_mmPerPix))-(value(saved.MotorsSection_gui_origin_x)) 0-value(saved.MotorsSection_gui_origin_x)]);
        
        active_locations.value=active_locations_tmp;
        
        
        MotorsSection(obj,'plot_grid');
        
    case 'make_go'
        
        active_locations_tmp=value(active_locations);
        
        if value(current_location_index) ~=0
            current_location.name(value(current_location_index)) = ...
                value(active_locations_tmp.name(value(current_location_index)));
            
            active_locations_tmp.go_nogo(value(current_location_index)) = {'go'};
        else
            error('First select a pole location!')
        end
        
        active_locations.value=active_locations_tmp;
        
        MotorsSection(obj,'plot_grid');
        
    case 'make_nogo'
        
        active_locations_tmp=value(active_locations);
        
        
        if value(current_location_index) ~=0
            current_location.name(value(current_location_index)) = ...
                value(active_locations_tmp.name(value(current_location_index)));
            
            active_locations_tmp.go_nogo(value(current_location_index)) = {'nogo'};
        else
            error('First select a pole location!')
        end
        
        active_locations.value=active_locations_tmp;
        
        
        MotorsSection(obj,'plot_grid');
        
    case 'move_radial'
        
        move_absolute(pole_motors,value(move_rad)*10000,pole_motors_properties.radial_motor_num);
        MotorsSection(obj,'read_pole_positions');
        
    case 'move_axial'
        move_absolute(pole_motors,value(move_ax)*10000,pole_motors_properties.axial_motor_num);
        MotorsSection(obj,'read_pole_positions');
    case 'move_test'
        if value(current_location_index) ~=0
            
            %move based on a click of the 'Move' button
            currLocName = value(active_locations.name{value(current_location_index)});
            currLocInd=value(current_location_index);
            
        else
            error('First select a pole location!')
            
        end
        ind=currLocInd;
        move_absolute_mult(pole_motors,[value(motor_origin_x)*10000 + active_locations.coords{ind}(1)*10000 ...
            value(motor_origin_y)*10000 + active_locations.coords{ind}(2)*10000], ...
            [pole_motors_properties.radial_motor_num pole_motors_properties.axial_motor_num]);
        
        %MotorsSection(obj,'read_pole_positions');
        
    case 'move_next_side', % --------- CASE MOVE_NEXT_SIDE -----
        
        active_locations_tmp=value(active_locations);
        
        
        %'next_side' imported from TrialStructureSection
        
        %all next pole positions  imported from TrialStructureSection as
        %well...This is so we can apply antibiasing to their positions
        
        %%%--------LICKPORT ZABERS--------%%%
        %JPL-CURRENTLY NOT SUPPORTED
        
        %%%--------INIT POLE ZABERS--------%%%
        %JPL-CURRENTLY NOT SUPPORTED
        
        %%%--------POLE ZABERS ----------%%%
        
        %only move motors if we have to to avoid errors
        current_location_name.value = next_pos_id;
        
        %this gets called on the first 'empty' sm call. dont want this!
        if isempty(next_pos_id)
            return;
        end
        if ~strcmp('',value(next_mismatch_id))
            currentPoleId.value = find(strcmp(next_mismatch_id,value(active_locations_tmp.name))==1);
            current_location_index.value=find(strcmp(next_mismatch_id,value(active_locations_tmp.name))==1); %redudnant variable?
            %update the gui
            %highlight the appropriate row in the table
            posName=next_mismatch_id;
        else
            currentPoleId.value = find(strcmp(next_pos_id,value(active_locations_tmp.name))==1);
            current_location_index.value=find(strcmp(next_pos_id,value(active_locations_tmp.name))==1); %redudnant variable?
            %update the gui
            %highlight the appropriate row in the table
            posName=next_pos_id;
        end
        
        %create a GUI element that always displays the
        %current location now
        posRow=find(strcmp(posName,value(tabledata.data(:,1)))==1);
        set(value(motorfig),'CurrentAxes',value(tbl))
        tabledata.value=mltable(get(value(motorfig),'Number'), value(tbl), 'UpdateCellSelection',[],[],[],[],posRow);
        
        %check for table updates
        MotorsSection(obj,'poll_table_and_update');
        
        %plot the grid
        MotorsSection(obj,'plot_grid');
        
        %         nogo_position=[];
        %         if strmatch(next_type,'nogo')
        %             if isempty(nogo_position)
        %                 position = value(nogo_position);
        %                 warning('nogo position has not been defined!')
        %             else
        %                 position=[0 0];
        %             end
        %         end
        %
        tic
        
        %get index of nexct position
        ind=find(strcmp(next_pos_id,value(active_locations_tmp.name))==1);
        
        n_completed_trials=0;
        
        if n_completed_trials >= 1
            %update the number of times this position has appeared
            active_locations_tmp.appearances{ind}=value(active_locations_tmp.appearances{ind})+1;
            
            %update the table
            t=value(tabledata);
            t.data(ind,13)={value(active_locations_tmp.appearances{ind})}; %appearances
            t.data(ind,14)={value(active_locations_tmp.responses{ind})}; %needs to be responses
            t.data(ind,15)={value(active_locations_tmp.hits{ind})+value(active_locations_tmp.CRs{ind})}; %correcty
            tabledata.value=t;
            set(value(motorfig),'CurrentAxes',value(tbl))
            tabledata.value = mltable(get(value(motorfig),'Number'), value(tbl),'updateTable',[],[],t);
        end
        
        coordvect= (cell2mat(active_locations_tmp.coords(:)));
        if ~isempty(coordvect)
            prePoint=coordvect((randsample(1:size(coordvect,1),1)),:);
        end
        
        %get rid of all the non-valued table entires
        %tmp=value(tabledata);
        %tabledata_out.value=tmp.data(~strcmp('',tmp.data(:,1)),:);
        
        %save the table entires
        %tabledata_out.value=[value(tabledata_out); tabledata.data];
        
        %for GUI updating
        current_location_index.value=value(currentPoleId);
        curr_pole_name.value=value(active_locations_tmp.name{ind});
        
        % move motors to prepoint
        %move_absolute_mult(pole_motors,[prePoint(1)*10000,prePoint(2)*10000], ...
        %    [pole_motors_properties.radial_motor_num pole_motors_properties.axial_motor_num]);
        
        %  move motors to next location
        %move_absolute_mult(pole_motors,[value(motor_origin_x)*10000 + active_locations_tmp.coords{ind}(1)*10000 ...
        %    value(motor_origin_y)*10000 + active_locations_tmp.coords{ind}(2)*10000], ...
        %    [pole_motors_properties.radial_motor_num pole_motors_properties.axial_motor_num]);
        
        active_locations.value=active_locations_tmp;
        
        
        return;
        
    case 'pole_motor_home',
        move_home(pole_motors);
        return;
        
    case 'pole_serial_reset',
        close_and_cleanup(pole_motors);
        
        global pole_motors_properties;
        global pole_motors;
        
        if strcmp(pole_motors_properties.type,'@FakeZaberTCD1000')
            pole_motors = FakeZaberTCD1000;
        else
            pole_motors = ZaberTCD1000;
        end
        instreset;
        %serial_open(pole_motors);
        return;
        
    case 'pole_motor_stop',
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
        
        %serial_open(init_motors);
        return;
        
    case 'init_motor_stop',
        stop(init_motors);
        return;
        
    case 'init_motor_reset',
        reset(init_motors);
        return;
        
        %general motor stuff
    case 'serial_open',
        %serial_open(motors);
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
        active_locations_tmp=value(active_locations);
        
        axial_pole_motor_position.value = get_position(pole_motors,pole_motors_properties.axial_motor_num);
        radial_pole_motor_position.value = get_position(pole_motors,pole_motors_properties.radial_motor_num);
        %store current location for other classes
        active_locations_tmp.current=[value(axial_pole_motor_position) value(radial_pole_motor_position)];
        
        active_locations.value=active_locations_tmp;
        
        return;
        
    case {'update_loc_spacing','update_bar_diam','set_mmPerPix'}
        %recreate the grid
        
        %doesnt live update at the moment. Need to redraw a grid to see
        %changes
        
    case 'plot_grid'
        active_locations_tmp=value(active_locations);
        
        %first define the color vector for the scattergroup object. go
        %positions get green, no-go positions get black, current position
        %gets bold and blue markers
        
        nogo_inds = find(strcmp('nogo',value(active_locations_tmp.go_nogo))==1);
        go_inds = find(strcmp('go',value(active_locations_tmp.go_nogo))==1);
        CData = zeros(numel(value(active_locations_tmp.name)),3);
        
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
        
        for g=1:1:numel(value(active_locations_tmp.name))
            
            %create scatter group handle for this location and set its
            %properties
            axes(value(myaxes));
            %if the handle name for this pole is 'none', it has been
            %eliminated for now
            
            %set its properties
            set(value(active_locations_tmp.handle_num{g}),'xdata', value(active_locations_tmp.axial_positions{g}));
            set(value(active_locations_tmp.handle_num{g}),'ydata', value(active_locations_tmp.radial_positions{g}));
            set(value(active_locations_tmp.handle_num{g}),'ButtonDownFcn', [mfilename '(' class(obj) ',''buttonDownCallback'')']);
            axpos = get(value(myaxes),'Position');
            markerWidth =  (value(pole_diam))/diff(xlim)*axpos(3); % Calculate Marker width in points
            set(value(active_locations_tmp.handle_num{g}), 'SizeData', markerWidth^2);
            set(value(active_locations_tmp.handle_num{g}), 'MarkerFaceColor', CData(g,:));  %corresponds to go or no go
            
            if sum(strcmp(value(active_locations_tmp.cue_name{g}),value(cue_colors.name))) > 0
                set(value(active_locations_tmp.handle_num{g}), 'MarkerEdgeColor',...
                    value(cue_colors.color{find(strcmp(value(active_locations_tmp.cue_name{g}),...
                    value(cue_colors.name))==1)}));  %corresponds to cue type
            else
                set(value(active_locations_tmp.handle_num{g}), 'MarkerEdgeColor',[0 0 0]);  %corresponds to cue type
            end
            set(value(active_locations_tmp.handle_num{g}), 'LineWidth', 1);
            %if current location, make it bold
            if g == value(current_location_index)
                set(value(active_locations_tmp.handle_num{g}), 'LineWidth', 3);   %shows currently selected location
            end
            
        end
        
        active_locations.value=active_locations_tmp;
        
        
    case 'face_poly_def'
        
        active_locations_tmp=value(active_locations);
        
        %draw face polygon
        axes(value(myaxes));
        face=impoly;
        contour.value = wait(face);
        
        %ellimnate points in tgrid that are outside of the ellipse
        %first test if they are in the ellipse
        
        invect_face = inpolygon(cell2mat(value(active_locations_tmp.axial_positions)),cell2mat(value(active_locations_tmp.radial_positions)),value(contour(:,1)),value(contour(:,2)));
        
        %delete points and update table
        ind=find((invect_face == 1)==1);
        
        %create new
        active_locations_new=[];
        for g=1:1:numel(1:1:numel(active_locations.axial_positions)-numel(ind))
            active_locations_new.handle_num{g}=[];
            active_locations_new.handle_name{g}=[];
            active_locations_new.axial_positions{g}=[];
            active_locations_new.radial_positions{g}=[];
            active_locations_new.coords{g}=[];
            active_locations_new.thetapos{g}=[];
            active_locations_new.id{g}=[];
            active_locations_new.name{g}=[]; %need to keep this for now
            active_locations_new.cue_name{g}=[];
            active_locations_new.cue_id{g}=[];
            active_locations_new.go_nogo{g}=[];
            active_locations_new.appearances{g}=[];
            active_locations_new.hits{g}=[];
            active_locations_new.touches{g}=[];
            active_locations_new.handle_num{g}=[];
            active_locations_new.pr{g}=[];
            active_locations_new.miss{g}=[];
            active_locations_new.CRs{g}=[];
            active_locations_new.FAs{g}=[];
            active_locations_new.responses{g}=[];
            active_locations_new.rewXr{g}=[];
            active_locations_new.actionThreshXr{g}=[];
            active_locations_new.punishOn{g}=[];
            active_locations_new.enabled{g}=[];
            active_locations_new.stimEpochId{g}=[];
            active_locations_new.answerAction{g}=[];
            active_locations_new.sampleAction{g}=[];
        end
        
        %populate new
        counter=1;
        empty_row = {...
            '',  [], [], '', '', '', [],'', [], [], [], [], [], [], [];...
            };
        
        cell_data=[empty_row; repmat(empty_row,numel(active_locations_new.id)-1,1)];
        for g=1:1:numel(value(value(active_locations.id)))
            
            %delete old handle
            delete(value(active_locations.handle_num{g}));
            
            if ~ismember(g,ind)
                active_locations_new.axial_positions{counter}=active_locations_tmp.axial_positions{g};
                active_locations_new.radial_positions{counter}=active_locations_tmp.radial_positions{g};
                active_locations_new.coords{counter}=active_locations_tmp.coords{g};
                active_locations_new.thetapos{counter}=active_locations_tmp.thetapos{g};
                %%%ids are indexex by counter
                active_locations_new.id{counter}=counter;
                active_locations_new.name{counter}=['pos_' num2str(counter)];
                %%
                active_locations_new.cue_name{counter}=active_locations_tmp.cue_name{g};
                active_locations_new.cue_id{counter}=active_locations_tmp.cue_id{g};
                active_locations_new.go_nogo{counter}=active_locations_tmp.go_nogo{g};
                active_locations_new.appearances{counter}=active_locations_tmp.appearances{g};
                active_locations_new.hits{counter}=active_locations_tmp.hits{g};
                active_locations_new.pr{counter}=active_locations_tmp.pr{g};
                active_locations_new.miss{counter}=active_locations_tmp.miss{g};
                active_locations_new.CRs{counter}=active_locations_tmp.CRs{g};
                active_locations_new.FAs{counter}=active_locations_tmp.FAs{g};
                active_locations_new.responses{counter}=active_locations_tmp.responses{g};
                active_locations_new.rewXr{counter}=active_locations_tmp.rewXr{g};
                active_locations_new.actionThreshXr{counter}=active_locations_tmp.actionThreshXr{g};
                active_locations_new.punishOn{counter}=active_locations_tmp.punishOn{g};
                active_locations_new.enabled{counter}=active_locations_tmp.enabled{g};
                active_locations_new.answerAction{counter}=active_locations_tmp.answerAction{g};
                active_locations_new.sampleAction{counter}=active_locations_tmp.sampleAction{g};
                active_locations_new.stimEpochId{counter}=active_locations_tmp.stimEpochId{g};
                active_locations_new.isStimTrial{counter}=active_locations_tmp.isStimTrial{g};
                active_locations_new.isMismatchTrial{counter} =active_locations_tmp.isMismatchTrial{g};
                active_locations_new.mismatchId{counter} = active_locations_tmp.mismatchId{g};
                active_locations_new.mismatch_pr{counter} = active_locations_tmp.mismatch_pr{g};
                active_locations_new.stimEpochId{counter} = active_locations_tmp.stimEpochId{g};
                %scatter a point at 0,0 to get a handle number. We will change
                %the data of this point in the real plot function
                active_locations_new.handle_num{counter} = scatter(value(myaxes),0,0);
                active_locations_new.handle_name{counter} = ['handle_' active_locations_new.name{counter}];
                
                %update tablke
                cell_data(counter,1)=value(active_locations_new.name(counter));
                cell_data(counter,2)=value(active_locations_new.axial_positions(counter));
                cell_data(counter,3)=value(active_locations_new.radial_positions(counter));
                cell_data(counter,4)=value(active_locations_new.go_nogo(counter));
                cell_data(counter,5)=value(active_locations_new.sampleAction(counter));
                cell_data(counter,6)=value(active_locations_new.answerAction(counter));
                cell_data(counter,7)=value(active_locations_new.punishOn(counter));
                cell_data(counter,8)=value(active_locations_new.cue_name(counter));
                cell_data(counter,9)=value(active_locations_new.pr(counter));
                cell_data(counter,10)=value(active_locations_new.mismatch_pr(counter));
                cell_data(counter,11)=value(active_locations_new.rewXr(counter));
                cell_data(counter,12)=value(active_locations_new.actionThreshXr(counter));
                cell_data(counter,13)=value(active_locations_new.appearances(counter));
                cell_data(counter,14)=value(active_locations_new.touches(counter));
                cell_data(counter,15)={value(active_locations_new.hits{counter}) + value(active_locations_new.CRs{counter})};
                
                counter=counter+1;
                
            end
        end
        
        active_locations.value=active_locations_new;
        
        columninfo.titles=       {'Name',  'Axial', 'Radial', 'Go-NoGo', 'Samp. Axn', 'Answ. Axn', 'Punish On', 'Cue',   'Pr',    'Mism. Pr.', 'RewXr',  'ThrshXr', '# Appear.','# Samp. Acts..','# Correct.'};
        columninfo.formats =     {'%4.4g', '%4.4g', '%4.4g',  '%4.4g',   '%4.4g',     '%4.4g',     '%4.4g',     '%4.4g', '%4.4g', '%4.4g',     '%4.4g',  '%4.4g',   '%4.4g',     '%4.4g',    '%4.4g' };
        columninfo.weight =      [ 1,       1,      1,        1,         1,            1,           1,          1,       1,       1,           1,        1,         1,           1,           1];
        columninfo.multipliers = [ 1,       1,      1,        1,         1,            1,           1,          1,       1,       1,           1,        1,         1,           1,           1];
        columninfo.isEditable =  [ 0,       0,      0,        1,         1,            1,           1,          1,       1,       1,           1,        1,         0,           0,           0];
        columninfo.isNumeric  =  [ 0,       1,      1,        0,         0,            0,           1,          0,       1,       1,           1,        1,         1,           1,           1];
        %JPL - these checkboxes will radio poles enabled and disabled, and
        %gray them out on the display
        %if poles are right clicked in the display and set to 'disable' or
        %'enable', the radio button will follow
        %....BUT NONE OF THIS IS IMPLEMENTED YET
        
        %Write now checks arent being done properly, disabling
        
        %columninfo.withCheck = true; % optional to put checkboxes along left side
        %columninfo.chkLabel = 'Use'; % optional col header for checkboxes
        rowHeight = 15;
        gFont.size=7;
        gFont.name='Helvetica';
        
        %destreoy old table
        set(value(motorfig),'CurrentAxes',value(tbl))
        mltable(get(gcf,'Number'), value(tbl), 'DestroyTable');
        %create new table
        tbl.value = axes('units', 'pixels','position', [541 102 1000 300]);
        set(value(motorfig),'CurrentAxes',value(tbl))
        tabledata = mltable(get(gcf,'Number'), value(tbl), 'CreateTable', columninfo, rowHeight, cell_data, gFont);
        
        
        %check for table updates
        %plot the grid
        MotorsSection(obj,'plot_grid');
        delete(face);
        
    case 'def_origin'
        active_locations_tmp=value(active_locations);
        
        axes(value(myaxes));
        %click on the center of the pole in the image.
        [gui_origin_x.value,gui_origin_y.value] = ginput(1);
        
        %get the current motor position. Current position is read into
        %active_locations_tmp.current
        MotorsSection(obj,'read_pole_positions');
        
        motor_origin_x.value = value(axial_pole_motor_position);
        motor_origin_y.value = value(radial_pole_motor_position);
        
        %update axies
        set(gca,'YLim',[0-value(gui_origin_y) (size(value(faceIm),2).*value(mmPerPix))-(value(gui_origin_y))]);
        set(value(imHandle),'YData',[(size(value(faceIm),2).*value(mmPerPix))-(value(gui_origin_y)) 0-value(gui_origin_y) ]);
        
        set(gca,'XLim',[0-value(gui_origin_x) (size(value(faceIm),2).*value(mmPerPix))-(value(gui_origin_x))]);
        set(value(imHandle),'XData',[(size(value(faceIm),2).*value(mmPerPix))-(value(gui_origin_x)) 0-value(gui_origin_x)]);
        
        %update pole positions and values in table
        t=value(tabledata);
        
        %is this the first origin we have selected?
        if   numel(active_locations_tmp.axial_positions)<=1 && ((cell2mat(value(active_locations_tmp.axial_positions))==0)  && (cell2mat(value(active_locations_tmp.radial_positions))==0))
            for g=1:1:numel(value(active_locations_tmp.axial_positions))
                %JPL - pattern seems to be offset by a pole spacing. adding a
                %fix
                active_locations_tmp.axial_positions{g}=value(active_locations_tmp.axial_positions{g})-value(gui_origin_x)- 2*value(loc_spacing);
                active_locations_tmp.radial_positions{g}=value(active_locations_tmp.radial_positions{g})-value(gui_origin_y)- 2*value(loc_spacing);
                active_locations_tmp.coords{g} = [value(active_locations_tmp.axial_positions{g}) value(active_locations_tmp.radial_positions{g})];
                
                %update values in table
                t.data(g,2)={value(active_locations_tmp.radial_positions{g})};
                t.data(g,3)={value(active_locations_tmp.axial_positions{g})};
            end
            
        end
        %update table
        tabledata.value=t;
        set(value(motorfig),'CurrentAxes',value(tbl))
        tabledata.value = mltable(get(value(motorfig),'Number'), value(tbl),'updateTable',[],[],t);
        
        active_locations.value=active_locations_tmp;
        
        %check for table updates
        MotorsSection(obj,'poll_table_and_update');
        %replot the pole positions
        MotorsSection(obj,'plot_grid');
        
    case 'whisk_ellipse_def'
        %draw whisker ellipse
        axes(value(myaxes));
        whisk = imellipse;
        vertices.value = wait(whisk); %allows editing of the circle before returning
        active_locations_tmp=value(active_locations);
        %ellimnate points in tgrid that are outside of the ellipse
        %first test if they are in the ellipse
        invect_whisk = inpolygon(cell2mat(value(active_locations.axial_positions)),cell2mat(value(active_locations.radial_positions)),value(vertices(:,1)),value(vertices(:,2)));
        
        not_ind=find((invect_whisk == 0)==1);
        ind=find((invect_whisk == 1)==1);
        %clear the deleted points from the table data
        t=value(tabledata);
        %t.data(numel(value(active_locations.axial_positions))-numel(not_ind)+1:numel(value(active_locations.axial_positions)),:)= repmat({'' [0] [0] '' '' '' [0] '' [0] [0 0 0 0 0] [0] [0] [0] [0] [0]},numel(not_ind),1);
        t.data(numel(value(active_locations.axial_positions))-numel(not_ind)+1:numel(value(active_locations.axial_positions)),:)= repmat({'' [] [] '' '' '' [] '' [] [] [] [] [] [] []},numel(not_ind),1);
        %delete any stragglers from active locations
        names=value(active_locations.name([not_ind])); %store a copy of the original names referecing index positions
        
        for g=1:1:numel(not_ind)
   
            index=find(strcmp(value(active_locations.name),names(g))==1);
            
            %make sure the data gets hidden
            delete(active_locations_tmp.handle_num{index});
            active_locations_tmp.handle_num{index}=[];
            active_locations_tmp.handle_name{index}=[];
            
            active_locations_tmp.axial_positions{index}=[];
            active_locations_tmp.radial_positions{index}=[];
            active_locations_tmp.thetapos{index}=[];
            active_locations_tmp.coords{index}=[];
            active_locations_tmp.id{index}=[];
            active_locations_tmp.name{index}=[];
            active_locations_tmp.cue_name{index}=[];
            active_locations_tmp.cue_id{index}=[];
            active_locations_tmp.go_nogo{index}=[];
            active_locations_tmp.appearances{index}=[];
            active_locations_tmp.hits{index}=[];
            active_locations_tmp.touches{index}=[];
            active_locations_tmp.handle_num{index}=[];
            active_locations_tmp.pr{index}=[];
            active_locations_tmp.mismatch_pr{index}=[];
            active_locations_tmp.miss{index}=[];
            active_locations_tmp.CRs{index}=[];
            active_locations_tmp.FAs{index}=[];
            active_locations_tmp.responses{index}=[];
            active_locations_tmp.rewXr{index} = [];
            active_locations_tmp.actionThreshXr{index} = [];
            active_locations_tmp.punishOn{index} = [];
            active_locations_tmp.enabled{index} = [];
            active_locations_tmp.answerAction{index} = [];
            active_locations_tmp.sampleAction{index} = [];
            active_locations_tmp.isStimTrial{index} = [];
            active_locations_tmp.stimEpochId{index} = [];
            active_locations_tmp.isMismatchTrial{index} = [];
            active_locations_tmp.mismatchId{index} = [];
            
        end
        %renumber and rename remaining positions
        counter=1;
        
        active_locations_new=[];
        for g=1:1:numel(active_locations_tmp.axial_positions)
            if ~isempty(active_locations_tmp.id{g})
                active_locations_new.id{counter}=counter;
                active_locations_new.name{counter}={['pos_' num2str(counter)]};
                active_locations_new.handle_name{counter}={[active_locations_tmp.name{g} '_handle']};
                active_locations_new.pr{counter}=1/sum(cellfun(@(x) ~isempty(x), active_locations_tmp.axial_positions));
                active_locations_new.handle_num{counter}=active_locations_tmp.handle_num{g};
                active_locations_new.axial_positions{counter}=active_locations_tmp.axial_positions{g};
                active_locations_new.radial_positions{counter}=active_locations_tmp.radial_positions{g};
                active_locations_new.thetapos{counter}=active_locations_tmp.thetapos{g};
                active_locations_new.coords{counter}=active_locations_tmp.coords{g};
                active_locations_new.cue_name{counter}=active_locations_tmp.cue_name{g};
                active_locations_new.cue_id{counter}=active_locations_tmp.cue_id{g};
                active_locations_new.go_nogo{counter}=active_locations_tmp.go_nogo{g};
                active_locations_new.appearances{counter}=active_locations_tmp.appearances{g};
                active_locations_new.hits{counter}=active_locations_tmp.hits{g};
                active_locations_new.touches{counter}=active_locations_tmp.touches{g};
                active_locations_new.mismatch_pr{counter}=active_locations_tmp.mismatch_pr{g};
                active_locations_new.miss{counter}=active_locations_tmp.miss{g};
                active_locations_new.CRs{counter}=active_locations_tmp.CRs{g};
                active_locations_new.FAs{counter}=active_locations_tmp.FAs{g};
                active_locations_new.responses{counter}=active_locations_tmp.responses{g};
                active_locations_new.rewXr{counter}=active_locations_tmp.rewXr{g};
                active_locations_new.actionThreshXr{counter}=active_locations_tmp.actionThreshXr{g};
                active_locations_new.punishOn{counter}=active_locations_tmp.punishOn{g};
                active_locations_new.enabled{counter}=active_locations_tmp.enabled{g};
                active_locations_new.answerAction{counter}=active_locations_tmp.answerAction{g};
                active_locations_new.sampleAction{counter}=active_locations_tmp.sampleAction{g};
                active_locations_new.isStimTrial{counter}=active_locations_tmp.isStimTrial{g};
                active_locations_new.stimEpochId{counter}=active_locations_tmp.stimEpochId{g};
                active_locations_new.isMismatchTrial{counter}=active_locations_tmp.isMismatchTrial{g};
                active_locations_new.mismatchId{counter}=active_locations_tmp.mismatchId{g};
                
                active_locations_tmp.id{g}=counter;
                active_locations_tmp.name{g}=['pos_' num2str(counter)];
                active_locations_tmp.handle_name{g}=[active_locations_tmp.name{g} '_handle'];
                active_locations_tmp.pr{g}=1/numel(active_locations_tmp.axial_positions);
                active_locations_tmp.mismatch_pr{g}=0;

                counter=counter+1;
            end
        end
       
        active_locations.value=active_locations_new;
        
        empty_row= {'',[],[],'','','',[],'',[],[],[],[],[],[],[]};
        cell_data=[repmat(empty_row, numel(active_locations.id),1)];
        
        columninfo.titles=       {'Name',  'Axial', 'Radial', 'Go-NoGo', 'Samp. Axn', 'Answ. Axn', 'Punish On', 'Cue',   'Pr',    'Mism. Pr.', 'RewXr',  'ThrshXr', '# Appear.','# Samp. Acts..','# Correct.'};
        columninfo.formats =     {'%4.4g', '%4.4g', '%4.4g',  '%4.4g',   '%4.4g',     '%4.4g',     '%4.4g',     '%4.4g', '%4.4g', '%4.4g',     '%4.4g',  '%4.4g',   '%4.4g',     '%4.4g',    '%4.4g' };
        columninfo.weight =      [ 1,       1,      1,        1,         1,            1,           1,          1,       1,       1,           1,        1,         1,           1,           1];
        columninfo.multipliers = [ 1,       1,      1,        1,         1,            1,           1,          1,       1,       1,           1,        1,         1,           1,           1];
        columninfo.isEditable =  [ 0,       0,      0,        1,         1,            1,           1,          1,       1,       1,           1,        1,         0,           0,           0];
        columninfo.isNumeric  =  [ 0,       1,      1,        0,         0,            0,           1,          0,       1,       1,           1,        1,         1,           1,           1];
        %JPL - these checkboxes will radio poles enabled and disabled, and
        %gray them out on the display
        %if poles are right clicked in the display and set to 'disable' or
        %'enable', the radio button will follow
        %....BUT NONE OF THIS IS IMPLEMENTED YET
        
        %Write now checks arent being done properly, disabling
        
        %columninfo.withCheck = true; % optional to put checkboxes along left side
        %columninfo.chkLabel = 'Use'; % optional col header for checkboxes
        rowHeight = 15;
        gFont.size=7;
        gFont.name='Helvetica';
        
        for g=1:1:numel(active_locations_new.id)
            
            %update the table data

            cell_data(g,1)=active_locations_new.name{g};
            cell_data(g,2)=active_locations_new.axial_positions(g);
            cell_data(g,3)=active_locations_new.radial_positions(g);
            cell_data(g,4)=active_locations_new.go_nogo(g);
            cell_data(g,5)=active_locations_new.sampleAction(g);
            cell_data(g,6)=active_locations_new.answerAction(g);
            cell_data(g,7)=active_locations_new.punishOn(g);
            cell_data(g,8)=active_locations_new.cue_name(g);
            cell_data(g,9)=active_locations_new.pr(g);
            cell_data(g,10)=active_locations_new.mismatch_pr(g);
            cell_data(g,11)=active_locations_new.rewXr(g);
            cell_data(g,12)=active_locations_new.actionThreshXr(g);
            cell_data(g,13)=active_locations_new.appearances(g);
            cell_data(g,14)=active_locations_new.touches(g);
            cell_data(g,15)={cell2mat(active_locations_new.hits(g)) + cell2mat(active_locations_new.CRs(g))};
            
        end
        
        %destreoy old table
        set(gcf,'CurrentAxes',value(tbl))
        mltable(get(gcf,'Number'), value(tbl), 'DestroyTable');
        %create new table
        tbl.value = axes('units', 'pixels','position', [541 102 1000 300]);
        set(gcf,'CurrentAxes',value(tbl))
        tabledata = mltable(get(gcf,'Number'), value(tbl), 'CreateTable', columninfo, rowHeight, cell_data, gFont);
        
        delete(whisk);
        
        %check for table updates
        MotorsSection(obj,'poll_table_and_update');
        %plot the grid
        MotorsSection(obj,'plot_grid');
        
    case 'create_grid_rect'
        
        active_locations_tmp=value(active_locations);
        %for clearing the old data from the plot
        MotorsSection(obj,'plot_grid');
        
        %now delete the data and handles
        active_locations_tmp.coords=[];
        
        if  length(active_locations_tmp.axial_positions) > 0
            for g=1:1:length(active_locations_tmp.axial_positions)
                active_locations_tmp.axial_positions{g}=[];
                active_locations_tmp.radial_positions{g}=[];
                active_locations_tmp.thetapos{g}=[];
                active_locations_tmp.id{g}=[];
                active_locations_tmp.name{g}=[];
                active_locations_tmp.cue_name{g} = [];
                active_locations_tmp.cue_id{g} = [];
                active_locations_tmp.go_nogo{g} = [];
                active_locations_tmp.appearances{g}= [];
                active_locations_tmp.hits{g}=[];
                active_locations_tmp.touches{g}=[];
                active_locations_tmp.miss{g}=[];
                active_locations_tmp.CRs{g}=[];
                active_locations_tmp.FAs{g}=[];
                active_locations_tmp.responses{g}=[];
                active_locations_tmp.rewXr{g}=[];
                active_locations_tmp.actionThreshXr{g} = [];
                active_locations_tmp.punishOn{g} = [];
                active_locations_tmp.enabled{g} = [];
                active_locations_tmp.answerAction{g} = [];
                active_locations_tmp.sampleAction{g} = [];
                active_locations_tmp.isStimTrial{g} = [];
                active_locations_tmp.stimEpochId{g} = [];
                active_locations_tmp.isMismatchTrial{g} = [];
                active_locations_tmp.mismatchId{g} = [];
                
                active_locations_tmp.handle_name{g}=[];
                delete(active_locations_tmp.handle_num{g});
                active_locations_tmp.handle_num{g}=[];
                
            end
        end
        
        axes(value(myaxes));
        %draw rectangular region for location grid
        gridd = imrect;
        position = wait(gridd);
        
        %populate the grid with a hexagonaly spaced array of points. The spacing of
        %points and the point diam (in mm!) are the only input param.
        
        %draw triangular grid using the geom2d toolbox. Fills the entire rectangle
        %defined by 'position', store in active locations
        
        tgrid = triangleGrid([position(2) position(1) position(4)+position(2)...
            position(3)+position(1)], [position(2) position(1)],...
            value(loc_spacing) + value(value(pole_diam)));
        
        %add grid points to active locations
        %create ids and names for each of these points
        %default for a new grid is all cues = cue1, all go
        
        active_locations_tmp=[];
        %t.numRows=numel(tgrid);
        
        for g=1:1:length(tgrid)
            active_locations_tmp.axial_positions{g} = tgrid(g,2);
            active_locations_tmp.radial_positions{g} = tgrid(g,1);
            active_locations_tmp.coords{g}=[tgrid(g,2) tgrid(g,1)];
            active_locations_tmp.thetapos{g}=[];
            active_locations_tmp.id{g}=g;
            active_locations_tmp.name{g}=['pos_' num2str(g)];
            active_locations_tmp.cue_id{g} = 1;
            active_locations_tmp.cue_name{g} = 'cue_1';
            active_locations_tmp.go_nogo{g} = 'go';
            active_locations_tmp.appearances{g} = 0;
            active_locations_tmp.touches{g} = 0;
            active_locations_tmp.hits{g} = 0;
            active_locations_tmp.miss{g}=0;
            active_locations_tmp.CRs{g}=0;
            active_locations_tmp.FAs{g}=0;
            active_locations_tmp.mismatch_pr{g}=[0 0 0 0];
            active_locations_tmp.responses{g}=0;
            active_locations_tmp.pr{g} = 1/length(tgrid);
            active_locations_tmp.rewXr{g} = 1;
            active_locations_tmp.actionThreshXr{g} = 1.1;
            active_locations_tmp.punishOn{g} = 0;
            active_locations_tmp.enabled{g} = 1;
            active_locations_tmp.answerAction{g} = 'lick';
            active_locations_tmp.sampleAction{g} = 'none';
            active_locations_tmp.isStimTrial{g} = 0;
            active_locations_tmp.stimEpochId{g} = 0;
            active_locations_tmp.isMismatchTrial{g} = [0 0 0 0];
            active_locations_tmp.mismatchId{g} = [0 0 0 0];
            active_locations_tmp.handle_name{g}=[active_locations_tmp.name{g} '_handle'];
            
            %scatter a point at 0,0 to get a handle number. We will change
            %the data of this point in the real plot function
            active_locations_tmp.handle_num{g} = scatter(value(myaxes),0,0);

            %update the table data
            t.data(g,1)=value(active_locations_tmp.name(g));
            t.data(g,2)=value(active_locations_tmp.axial_positions(g));
            t.data(g,3)=value(active_locations_tmp.radial_positions(g));
            t.data(g,4)=value(active_locations_tmp.go_nogo(g));
            t.data(g,5)=value(active_locations_tmp.sampleAction(g));
            t.data(g,6)=value(active_locations_tmp.answerAction(g));
            t.data(g,7)=value(active_locations_tmp.punishOn(g));
            t.data(g,8)=value(active_locations_tmp.cue_name(g));
            t.data(g,9)=value(active_locations_tmp.pr(g));
            t.data(g,10)=value(active_locations_tmp.mismatch_pr(g));
            t.data(g,11)=value(active_locations_tmp.rewXr(g));
            t.data(g,12)=value(active_locations_tmp.actionThreshXr(g));
            t.data(g,13)=value(active_locations_tmp.appearances(g));
            t.data(g,14)=value(active_locations_tmp.touches(g));
            t.data(g,15)={value(active_locations_tmp.hits{g}) + value(active_locations_tmp.CRs{g})};
            
        end
        active_locations.value=active_locations_tmp;

        %make new table
        %first populate cell data with active loc info
        %blank tabledata
        
        empty_row= {'',[],[],'','','',[],'',[],[],[],[],[],[],[]};
        cell_data=[repmat(empty_row, numel(active_locations.id),1)];
        
        columninfo.titles=       {'Name',  'Axial', 'Radial', 'Go-NoGo', 'Samp. Axn', 'Answ. Axn', 'Punish On', 'Cue',   'Pr',    'Mism. Pr.', 'RewXr',  'ThrshXr', '# Appear.','# Samp. Acts..','# Correct.'};
        columninfo.formats =     {'%4.4g', '%4.4g', '%4.4g',  '%4.4g',   '%4.4g',     '%4.4g',     '%4.4g',     '%4.4g', '%4.4g', '%4.4g',     '%4.4g',  '%4.4g',   '%4.4g',     '%4.4g',    '%4.4g' };
        columninfo.weight =      [ 1,       1,      1,        1,         1,            1,           1,          1,       1,       1,           1,        1,         1,           1,           1];
        columninfo.multipliers = [ 1,       1,      1,        1,         1,            1,           1,          1,       1,       1,           1,        1,         1,           1,           1];
        columninfo.isEditable =  [ 0,       0,      0,        1,         1,            1,           1,          1,       1,       1,           1,        1,         0,           0,           0];
        columninfo.isNumeric  =  [ 0,       1,      1,        0,         0,            0,           1,          0,       1,       1,           1,        1,         1,           1,           1];
        %JPL - these checkboxes will radio poles enabled and disabled, and
        %gray them out on the display
        %if poles are right clicked in the display and set to 'disable' or
        %'enable', the radio button will follow
        %....BUT NONE OF THIS IS IMPLEMENTED YET
        
        %Write now checks arent being done properly, disabling
        
        %columninfo.withCheck = true; % optional to put checkboxes along left side
        %columninfo.chkLabel = 'Use'; % optional col header for checkboxes
        rowHeight = 15;
        gFont.size=7;
        gFont.name='Helvetica';
        
        for g=1:1:length(tgrid)
            %update the table data
            
            cell_data(g,1)=value(active_locations_tmp.name(g));
            cell_data(g,2)=value(active_locations_tmp.axial_positions(g));
            cell_data(g,3)=value(active_locations_tmp.radial_positions(g));
            cell_data(g,4)=value(active_locations_tmp.go_nogo(g));
            cell_data(g,5)=value(active_locations_tmp.sampleAction(g));
            cell_data(g,6)=value(active_locations_tmp.answerAction(g));
            cell_data(g,7)=value(active_locations_tmp.punishOn(g));
            cell_data(g,8)=value(active_locations_tmp.cue_name(g));
            cell_data(g,9)=value(active_locations_tmp.pr(g));
            cell_data(g,10)=value(active_locations_tmp.mismatch_pr(g));
            cell_data(g,11)=value(active_locations_tmp.rewXr(g));
            cell_data(g,12)=value(active_locations_tmp.actionThreshXr(g));
            cell_data(g,13)=value(active_locations_tmp.appearances(g));
            cell_data(g,14)=value(active_locations_tmp.touches(g));
            cell_data(g,15)={value(active_locations_tmp.hits{g}) + value(active_locations_tmp.CRs{g})};
            
        end
        
        %destreoy old table
        set(gcf,'CurrentAxes',value(tbl))
        mltable(get(gcf,'Number'), value(tbl), 'DestroyTable');
        %create new table
        tbl.value = axes('units', 'pixels','position', [541 102 1000 300]);
        set(gcf,'CurrentAxes',value(tbl))
        tabledata = mltable(get(gcf,'Number'), value(tbl), 'CreateTable', columninfo, rowHeight, cell_data, gFont);
%       tabl
%         tabledata.value = mltable(value(motorfig), value(tbl),'updateTable',[],[],tabledata);
% 
%         MotorsSection(obj,'poll_table_and_update')
%         
%         tabledata.value = mltable(value(motorfig), value(tbl),'updateTable',[],[],t);

        
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
        
    case 'poll_table_and_update'
        %update the table-editable fields of active locations
        active_locations_tmp=value(active_locations);
        
        for g=1:1:length(active_locations_tmp.axial_positions)
            t=get(value(tbl),'userdata');
            set(value(motorfig),'CurrentAxes',value(tbl))
            tabledata.value = mltable(get(value(motorfig),'Number'), value(tbl),'updateTable',[],[],t);
            
            %check that that the go-nogo-left-right cell is valid
            try
                if strcmp(tabledata.data(g,4),'go')>0 || strcmp(tabledata.data(g,4),'nogo')>0 || strcmp(tabledata.data(g,4),'left')>0 || strcmp(tabledata.data(g,4),'right')>0
                    active_locations_tmp.go_nogo(g) = tabledata.data(g,4);
                else
                    warning('go-nogo value must be either "go", "nogo", "left", or "right"')
                end
            catch
                
            end
            
            %check that that thesample period actions cell is valid
            if strcmp(tabledata.data(g,5),'none')>0 || strcmp(tabledata.data(g,5),'touch')>0 || strcmp(tabledata.data(g,5),'whisk')>0 || strcmp(tabledata.data(g,5),'lick')>0
                active_locations_tmp.sampleAction(g) = tabledata.data(g,5);
            else
            end
            
            %check that that the answer period actions cell is valid
            if strcmp(tabledata.data(g,6),'none')>0 || strcmp(tabledata.data(g,6),'touch')>0 || strcmp(tabledata.data(g,6),'whisk')>0 || strcmp(tabledata.data(g,6),'lick')>0
                active_locations_tmp.answerAction(g) = tabledata.data(g,6);
            else
            end
            
            
            %check punish on
            
            if isempty(cell2mat(tabledata.data(g,7)))
                active_locations_tmp.punishOn(g) = tabledata.data(g,7);
            elseif cell2mat(tabledata.data(g,7)) == 0 || cell2mat(tabledata.data(g,7)) == 1
                active_locations_tmp.punishOn(g) = tabledata.data(g,7);
            else
                warning('Pr values must be between 0 and 1')
            end
            
            %check that that the cue name cell is valid
            active_locations_tmp.cue_name(g) = tabledata.data(g,8);
            if ~ isempty(active_locations_tmp.cue_name{g})
                try
                    active_locations_tmp.cue_id(g) = {(SoundManagerSection(obj, 'get_sound_id', tabledata.data{g,8}))};
                catch
                    warning(['Cue name for ' active_locations_tmp.cue_name(g) 'is unknown!']);
                end
            else
                active_locations_tmp.cue_id(g) = tabledata.data(g,8);
            end
            
            %check that the Pr vales are between 0 and 1
            if ~isempty(cell2mat(tabledata.data(g,9)))
                if cell2mat(tabledata.data(g,9)) >= 0 && cell2mat(tabledata.data(g,9)) <= 1
                    active_locations_tmp.pr(g) = tabledata.data(g,9);
                else
                    warning('Pr values must be between 0 and 1')
                end
            end
            %check that the Pr values all add up to 1 - basically, just take
            %wahtever is in there as a weight, and renormalize
            
            %JPL -  this assigment was recasting active_locations_tmp.pr and really
            %screwing things up, leading to recomputation of pole prs and
            %eventually to a single pole being selected with much higher pr
            %than the others!
            
            %active_locations_tmp.pr = {cell2mat(active_locations_tmp.pr) ./ sum(cell2mat(active_locations_tmp.pr))};
            
            
            %check mismatches on location
            if ~isempty(cell2mat(tabledata.data(g,10)))
                tmp=cell2mat(tabledata.data(g,10));
                if  tmp(1) >= 0 && tmp(1) <= 1
                    active_locations_tmp.mismatch_pr{g}(1) = tmp(1);
                else
                    warning('Pr values must be between 0 and 1')
                end
            end
            
            %check mismatches on rewxr
            if ~isempty(cell2mat(tabledata.data(g,10)))
                tmp=cell2mat(tabledata.data(g,10));
                if  tmp(2) >= 0 && tmp(2) <= 1
                    active_locations_tmp.mismatch_pr{g}(2) = tmp(2);
                else
                    warning('Pr values must be between 0 and 1')
                end
            end
            
            %check mismatches on actionxr
            if ~isempty(cell2mat(tabledata.data(g,10)))
                tmp=cell2mat(tabledata.data(g,10));
                if  tmp(3) >= 0 && tmp(3) <= 1
                    active_locations_tmp.mismatch_pr{g}(3) = tmp(3);
                else
                    warning('Pr values must be between 0 and 1')
                end
            end
            
            %check mismatches on cue
            if ~isempty(cell2mat(tabledata.data(g,10)))
                tmp=cell2mat(tabledata.data(g,10));
                if  tmp(4) >= 0 && tmp(4) <= 1
                    active_locations_tmp.mismatch_pr{g}(4) = tmp(4);
                else
                    warning('Pr values must be between 0 and 1')
                end
            end
            
            
            
            %check on the reward multipliers
            if cell2mat(tabledata.data(g,11)) >= 0
                active_locations_tmp.rewXr(g) = tabledata.data(g,11);
            else
            end
            
            %check on the touch thresh multipliers
            if cell2mat(tabledata.data(g,12)) >= 0
                active_locations_tmp.actionThreshXr(g) = tabledata.data(g,12);
            else
            end
            
            active_locations.value=active_locations_tmp;
            
        end
    case 'choose_theta_point'
        
        axes(value(myaxes));
        %click on the center of the pole in the image.
        [theta_x.value,theta_y.value] = ginput(1);
        
    case 'buttonDownCallback'
        
        active_locations_tmp=value(active_locations);
        
        p = get(gca,'CurrentPoint');
        p = p(1,1:2);
        
        coordvect= (cell2mat(active_locations_tmp.coords(:)));
        
        %find the pole location nearest to the click point
        distances=sqrt((coordvect(:,1)-repmat(p(1),size(coordvect,1),1)).^2 ...
            + (coordvect(:,2)-repmat(p(2),size(coordvect,1),1)).^2);
        
        %set this point as the current point
        current_location_index.value=find(distances==min(distances));
        
        %update the data display for the data on this pole
        %radial_coord.value = active_locations_tmp.coords(value(current_location_index),1);
        %axial_coord.value = active_locations_tmp.coords(value(current_location_index),2);
        
        %highlight the appropriate row in the table
        %posName=active_locations_tmp.name{value(current_location_index)};
        %JPL - hack for now, create a GUI element that always displays the
        %current location now
        
        %curr_pole_name.value = posName;
        %posRow=find(strcmp(posName,value(tabledata.data(:,1)))==1);
        posRow=active_locations_tmp.id{value(current_location_index)};
            set(value(motorfig),'CurrentAxes',value(tbl))
        tabledata.value=mltable(get(value(motorfig),'Number'), value(tbl), 'UpdateCellSelection',[],[],[],[],posRow);
        
        %check for table updates
        MotorsSection(obj,'poll_table_and_update');
        
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
        currfig = get(gcf,'Number');
        
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



