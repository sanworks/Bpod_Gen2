% [x, y] = WaterValvesSection(obj, action, x, y)
%
% This plugin uses the water calibration table (constructed using
% @WaterCalibrationTable) to automatically translate from a desired water
% delivery amount into a time for which the water valve should be left
% open.
%
% GUI DISPLAY: Puts up two numerical editable fields, Left microliters and
% Right microliters, where the user can insert the desired dispense amount.
% To the right of these will be two display fields showing the
% corresponding times for which the valves should be left open. A title
% will be above all these GUI fields. If the GUIs for the desired amounts
% are edited by a user, (or changed by loading Solo settings), the dispense
% times will be automatically recalculated.
%
% Note that @WaterCalibrationTable figures out dispense times for amounts
% that are within 15% of the calibrated data points that it has; and that
% calibrations have finite lifetimes. If asking for a value that is beyond
% the known range of the calibration table, or the calibration table is out
% of date, a warning window will go up, dispense times will acquire a red
% background, and dispense times will go to a default value of 0.01 (i.e.,
% essentially nothing.) If your dispense times have a red background, that
% means "recalibrate your table before using them" !!
%
%
% PARAMETERS AND RETURNS:
% -----------------------
%
% obj      Default object argument.
%
% action   One of:
%
%   'init' x y
%            Initializes the plugin and sets up the GUI for it. Requires
%            two extra arguments, which will be the (x, y) coords, in
%            pixels, of the lower left hand corner of where this plugin's
%            GUI elements will start to be displayed in the current figure.
%            Returns [x, y], the position of the top left hand corner of
%            the plugin's GUI elements after they have been added to the
%            current figure.
%       Optional Params:
%       'streak_gui' 0
%            If 'streak_gui' is passed and set to 1 during init, then two
%            parameters are made visible that involve gemoetrically
%            increasing rewards for consecutive correct answers, ie.
%            'streaks': Streak_base and Streak_max.  See 'get_water_times'
%            for further details.
%            e.g. [x,y]=WaterValvesSection(obj,'init',x,y,'streak_gui',1);
%       'maxdays_error'    31
%            After this many days without a recalibration, the
%            @WaterCalibrationTable will give an error and refuse to
%            proceed.
%       'maxdays_warning'  25
%            After this many days without a recalibration, the
%            @WaterCalibrationTable will proceed ok, but will issue a
%            warning.
%       'show_calib_info' 0
%            If show_calib_info is passed in as 1 then two parameters are
%            made visible. Tech is the last technician to perform a
%            calibration on that rig and LastCalib is the date when that
%            rig was last calibrated.
%
%
%   'set_water_amounts'  l_uL r_uL
%            Requires two extra arguments; sets the GUI parameter for left
%            volume to the first of these, l_uL, and sets the GUI
%            parameter for right volume to the second, r_uL; then
%            recalculates the appropriate water dispense times. This action
%            is provided here to allow a command-line way of changing the
%            GUIs for left and right volume; the user can also change them
%            by hand, directly in the GUI.
%
%   'get_water_volumes' Returns two values, l_uL and r_uL
%
%   'get_water_times'  [streak_length=0]
%            Returns two values, LeftTime, and RightTime, which are the
%            water valve opening times that were calculated to correspond
%            to the GUI dispense amounts. Example call:
%              WaterValvesSection(obj,'get_water_times', 3);
%        Optional Params:
%            If an extra argument is passed in, this argument will be taken
%            to represent the "streak_length", i.e., the number of
%            immediately previous consecutive correct responses by the
%            subject. For example, if the previous four trials were miss,
%            correct, correct, correct, the streak would be three and you
%            could make the call as in:
%               WaterValvesSection(obj,'get_water_times', 3);
%            If this param is passed in, the returned Water time values are
%            augmented by the formula:
%               water_time*Streak_base^min(streak_length,Streak_max);
%            Generally you want Streak_base > 1, so that there is more
%            water for longer streaks.    
%
%   'calculate'
%            Force a recalculation of water dispanse times. This call
%            should normally never be needed by the user, since both
%            command line and GUI modes of changing desired dispense times
%            automaticaly force the recalculation.
%
%   'reinit' Delete all of this section's GUIs and data, and reinit, at the
%            same position on the same figure as the original section GUI
%            was placed.
%


% Written  by Carlos Brody 2007
% Modified by Jeff Erlich  2007
% Modified by Chuck Kopec  2009
% Overhaul by Chuck Kopec  2011 to work with new calibration

function [x, y] = WaterValvesSection(obj, action, x, y, varargin)

GetSoloFunctionArgs(obj);


pairs = { ...
    'maxdays_error'        90  ; ... %No longer used
    'maxdays_warning'      80  ; ... %No longer used
    };
parse_knownargs(varargin, pairs);

