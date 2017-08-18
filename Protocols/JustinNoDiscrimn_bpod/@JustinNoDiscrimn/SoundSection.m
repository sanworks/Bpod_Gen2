% [x, y] = SoundSection(obj, action, varargin)
%
% Section that takes care of defining and uploading sounds
%
% PARAMETERS:
% -----------
%
% obj      Default object argument.
%
% action   One of:w
%            'init'      To initialise the section and set up the GUI
%                        for it
%
%            'reinit'    Delete all of this section's GUflushIs and data,
%                        and reinit, at the same position on the same
%                        figure as the original section GUI was placed.
%
%           'make_sounds'   Use the current GUI params to make the
%                        sounds. Does not upload sounds.
%
%           'upload_sounds' If new sounds have been made since last
%                        upload, uploads them to the sounds machine.
%
%           'get_tone_duration'  Returns length, in milliseconds, of
%                        the sounds the rat should discriminate
%
%           'get_sound_ids'      Returns a structure with two
%                        fieldnames, 'right' and 'left'; the values of
%                        these fieldnames will be the sound numbers of
%                        the tone loaded as the Right sound and of the
%                        tone loaded as the Left sound, respectively.
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
% x        When action == 'get_tone_duration', x is length, in
%          milliseconds, of the sounds the rat should discriminate.
%
% x        When action == 'get_sound_ids', x is a structure with two
%          fieldnames, 'right' and 'left'; the values of these fieldnames
%          will be the sound numbers of the tone loaded as the Right sound
%          and of the tone loaded as the Left sound, respectively.
%


function [x, y] = SoundSection(obj, action, varargin)

GetSoloFunctionArgs;

global Solo_rootdir;

switch action
    case 'init',   % ---------- CASE INIT -------------

        %are we calibrating?
        
        x=varargin{1};
        y=varargin{2};

        % Save the figure and the position in the figure where we are
        % going to start adding GUI elements:
        fnum=gcf;
        SoloParamHandle(obj, 'my_gui_info', 'value', [x y fnum.Number]);
        % Old call to initialise sound system:
        %       rpbox('InitRP3StereoSound');

        %---DEFAULTS
        SoundDurationDefault=150; %ms
        SoundVolumeDefault=0.01;
        SoundFreqDefault=2000;

        %y=y+20;
        % ----------------- Speaker calibration data ------------------
        SettingsDir = fullfile(Solo_rootdir,'Settings');
        SoloParamHandle(obj, 'SpeakerCalibration','value',[],'saveable',0);
        SpeakerCalibrationFile = fullfile(SettingsDir,'SpeakerCalibration.mat');
        if(exist(SpeakerCalibrationFile,'file'));
            SpeakerCalibration.value = load(SpeakerCalibrationFile);
        else
            %SpeakerCalibration.FrequencyVector = [1,1e5];
            %SpeakerCalibration.AttenuationVector = 0.0032*[1,1]; % Around 70dB-SPL
            %SpeakerCalibration.TargetSPL = 70;
            warning('No calibration file found: %s\n  sound intensity will not be accurate!',...
                SpeakerCalibrationFile),
        end

        %---SOUNDER SERVER
        
        SoundManagerSection(obj,'init')

        SoloParamHandle(obj,'SoundStruct','value',[],'saveable',0);

        %%%struct for each tone
%JPL - make Go Sound a falling FM sweep
        %INIT TRIAL SOUND
        SoundStruct.init.Name  ='init';
        SoundStruct.init.Type  =  'FM Sweep';
        SoundStruct.init.Duration =75/1000; %conv to seconds
        SoundStruct.init.Volume = 0.001; %arbitary
        SoundStruct.init.Frequency=17000; %Hz
        SoundStruct.init.ModFrequency=18000; %Hz
        SoundStruct.init.ModIndex=0.01; %0 to 1
        %SoundStruct.init.Attenuation = SoundsSection(obj,'calculate_attenuation',SpeakerCalibration,...
        %                                       SoundStruct.init.Frequency,SoundStruct.init.Volume);
        SoundStruct.init.Waveform = SoundStruct.init.Volume.*MakeSigmoidSwoop(600000, 0, 22000, 18000,SoundStruct.init.Duration*1000, 1, 0, 1);
        %SoundStruct.init.Waveform = SoundSection(obj,'create_waveform',SoundStruct.init);
        [x, y]=SoundSection(obj,'make_interface',x,y,SoundStruct.init);
        y=y+25;
        %GO SOUND
%         SoundStruct.go.Name  ='go';
%         SoundStruct.go.Type  =  'Tone';
%         SoundStruct.go.Duration =SoundDurationDefault;
%         SoundStruct.go.Volume = SoundVolumeDefault; %arbitary
%         SoundStruct.go.Frequency=2000; %Hz
%         SoundStruct.go.ModFrequency=0; %Hz
%         SoundStruct.go.ModIndex=0; %0 to 1
%         SoundStruct.go.Waveform = [];

%JPL - make Go Sound a rising FM sweep
        SoundStruct.go.Name  ='go';
        SoundStruct.go.Type  =  'FM Sweep';
        SoundStruct.go.Duration =75/1000; %conv to seconds
        SoundStruct.go.Volume = 0.001; %arbitary
        SoundStruct.go.Frequency=19000; %Hz
        SoundStruct.go.ModFrequency=21000; %Hz
        SoundStruct.go.ModIndex=0.01; %0 to 1
        %SoundStruct.go.Attenuation = SoundsSection(obj,'calculate_attenuation',SpeakerCalibration,...
        %                                       SoundStruct.go.Frequency,SoundStruct.go.Volume);
        SoundStruct.go.Waveform = SoundStruct.go.Volume.*MakeSigmoidSwoop(600000, 0, 12500, 15500,SoundStruct.go.Duration*1000, 1,0,1);
        %SoundStruct.go.Waveform = SoundSection(obj,'create_waveform',SoundStruct.go);
        [x, y]=SoundSection(obj,'make_interface',x,y,SoundStruct.go);
        y=y+25;
        
        %REWARD TONE
%         SoundStruct.reward.Name  ='reward';
%         SoundStruct.reward.Type  =  'Tone';
%         SoundStruct.reward.Duration =SoundDurationDefault;
%         SoundStruct.reward.Volume = SoundVolumeDefault; %arbitary
%         SoundStruct.reward.Frequency=3000; %Hz
%         SoundStruct.reward.ModFrequency=0; %Hz
%         SoundStruct.reward.ModIndex=0; %0 to 1
%         SoundStruct.reward.Waveform = [];
%         SoundStruct.reward.Waveform = SoundSection(obj,'create_waveform',SoundStruct.reward);
%         [x, y]=SoundSection(obj,'make_interface',x,y,SoundStruct.reward);
%         y=y+25;
%JPL = make reward sound a pleasnt click!
        SoundStruct.reward.Name  ='reward';
        SoundStruct.reward.Type  =  'Click';
        SoundStruct.reward.Duration =SoundDurationDefault/1000; %conv to seconds
        SoundStruct.reward.Volume = 0.01; %arbitary
        SoundStruct.reward.Frequency=0; %Hz
        SoundStruct.reward.ModFrequency=0; %Hz
        SoundStruct.reward.ModIndex=0; %0 to 1
        %SoundStruct.reward.Attenuation = SoundsSection(obj,'calculate_attenuation',SpeakerCalibration,...
        %                                       SoundStruct.reward.Frequency,SoundStruct.reward.Volume);
        %SoundStruct.reward.Waveform = SoundStruct.reward.Volume*[MakeClick({0.0001}, {1.2}) zeros(1,10000) MakeClick({0.0001}, {1.2}) zeros(1,10000) MakeClick({0.0001}, {1.2})];
                %SoundStruct.reward.Waveform =
        SoundStruct.reward.Waveform=SoundStruct.reward.Volume.*MakeClick({20}, {1.2});
        %SoundStruct.reward.Waveform = SoundSection(obj,'create_waveform',SoundStruct.reward);
        [x, y]=SoundSection(obj,'make_interface',x,y,SoundStruct.reward);
        y=y+25;
        