switch action
    case 'init',
        
        
        
        
        
        
        % Save the figure and the position in the figure where we are going to start adding GUI elements:
        SoloParamHandle(obj, 'my_gui_info', 'value', [x y gcf]);
        
        ToggleParam(obj, 'WaterShow', 0, x, y, 'OnString', 'WaterExtras Showing', ...
            'OffString', 'WaterExtras Hidden', 'TooltipString', 'Show/Hide Water Valves panel');
        set_callback(WaterShow, {mfilename, 'show_hide'}); %#ok<NODEF> (Defined just above)
        next_row(y);
        
        EditParam(obj,'Left_volume',     24,x,y,'position',[x    y  90 20],'labelfraction',0.7, 'label','Left uL');
        DispParam(obj,'LeftWValveTime',   0,x,y,'position',[x+90 y 110 20],'labelfraction',0.6,'label','Lt Wtr time');
        if ~isnan(bSettings('get','DIOLINES','left1water')); next_row(y);
        else make_invisible(Left_volume); make_invisible(LeftWValveTime); end %#ok<NODEF>
        
        EditParam(obj,'Center_volume',   24,x,y,'position',[x    y  90 20],'labelfraction',0.7, 'label','Center uL');
        DispParam(obj,'CenterWValveTime', 0,x,y,'position',[x+90 y 110 20],'labelfraction',0.6,'label','Ct Wtr time');
        if ~isnan(bSettings('get','DIOLINES','center1water')); next_row(y);
        else make_invisible(Center_volume); make_invisible(CenterWValveTime); end %#ok<NODEF>
        
        EditParam(obj,'Right_volume',    24,x,y,'position',[x    y  90 20],'labelfraction',0.7, 'label','Right uL');
        DispParam(obj,'RightWValveTime',  0,x,y,'position',[x+90 y 110 20],'labelfraction',0.6,'label','Rt Wtr time');
        if ~isnan(bSettings('get','DIOLINES','right1water')); next_row(y);
        else make_invisible(Right_volume); make_invisible(RightWValveTime); end %#ok<NODEF>
        
        
        SoloParamHandle(obj,'MaxDaysError',  'value',maxdays_error);
        SoloParamHandle(obj,'MaxDaysWarning','value',maxdays_warning);
        SoloParamHandle(obj,'RigID',         'value',bSettings('get','RIGS','Rig_ID'));
        SoloParamHandle(obj,'Valves',        'value',{});
        SoloParamHandle(obj,'Dispense',      'value',[]);
        SoloParamHandle(obj,'OpenTime',      'value',[]);
        
        
        
        SubheaderParam(obj,'title',mfilename,x,y); next_row(y, 1.5);
        
        
        
        SoloParamHandle(obj, 'my_xyfig', 'value', [x y gcf]);
        
        
        SoloParamHandle(obj, 'myfig', 'value', figure('Position', [ 226   671   233    65], ...
            'closerequestfcn', [mfilename '(' class(obj) ', ''hide'');'], 'MenuBar', 'none', ...
            'Name', mfilename), 'saveable', 0);
        set(gcf, 'Visible', 'off');
        
        
        nx=10; ny=10;
        DispParam(obj,'Tech',            '',nx,ny,'position',[nx    ny  90 20],'labelfraction',0.7);
        DispParam(obj,'LastCalib',       '',nx,ny,'position',[nx+90 ny 120 20],'labelfraction',0.45);
        
        next_row(ny);
        
        NumeditParam(obj,'Streak_base',1,nx,ny,'position',[nx ny 90 20],'labelfraction',0.75,'label','Streak Base');
        tts=sprintf(['\n The streak mulitplier is streak_base^streak_length.\n  '...
            'If streak base is 1, then water is delivered as normal, since 1^n is 1\n. '...
            'If streak base is >1 then the water delivered will grow exponentially\n'...
            'with # of correct trials in a row.  The streak length is passed as an input \n'...
            'parameter to get_water_times']);
        set_tooltipstring(Streak_base, tts);
        
        NumeditParam(obj,'Streak_max',6,nx,ny,'position',[nx+90 ny 120 20],'labelfraction',0.8,'label','Max Streak Length');
        tts=sprintf(['\n If streak length is >= MaxStreak then water  is watertime*streak_base^maxstreak.']);
        set_tooltipstring(Streak_max, tts);
        
        next_row(ny);
        
        feval(mfilename,obj,'hide');
        feval(mfilename,obj,'get_calibration_info');
        
       parent_fig=my_gui_info(3);
       figure(parent_fig);
       
        
        
    case 'get_calibration_info'
        %% get_calibration_info
        skip_calib = bSettings('get','WATER','skip_water_calib');
        
        if ~isnan(value(RigID))
            try
                try   
                    usingBdata = bSettings('get', 'GENERAL', 'use_bdata');
                catch 
                    usingBdata = 1;
                end
                if usingBdata == 1
                    DT = bdata(['select dateval from calibration_info_tbl where isvalid=1 and rig_id=',...
                        num2str(value(RigID)),' order by dateval desc']);
                    dt = DT{1}(1:10);

                    [USR DT VLV DSP TM] = bdata(['select initials, dateval, valve, dispense, timeval from',...
                        ' calibration_info_tbl where isvalid=1 and rig_id=',num2str(value(RigID)),...
                        ' and dateval like "',dt,'%"']);

                    Valves.value    = VLV;
                    Dispense.value  = DSP;
                    OpenTime.value  = TM;
                    Tech.value      = USR{1};

                    datetemp = DT{1}(1:10); datetemp(datetemp == '-') = ' ';
                    LastCalib.value = datetemp;
                else
                    disp('Warning: B-data NOT enabled for liquid calibration. No calibration values received.')
                    skip_calib = 1;
                end
            catch %#ok<CTCH>
                disp('ERROR: Cannot connect to bdata.calibration_info_tbl. No calibration values received.');
                skip_calib = 1;
            end
        else
            disp('ERROR: This rig has ID NaN. Valve times set to default.');
            skip_calib = 1;
        end
        
        
        if isnan(skip_calib) || skip_calib == 0
            set_callback({Left_volume;Center_volume;Right_volume}, {mfilename, 'calculate'});
            feval(mfilename, obj, 'calculate');
        else
            LeftWValveTime.value   = 0.5;
            CenterWValveTime.value = 0.5;
            RightWValveTime.value  = 0.5;
            
        end
        
        
        
    case 'calculate'
        %% calculate
        valves     = value(Valves);   %#ok<NODEF>
        valvenames = unique(valves);
        dispense   = value(Dispense); %#ok<NODEF>
        opentime   = value(OpenTime); %#ok<NODEF>
        
        for i = 1:length(valvenames)
            OT        = 0.1;
            thisvalve = strcmp(valves,valvenames{i});
            dsp       = dispense(thisvalve);
            ot        = opentime(thisvalve);
            
            if     strcmp(valvenames{i},'left1water');   volume = value(Left_volume);  %#ok<NODEF>
            elseif strcmp(valvenames{i},'center1water'); volume = value(Center_volume);
            elseif strcmp(valvenames{i},'right1water');  volume = value(Right_volume);  %#ok<NODEF>
            else
            end
            
            if length(dsp) >= 2 && length(ot) >= 2
                if length(dsp) > 2 || length(ot) > 2
                    disp('ERROR: Extra calibration points detected. All will be used.');
                end
                p = polyfit(dsp,ot,1);
                OT = (p(1) * volume) + p(2);
            else
                disp('ERROR: Less than 2 calibration points detected. Setting valve open time to default');
            end
            
            if     strcmp(valvenames{i},'left1water');   LeftWValveTime.value   = OT;
            elseif strcmp(valvenames{i},'center1water'); CenterWValveTime.value = OT;
            elseif strcmp(valvenames{i},'right1water');  RightWValveTime.value  = OT;
            else
            end
        end
        
        
        
        
    case 'set_water_amounts'
        %% set_water_amounts
        if nargin < 4, error('Need two extra args for this action'); end;
        Left_volume.value  = x;
        Right_volume.value = y;
        feval(mfilename, obj, 'calculate');
        
        
    case 'get_water_times'
        %% get_water_times
        if nargin>2; streak_len=min(x,value(Streak_max));
        else         streak_len=1;
        end
        
        x = LeftWValveTime *Streak_base^streak_len;  %#ok<NODEF>
        y = RightWValveTime*Streak_base^streak_len; %#ok<NODEF>
        return;
        
    case 'get_left_time'
        %% get_left_time
        if nargin>2; streak_len=min(x,value(Streak_max));
        else         streak_len=1;
        end
        
        x = LeftWValveTime *Streak_base^streak_len;  %#ok<NODEF>
        
    case 'get_center_time'
        %% get_center_time
        if nargin>2; streak_len=min(x,value(Streak_max));
        else         streak_len=1;
        end
        
        x = CenterWValveTime *Streak_base^streak_len;  %#ok<NODEF>
        
    case 'get_right_time'
        %% get_right_time
        if nargin>2; streak_len=min(x,value(Streak_max));
        else         streak_len=1;
        end
        
        x = RightWValveTime *Streak_base^streak_len;  %#ok<NODEF>
        
        
    case 'get_water_volumes'
        %% get_water_volumes
        x = value(Left_volume); %#ok<NODEF>
        y = value(Right_volume); %#ok<NODEF>
        
        
    case 'reinit',
        %% reinit
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
        
        
        %% SHOW HIDE
        
    case 'hide',
        WaterShow.value = 0; set(value(myfig), 'Visible', 'off');
        
    case 'show',
        WaterShow.value = 1; set(value(myfig), 'Visible', 'on');
        
    case 'show_hide',
        if WaterShow == 1, set(value(myfig), 'Visible', 'on'); %#ok<NODEF> (defined by GetSoloFunctionArgs)
        else                   set(value(myfig), 'Visible', 'off');
        end;
        
        
        % ------------------------------------------------------------------
        %%              CLOSE
        % ------------------------------------------------------------------
    case 'close'
        if exist('myfig', 'var') && isa(myfig, 'SoloParamHandle') && ishandle(value(myfig)),
           myfignum = value(myfig);
        else
           myfignum = [];
        end;
        delete_sphandle('owner', ['^@' class(obj) '$'], 'fullname', ['^' mfilename '_']);
        if ~isempty(myfignum), delete(myfignum); end;
end;