%NOISE
        SoundStruct.noise.Name  ='noise';
        SoundStruct.noise.Type  =  'Noise';
        SoundStruct.noise.Duration =SoundDurationDefault/1000; %conv to seconds
        SoundStruct.noise.Volume = 0.005; 
        SoundStruct.noise.Frequency=20000; %Hzflush
        SoundStruct.noise.ModFrequency=20/3; %Hz
        SoundStruct.noise.ModIndex=0; %0 to 1
        SoundStruct.noise.Waveform = [];
        %SoundStruct.noise.Attenuation = SoundsSection(obj,'calculate_attenuation',SpeakerCalibration,...
        %                                       SoundStruct.noise.Frequency,SoundStruct.noise.Volume);
        SoundStruct.noise.Waveform = SoundSection(obj,'create_waveform',SoundStruct.noise);
        [x, y]=SoundSection(obj,'make_interface',x,y,SoundStruct.noise);

        %next colume is for pole cues
        y_col1=y;x_col1=x;
        y=2; x=x+220;

        %CUE TONE 1
        SoundStruct.cue_1.Name  ='cue_1';
        SoundStruct.cue_1.Type  =  'Tone';
        SoundStruct.cue_1.Duration =SoundDurationDefault/1000;
        SoundStruct.cue_1.Volume = 0.004; %arbitary
        SoundStruct.cue_1.Frequency=2200; %Hz
        SoundStruct.cue_1.ModFrequency=0; %Hz
        SoundStruct.cue_1.ModIndex=0.01; %0 to 1
        SoundStruct.cue_1.Waveform = [];
        %SoundStruct.cue_1.Attenuation = SoundsSection(obj,'calculate_attenuation',SpeakerCalibration,...
        %                                      SoundStruct.cue_1.Frequency,SoundStruct.cue_1.Volume);
        SoundStruct.cue_1.Waveform = SoundSection(obj,'create_waveform',SoundStruct.cue_1);
        [x, y]=SoundSection(obj,'make_interface',x,y,SoundStruct.cue_1);
        y=y+25;
        %CUE TONE 2
        SoundStruct.cue_2.Name  ='cue_2';
        SoundStruct.cue_2.Type  =  'Tone';
        SoundStruct.cue_2.Duration =SoundDurationDefault/1000;
        SoundStruct.cue_2.Volume = 0.001; %arbitary
        SoundStruct.cue_2.Frequency=3600; %Hz
        SoundStruct.cue_2.ModFrequency=0; %Hz
        SoundStruct.cue_2.ModIndex=0.01; %0 to 1
        SoundStruct.cue_2.Waveform = [];
        %SoundStruct.cue_2.Attenuation = SoundsSection(obj,'calculate_attenuation',SpeakerCalibration,...
        %                                       SoundStruct.cue_2.Frequency,SoundStruct.cue_2.Volume);
        SoundStruct.cue_2.Waveform = SoundSection(obj,'create_waveform',SoundStruct.cue_2);
        [x, y]=SoundSection(obj,'make_interface',x,y,SoundStruct.cue_2);
        y=y+25;
        %CUE TONE 3
        SoundStruct.cue_3.Name  ='cue_3';
        SoundStruct.cue_3.Type  =  'Tone';
        SoundStruct.cue_3.Duration =SoundDurationDefault/1000;
        SoundStruct.cue_3.Volume = 0.001; %arbitary
        SoundStruct.cue_3.Frequency=4300; %Hz
        SoundStruct.cue_3.ModFrequency=0; %Hz
        SoundStruct.cue_3.ModIndex=0.01; %0 to 1
        SoundStruct.cue_3.Waveform = [];
        %SoundStruct.cue_3.Attenuation = SoundsSection(obj,'calculate_attenuation',SpeakerCalibration,...
        %                                       SoundStruct.cue_3.Frequency,SoundStruct.cue_3.Volume);
        SoundStruct.cue_3.Waveform = SoundSection(obj,'create_waveform',SoundStruct.cue_3);
        [x, y]=SoundSection(obj,'make_interface',x,y,SoundStruct.cue_3);
        y=y+25;
        %CUE TONE 4
        SoundStruct.cue_4.Name  ='cue_4';
        SoundStruct.cue_4.Type  =  'Tone';
        SoundStruct.cue_4.Duration =SoundDurationDefault/1000; %conv to seconds
        SoundStruct.cue_4.Volume = 0.0005; %arbitary
        SoundStruct.cue_4.Frequency=5400; %Hz
        SoundStruct.cue_4.ModFrequency=0; %Hz
        SoundStruct.cue_4.ModIndex=0.01; %0 to 1
        SoundStruct.cue_4.Waveform = [];
        %SoundStruct.cue_4.Attenuation = SoundsSection(obj,'calculate_attenuation',SpeakerCalibration,...
        %                                       SoundStruct.cue_4.Frequency,SoundStruct.cue_4.Volume);
        SoundStruct.cue_4.Waveform = SoundSection(obj,'create_waveform',SoundStruct.cue_4);
        [x, y]=SoundSection(obj,'make_interface',x,y,SoundStruct.cue_4);
        y=y+25;
        %CUE TONE 5
        SoundStruct.cue_5.Name  ='cue_5';
        SoundStruct.cue_5.Type  =  'Tone';
        SoundStruct.cue_5.Duration =SoundDurationDefault/1000; %conv to seconds
        SoundStruct.cue_5.Volume = 0.0008; %arbitary
        SoundStruct.cue_5.Frequency=6600; %Hz
        SoundStruct.cue_5.ModFrequency=0; %Hz
        SoundStruct.cue_5.ModIndex=0.01; %0 to 1
        SoundStruct.cue_5.Waveform = [];
        %SoundStruct.cue_5.Attenuation = SoundsSection(obj,'calculate_attenuation',SpeakerCalibration,...
        %                                       SoundStruct.cue_5.Frequency,SoundStruct.cue_5.Volume);
        SoundStruct.cue_5.Waveform = SoundSection(obj,'create_waveform',SoundStruct.cue_5);
        [x, y]=SoundSection(obj,'make_interface',x,y,SoundStruct.cue_5);
        y=y+25;

        %CUE TONE 6
        SoundStruct.cue_6.Name  ='cue_6';
        SoundStruct.cue_6.Type  =  'Tone';
        SoundStruct.cue_6.Duration =SoundDurationDefault/1000; %conv to seconds
        SoundStruct.cue_6.Volume = 0.01; %arbitary
        SoundStruct.cue_6.Frequency=7600; %Hz
        SoundStruct.cue_6.ModFrequency=0; %Hz
        SoundStruct.cue_6.ModIndex=0.01; %0 to 1
        SoundStruct.cue_6.Waveform = [];
        %SoundStruct.cue_6.Attenuation = SoundsSection(obj,'calculate_attenuation',SpeakerCalibration,...
        %                                       SoundStruct.cue_6.Frequency,SoundStruct.cue_6.Volume);
        SoundStruct.cue_6.Waveform = SoundSection(obj,'create_waveform',SoundStruct.cue_6);
        [x, y]=SoundSection(obj,'make_interface',x,y,SoundStruct.cue_6);
        y=y+25;
        %CUE TONE 7
        SoundStruct.cue_7.Name  ='cue_7';
        SoundStruct.cue_7.Type  =  'Tone';
        SoundStruct.cue_7.Duration =SoundDurationDefault/1000; %conv to seconds
        SoundStruct.cue_7.Volume = 0.001; %arbitary
        SoundStruct.cue_7.Frequency=8400; %Hz
        SoundStruct.cue_7.ModFrequency=0; %Hz
        SoundStruct.cue_7.ModIndex=0.01; %0 to 1
        SoundStruct.cue_7.Waveform = [];
        %SoundStruct.cue_7.Attenuation = SoundsSection(obj,'calculate_attenuation',SpeakerCalibration,...
        %                                       SoundStruct.cue_7.Frequency,SoundStruct.cue_7.Volume);
        SoundStruct.cue_7.Waveform = SoundSection(obj,'create_waveform',SoundStruct.cue_7);
        [x, y]=SoundSection(obj,'make_interface',x,y,SoundStruct.cue_7);
        y=y+25;
        %CUE TONE 8
        SoundStruct.cue_8.Name  ='cue_8';
        SoundStruct.cue_8.Type  =  'Tone';
        SoundStruct.cue_8.Duration =SoundDurationDefault/1000; %conv to seconds
        SoundStruct.cue_8.Volume = 0.01; %arbitary
        SoundStruct.cue_8.Frequency=9600; %Hz
        SoundStruct.cue_8.ModFrequency=0; %Hz
        SoundStruct.cue_8.ModIndex=0.01; %0 to 1
        SoundStruct.cue_8.Waveform = [];
        %SoundStruct.cue_8.Attenuation = SoundsSection(obj,'calculate_attenuation',SpeakerCalibration,...
        %                                       SoundStruct.cue_8.Frequency,SoundStruct.cue_8.Volume);
        SoundStruct.cue_8.Waveform = SoundSection(obj,'create_waveform',SoundStruct.cue_8);
        [x, y]=SoundSection(obj,'make_interface',x,y,SoundStruct.cue_8);

        y=2;x=880;

        SubheaderParam(obj,'title','Sound Section',x_col1, y_col1+200,'width', 425)
        SubheaderParam(obj,'title','Sound Tools',x_col1, y_col1+200,'width', 200)
        SubheaderParam(obj,'title','Pole Cues',x_col1+220, y_col1+200,'width', 200)
        SubheaderParam(obj,'title','Fixed Cues',x_col1, y_col1+20,'width', 200)

        %---LOOPING
        %ToggleParam(obj,'SoundLoop',0,x_col1+220,y_col1,'position',[x_col1 + 220 y_col1 60 20],...
        %    'OnString','Loop On','OffString','Loop Off','TooltipString',...
        %    sprintf(['\n..''\nIf ON (black), on''\nIf OFF (brown), off']));
        %set_callback(SoundLoop,{mfilename,'update_soundloop'});

        %%%MAKE SOUND CUE NAME Cell FOR MOTORS SECTION
        cueNames=fields(value(SoundStruct));
        ind=1;
        for b=1:1:numel(cueNames)
            if strfind(cueNames{b},'cue_')
                PoleCueList{ind}=cueNames{b};
                ind=ind+1;
            end
        end
        %add a final cue of 'none' for motor section purposes
        PoleCueList{ind+1}='none';

        %NO CUE
        SoundStruct.none.Name  ='none';
        SoundStruct.none.Type  =  'FM';
        SoundStruct.none.Duration =0;
        SoundStruct.none.Volume = 0; %arbitary
        SoundStruct.none.Frequency=0; %Hz
        SoundStruct.none.ModFrequency=0; %Hz
        SoundStruct.none.ModIndex=0.0; %0 to 1
        SoundStruct.none.Waveform = [];
        SoundStruct.none.Waveform = SoundSection(obj,'create_waveform',SoundStruct.none);

        %DECLARE all sounds
        SoundManagerSection(obj,'declare_new_sound', 'cue_1', [0]);
        SoundManagerSection(obj,'declare_new_sound', 'cue_2', [0]);
        SoundManagerSection(obj,'declare_new_sound', 'cue_3', [0]);
        SoundManagerSection(obj,'declare_new_sound', 'cue_4', [0]);
        SoundManagerSection(obj,'declare_new_sound', 'cue_5', [0]);
        SoundManagerSection(obj,'declare_new_sound', 'cue_6', [0]);
        SoundManagerSection(obj,'declare_new_sound', 'cue_7', [0]);
        SoundManagerSection(obj,'declare_new_sound', 'cue_8', [0]);
        SoundManagerSection(obj,'declare_new_sound', 'init', [0]);
        SoundManagerSection(obj,'declare_new_sound', 'reward', [0]);
        SoundManagerSection(obj,'declare_new_sound', 'go', [0]);
        SoundManagerSection(obj,'declare_new_sound', 'noise', [0]);
        SoundManagerSection(obj,'declare_new_sound', 'none', [0]);
        
        %SET all sounds     
        SoundManagerSection(obj,'set_sound', 'cue_1', SoundStruct.cue_1.Waveform);
        SoundManagerSection(obj,'set_sound', 'cue_2', SoundStruct.cue_2.Waveform);
        SoundManagerSection(obj,'set_sound', 'cue_3', SoundStruct.cue_3.Waveform);
        SoundManagerSection(obj,'set_sound', 'cue_4', SoundStruct.cue_4.Waveform);
        SoundManagerSection(obj,'set_sound', 'cue_5', SoundStruct.cue_5.Waveform);
        SoundManagerSection(obj,'set_sound', 'cue_6', SoundStruct.cue_6.Waveform);
        SoundManagerSection(obj,'set_sound', 'cue_7', SoundStruct.cue_7.Waveform);
        SoundManagerSection(obj,'set_sound', 'cue_8', SoundStruct.cue_8.Waveform);
        SoundManagerSection(obj,'set_sound', 'init', SoundStruct.init.Waveform);
        SoundManagerSection(obj,'set_sound', 'reward', SoundStruct.reward.Waveform);
        SoundManagerSection(obj,'set_sound', 'go', SoundStruct.go.Waveform);
        SoundManagerSection(obj,'set_sound', 'noise', SoundStruct.noise.Waveform);
        SoundManagerSection(obj,'set_sound', 'none', SoundStruct.none.Waveform);

        %upload sounds
        SoundSection(obj,'update_all_sounds');

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %SECTION FOR BUILDING A SERIES OF TONES FORF CALIBRATION PURPOSES%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %seems to have a limit of only 128 (2^7) sounds to load
        %into RT!
        
        %we have 13 sounds already, plus 1 for white noise
        
        %will need to do this in several frequency bands for fine
        %resolution
%         minFreq=2000; %in Hz
%         maxFreq=22000;
%         interval=ceil((maxFreq-minFreq)/(128-15));
%         freqVec=[minFreq:interval:maxFreq];
%       
%         %for volumes, will just neeed to adjust this param for each sound,
%         %defined by frequency
%         minVol=1;
%         maxVol=100000;
%         volInterval=15000;
%         volVec=[minVol:volInterval:maxVol];
% 
%         %hack
%         %structres dont like exponetentials as names...multiply volumes to
%         %get out of the decimal range
%         scaleVName=1;
% 
%         %loop through frequencies
%         for b=1:1:numel(freqVec)
%             SoundStruct.(['c_' num2str(freqVec(b)) '_' num2str(minVol*scaleVName)]).Name  =[num2str(freqVec(b)) '_' num2str(minVol*scaleVName)];
%             SoundStruct.(['c_' num2str(freqVec(b)) '_' num2str(minVol*scaleVName)]).Type  =  'Tone';
%             SoundStruct.(['c_' num2str(freqVec(b)) '_' num2str(minVol*scaleVName)]).Duration =0.1;
%             SoundStruct.(['c_' num2str(freqVec(b)) '_' num2str(minVol*scaleVName)]).Volume = minVol;
%             SoundStruct.(['c_' num2str(freqVec(b)) '_' num2str(minVol*scaleVName)]).Frequency=freqVec(b); %Hz
%             SoundStruct.(['c_' num2str(freqVec(b)) '_' num2str(minVol*scaleVName)]).Waveform = SoundSection(obj,'create_waveform',SoundStruct.(['c_' num2str(freqVec(b)) '_' num2str(minVol*scaleVName)]));
% 
%             %set this sound
%             SoundManagerSection(obj,'declare_new_sound', ['c_' num2str(freqVec(b)) '_' num2str(minVol*scaleVName)], [0]);
%             SoundManagerSection(obj, 'set_sound', ['c_' num2str(freqVec(b)) '_' num2str(minVol*scaleVName)], SoundStruct.(['c_' num2str(freqVec(b)) '_' num2str(minVol*scaleVName)]).Waveform);
%         end
% 
%         %transfer function
% 
%         %finally create a white noise stim for transfer fucntion estimation
%         SoundStruct.(['white_' num2str(minVol*scaleVName)]).Name  =['white_' num2str(minVol*scaleVName)];
%         SoundStruct.(['white_' num2str(minVol*scaleVName)]).Type  =  'Noise';
%         SoundStruct.(['white_' num2str(minVol*scaleVName)]).Duration = 0.1;
%         SoundStruct.(['white_' num2str(minVol*scaleVName)]).Volume = minVol;
%         SoundStruct.(['white_' num2str(minVol*scaleVName)]).Waveform = SoundSection(obj,'create_waveform',SoundStruct.(['white_' num2str(minVol*scaleVName)]));
% 
%         %set this sound
%         SoundManagerSection(obj,'declare_new_sound', ['white_' num2str(minVol*scaleVName)], [0]);
%         SoundManagerSection(obj, 'set_sound', ['white_' num2str(minVol*scaleVName)], SoundStruct.(['white_' num2str(minVol*scaleVName)]).Waveform);
% 
% 
%         %updatge these soudns
%         SoundSection(obj,'update_all_sounds');
        %upload the sounds
        SoundManagerSection(obj,'send_not_yet_uploaded_sounds')

    case 'hide'
        SoundParamsShow.value=0;
        set(value(myfig),'Visible','off');

    case 'show'
        SoundParamShow.value=1;
        set(value,'Visible','on');

    case 'show_hide'
        if value(SoundParamsShow)==1
            set(value(myfig),'Visible','on');
        else
            set(value(myfig),'Visible','off');
        end

    case 'update_sound'
        
        %add functionality from Gowan
        ThisSoundName = varargin{1};
        SoundStruct.(ThisSoundName).Volume   = value(eval([ThisSoundName 'Volume']));
        SoundStruct.(ThisSoundName).Frequency= value(eval([ThisSoundName 'Frequency']));
        %SoundStruct.(ThisSoundName).Attenuation = SoundsSection(obj,'calculate_attenuation',...
        %                                                  SpeakerCalibration,...
        %                                                  SoundStruct.(ThisSoundName).Frequency,...
        %                                                  SoundStruct.(ThisSoundName).Volume);
        %-- Bad Solo programming, it shouldn't use get_sphandle! --%
        %AttenuationGUI = get_sphandle('name',[SoundStruct.(ThisSoundName).Name,'Attenuation']);
        %AttenuationGUI{1}.value_callback = SoundStruct.(ThisSoundName).Attenuation;
        if sum(strcmp(SoundStruct.(ThisSoundName).Type, {'Tone'; 'FM'; 'AM'; 'Noise';'Click'}))>=1;
            SoundStruct.(ThisSoundName).Waveform = SoundSection(obj,'create_waveform',SoundStruct.(ThisSoundName));
        else
            %only the volume and balance are editable parameters here
        end
        SoundManagerSection(obj, 'set_sound', ThisSoundName, SoundStruct.(ThisSoundName).Waveform);
        %SoundSection(obj,'update_all_sounds');

    case'update_soundLoop'
        if value(SoundLoop),
            sndlp=1;
        else
            sndlp=0;
        end

        SoundManagerSection(obj,'loop_sound', 'cue_1', sndlp);
        SoundManagerSection(obj,'loop_sound', 'cue_2', sndlp);
        SoundManagerSection(obj,'loop_sound', 'cue_3', sndlp);
        SoundManagerSection(obj,'loop_sound', 'cue_4', sndlp);
        SoundManagerSection(obj,'loop_sound', 'cue_5', sndlp);
        SoundManagerSection(obj,'loop_sound', 'cue_6', sndlp);
        SoundManagerSection(obj,'loop_sound', 'cue_7', sndlp);
        SoundManagerSection(obj,'loop_sound', 'cue_8', sndlp);
        SoundManagerSection(obj,'loop_sound', 'init', sndlp);
        SoundManagerSection(obj,'loop_sound', 'reward', sndlp);
        SoundManagerSection(obj,'loop_sound', 'go', sndlp);
        SoundManagerSection(obj,'loop_sound', 'noise', sndlp);

    case 'make_interface'
        
        x=varargin{1};
        y=varargin{2};
        ThisSound=varargin{3};
        if ~strcmp(ThisSound.Type,'noise')
            NumeditParam(obj,[ThisSound.Name 'Frequency'],ThisSound.Frequency,x,y,...
                'label', 'Frequency',...
                'position',[x y 120 20],...
                'TooltipString', 'frequency [Hz]');
            set_callback(eval([ThisSound.Name 'Frequency']),{mfilename, 'update_sound',ThisSound.Name});
        end

        if ~strcmp(ThisSound.Type, 'noise')
            NumeditParam(obj,[ThisSound.Name, 'Volume'],ThisSound.Volume,x+125,y,...
                'label','Volume',...
                'position',[x+125 y 75 20],...
                'TooltipString', 'Volume [0-1]');
            next_row(y);
            set_callback(eval([ThisSound.Name 'Volume']),{mfilename,'update_sound',ThisSound.Name});
            SubheaderParam(obj,[ThisSound.Name 'Head'],...
                sprintf('%s (%s)', ThisSound.Name, ThisSound.Type),x,y);
        else
            SubheaderParam(obj,[ThisSound.Name 'Head'],...
                sprintf('%s (%s)',ThisSound.Name,ThisSound.Type),x,y);
            NumeditParam(obj,[ThisSound.Name 'Volume'],ThisSound.Volume, x+125,y,...
                'label','Volume',...
                'position',[x+125 y 75 20],...
                'TooltipString','Volume [0-1]');
            set_callback(eval([ThisSound.Name 'Volume']),{mfilename, 'update_sound',ThisSound.Name});
        end

        PushbuttonParam(obj,[ThisSound.Name 'Play'],x,y,...
            'label','Play',...
            'position',[x y 30 20]);
        set_callback(eval([ThisSound.Name 'Play']),{'SoundManagerSection','play_sound',ThisSound.Name});

        PushbuttonParam(obj,[ThisSound.Name 'Stop'],x,y,...
            'label','Stop',...
            'position',[x+30 y 30 20]);
        set_callback(eval([ThisSound.Name 'Stop']),{'SoundManagerSection','stop_sound',ThisSound.Name});

    case 'create_waveform'

        ThisSound=varargin{1};
        srate=SoundManagerSection(obj,'get_sample_rate');
        TimeVec=(0:1/srate:ThisSound.Duration);
        switch ThisSound.Type
            
            case 'Click'
                %dont do anything, taken care of
            case 'FM Sweep'
                %dont do anything, taken care of
            case 'Tone'
                ThisSound.Waveform=ThisSound.Volume*sin(2*pi*ThisSound.Frequency*TimeVec);
            case 'Noise'
                ThisSound.Waveform=ThisSound.Volume*randn(1,length(TimeVec));
            case 'AM'
                SoundCarrier=sin(2*pi*ThisSound.Frequency*TimeVec);
                SoundModulatory=1-0.5*ThisSound.ModDepth+...
                    0.5*ThisSound.ModDepth*sin(2*pi*ThisSound.ModFrequency*TimeVec-pi/2);
                ThisSound.Waveform=SoundCarrier.*SoundModulatory;
                ThisSound.Waveform=ThisSound.Waveform/std(ThisSound.Waveform);
                ThisSound.Waveform=ThisSound.Volume*ThisSound.Waveform;
            case 'FM'
                SoundModulatory=ThisSound.ModIndex*ThisSound.Frequency*...
                    sin(2*pi*ThisSound.ModFrequency*TimeVec);
                ThisSound.Waveform=ThisSound.Volume*...
                    sin(2*pi*ThisSound.Frequency*TimeVec+SoundModulatory);
            case 'TonesTrain'
                SilencePeriod = zeros(1,round(ThisSound.SilenceDuration*srate));
                ThisSound.Waveform = [];
                for indtone=1:length(ThisSound.TonesFrequency)
                    ThisTone = ThisSound.Attenuation(indtone) * ...
                        sin(2*pi*ThisSound.TonesFrequency(indtone)*TimeVec);
                    ThisTone = apply_raisefall(ThisTone,RaiseFallDuration,srate);
                    ThisSound.Waveform = [ThisSound.Waveform, ThisTone, SilencePeriod];
                end

            otherwise
                error('Unknown sound type: %s', ThisSound.Type);

        end
        x = ThisSound.Waveform;

    case 'update_all_sounds',      % ---------- CASE UPLOAD_SOUNDS -------------

%        SoundManagerSection(obj,'set_sound', 'cue_1', SoundStruct.c1.Waveform(:), value(SoundLoop));
%        SoundManagerSection(obj,'set_sound', 'cue_2', SoundStruct.c2.Waveform(:), value(SoundLoop));
%       SoundManagerSection(obj,'set_sound', 'cue_3', SoundStruct.c3.Waveform(:), value(SoundLoop));
%        SoundManagerSection(obj,'set_sound', 'cue_4', SoundStruct.c4.Waveform(:), value(SoundLoop));
%       SoundManagerSection(obj,'set_sound', 'cue_5', SoundStruct.c5.Waveform(:), value(SoundLoop));
%       SoundManagerSection(obj,'set_sound', 'cue_6', SoundStruct.c6.Waveform(:), value(SoundLoop));
%       SoundManagerSection(obj,'set_sound', 'cue_7', SoundStruct.c7.Waveform(:), value(SoundLoop));
%        SoundManagerSection(obj,'set_sound', 'cue_8', SoundStruct.c8.Waveform(:), value(SoundLoop));
%       SoundManagerSection(obj,'set_sound', 'init', SoundStruct.init.Waveform(:), value(SoundLoop));
%       SoundManagerSection(obj,'set_sound', 'reward', SoundStruct.rew.Waveform(:), value(SoundLoop));
%       SoundManagerSection(obj,'set_sound', 'go', SoundStruct.go.Waveform(:), value(SoundLoop));
%       SoundManagerSection(obj,'set_sound', 'noise', SoundStruct.noise.Waveform(:), value(SoundLoop));
%       SoundManagerSection(obj,'set_sound', 'none', SoundStruct.none.Waveform(:), value(SoundLoop));


        SoundManagerSection(obj,'send_not_yet_uploaded_sounds');

    case 'update_duration'
        SoundNames = varargin;
        for ind=1:length(SoundNames)
            SoundStruct.(SoundNames{ind}).Duration = value(TargetDuration);
            SoundStruct.(SoundNames{ind}).Waveform = ...
                SoundsSection(obj,'create_waveform',SoundStruct.(SoundNames{ind}));
        end
        SoundsSection(obj,'update_all_sounds');


    case 'update_volumes'
        SoundNames = varargin;
        for ind=1:length(SoundNames)
            SoundStruct.(SoundNames{ind}).Volume = value(TargetVolume);
            SoundStruct.(SoundNames{ind}).Waveform = ...
                SoundsSection(obj,'create_waveform',SoundStruct.(SoundNames{ind}));
        end
        SoundsSection(obj,'update_all_sounds');
        
    case 'update_volume'
        SoundName=varargin{1};
        newVol=varargin{2};
        for ind=1:length(SoundName)
            SoundStruct.(SoundName).Volume = value(newVol);
            SoundStruct.(SoundName).Waveform = ...
                SoundSection(obj,'create_waveform',SoundStruct.(SoundName));
        end
       SoundManagerSection(obj, 'set_sound', SoundName, SoundStruct.(SoundName).Waveform);


        
    case 'update_frequencies'
        SoundNames = varargin;
        for ind=1:length(SoundNames)
            SoundStruct.(SoundNames{ind}).Frequency = value(TargetFrequency);
            SoundStruct.(SoundNames{ind}).Waveform = ...
                SoundSection(obj,'create_waveform',SoundStruct.(SoundNames{ind}));
        end
        SoundSection(obj,'update_all_sounds');
    
    case 'calculate_attenuation'
        SpeakerCalibration = varargin{1};
        SoundFrequency = varargin{2};
        SoundIntensity = varargin{3};
        % -- Find attenuation for this intensity and frequency --
        % Note that the attenuation was measured for peak values. The conversion
        % to RMS values has to be done if necessary (e.g. for noise).
        SoundAttenuation = zeros(size(SoundFrequency));
        for ind=1:length(SoundFrequency)
            StimInterpAtt = interp1(SpeakerCalibration.FrequencyVector,...
                SpeakerCalibration.AttenuationVector,SoundFrequency(ind),'linear');
            if(isnan(StimInterpAtt))
                StimInterpAtt = 0.0032;
                warning(['Sound parameters (%0.1f Hz, %0.1f dB-SPL) out of range!\n',...
                    'Set to default intensity(%0.4f).'],...
                    SoundFrequency(ind),SoundIntensity,StimInterpAtt);
            end
            DiffSPL = SoundIntensity-SpeakerCalibration.TargetSPL;
            AttFactor = sqrt(10^(DiffSPL/10));
            SoundAttenuation(ind) = StimInterpAtt * AttFactor;
        end
        xpos = SoundAttenuation;
    
    case 'update_balances'

        %JPL - not working yet

        %         SoundNames = varargin;
        %         for ind=1:length(SoundNames)
        %             SoundStruct.(SoundNames{ind}).Volume = value(TargetVolume);
        %             SoundStruct.(SoundNames{ind}).Waveform = ...
        %                 SoundsSection(obj,'create_waveform',SoundStruct.(SoundNames{ind}));
        %         end
        %         SoundsSection(obj,'update_all_sounds');


    case 'close'
        %Delete all soloparamhandles that belong to this object and whose

        if exist('myfig', 'var') && isa(myfig, 'SoloParamHandle') && ishhandle(value(myfig)),
            delete(value(myfig));
        end
        delete_sphandle('owner',['^@' class(obj) '$'],'fullname',['^' mfilename '_']);

    case 'reinit',       % ---------- CASE REINIT -------------
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


