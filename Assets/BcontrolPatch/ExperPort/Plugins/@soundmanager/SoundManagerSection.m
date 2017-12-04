% [] = SoundManagerSection(obj, action, [arg1], [arg2], [arg3])
%
% This plugin helps to manage sounds sent to the SoundServer.
% (@RTLSoundMachine; or, in a virtual rig, @softsound). The plugin stores
% soundwaves (identifying them by name, so they are easy to id), sends them
% to the SoundServer, and keeps track of which sounds have been sent and
% which haven't, so they aren't sent again if that is unnecessary.
% 
% The plugin acts as a clean wrapper to the SoundServer; it is easier to
% use than the native SoundServer commands, and if you use it, you need 
% never know about the native commands.
%
% This plugin has no GUI elements. This plugin requires Dispatcher.
%
% 
%
% PARAMETERS:
% -----------
%
% obj      Default object argument.
%
% action   One of:
%
%    'init'    Initializes the plugin. Sets up internal variables
%              and initalizes the RT Linux SoundServer.
%
%    'initialize_machine'   Delete all existing sounds from the RT Linux SoundServer
%              and from the plugin; reinitialize the RT Linux SoundServer. 
%
%    'get_sample_rate'  Returns the sample rate used by the RT Linux
%              SoundServer. This information is crucial when you are going
%              to synthesize the sound waveforms that will be sent to the
%              RTL SoundServer.
%
%    'declare_new_sound'  name   [waveform]  [loop_fg=0]
%              This action defines a new name that can be used to identify
%              sounds. This action requires at least one further argument,
%              name, which should be a string. The next argument is
%              optional; this argument, waveform, if provided, should be a
%              numeric matrix that defines the sound waveform associated
%              with the name. waveform can be a vector, in which case the
%              sound will be mono (sound will be played on both speakers).
%              If waveform has either two columns or two rows, then it is
%              interpreted as two vectors, one for the Left speaker, and
%              one for the Right speaker. The first row (or column) is for
%              the Left speaker; the other for the Right. If the waveform
%              is not provided, then action='set_sound' (see below) must be
%              called before the newly declared sound can be used. The last
%              argument is also optional; if loop_fg is non-zero, then the
%              sound will loop until explicitly turned off. If loop_fg is
%              zero (the default) then the sound stops after being played
%              once. NOTE: LOOP_FG NON-ZERO IS ACCEPTED, BUT
%              NON-FUNCTIONAL, IN THE @SOFTSMMARKII EMULATOR
%
%    'set_sound'  name  waveform [loop_fg=0]
%              Set the waveform of a previously declared sound. This action
%              requires two additional arguments: name, the string that is
%              used to dentify the sound; and waveform, which should be a
%              numeric matrix that defines the sound waveform associated
%              with that name. waveform can be a vector, in which case the
%              sound will be mono (sound will be played on both speakers).
%              If waveform has either two columns or two rows, then it is
%              interpreted as two vectors, one for the Left speaker, and
%              one for the Right speaker. The first row (or column) is for
%              the Left speaker; the other for the Right. The last
%              argument is optional; if loop_fg is non-zero, then the
%              sound will loop until explicitly turned off. If loop_fg is
%              zero (the default) then the sound stops after being played
%              once. NOTE: LOOP_FG NON-ZERO IS ACCEPTED, BUT
%              NON-FUNCTIONAL, IN THE @SOFTSMMARKII EMULATOR
%
%    'send_not_yet_uploaded_sounds'      Any sound that has been newly
%              declared, or for which the waveform has been set using
%              'set_sound' since the last call to
%              'send_not_yet_uploaded_sounds', will be uploaded to the RTL
%              SoundServer. Sounds that were already uploaded and didn't
%              have their waveform set since they were uploaded will not be
%              uploaded again, to save time.
%
%    'get_sound_id' name
%              The RTLSM triggers sounds in the SoundServer using integer
%              ids, not sound names. This action returns the sound id
%              associated with a particular name. (You will need this
%              information, for example, when using the
%              @StateMachineAssembler to define a state that triggers a
%              sound). If no sound with this name has been declared, an
%              error will occur.
%
%    'get_sound_duration'  name
%              Returns, in seconds, the duration of the indicated sound.
%              name should be a string. If no sound with this name has been
%              declared, an error will occur.
%
%    'get_sound'  name
%			   Returns the sound wave of the specified sound.
%
%    'sound_exists' name
%              Returns either 1 or 0: a 1 if a sound with the indicated
%              name has been declared (see 'declare_new_sound' above), 0 if
%              it hasn't.
%
%    'delete_sound' name
%              If the sound exists, deletes it from the current table. If
%              the sound doesn't exist, does nothing.
%
%    'play_sound' name
%              If the sound with this name hasn't been uploaded yet, upload
%              it to the SoundServer; after that, tell the SoundServer to
%              play it asap. No real-time guarantees here.
%
%    'stop_sound' name
%              If the sound with this name hasn't been uploaded yet, upload
%              it to the SoundServer; after that, tell the SoundServer to
%              stop it asap. No real-time guarantees here.  This was added
%              so that users could play and stop looped sounds for testing.
%    'loop_sound' name, loop_flag
%              This action allows users to turn looping on and off without
%              uploading the entire sound again.
%
%    'get_sound_machine'   Returns the sound machine object, which will
%              either be an @RTLSoundMachine or an @softsound, depending on
%              whether you are on a physical rig (first case) or a virtual
%              rig (latter case). This action is provided for completeness,
%              but if you are using this plugin, there is nor eason you
%              should ever need direct access to the SoundServer.
%
%    'reinit'  Delete all of this plugin's data, and reinit from scratch.
%

% Written by Carlos Brody 2007


function [out] = SoundManagerSection(obj, action, arg1, arg2, arg3)
   
   GetSoloFunctionArgs(obj);

   if ~exist('the_sounds', 'var') && ~strcmp(action, 'init'),    
     % Asking to do something with SoundManagerSection without having run 'init'; 
     % we'll run 'init' for you...
     SoundManagerSection(obj, 'init');
     GetSoloFunctionArgs(obj);
   end;

   if exist('the_sounds', 'var'),
     uploadCol = findCol(the_sounds, 'uploaded');  %#ok<NODEF>
     idCol     = findCol(the_sounds, 'id'); 
     valueCol  = findCol(the_sounds, 'value');
     nameCol   = findCol(the_sounds, 'soundname');
     loopCol   = findCol(the_sounds, 'loop_fg');
     emptyCol  = findCol(the_sounds, 'empty_fg');
     
     nsounds   = size(value(the_sounds),1) - 1;
   end;
   
   
   
   switch action
     case 'init',   % ---------- CASE INIT -------------

       % First delete all previous (now obsolete) instances of the SoundManager:
       delete_sphandle('owner', ['^@' class(obj) '$'], ...
         'fullname', ['^' mfilename]);


       % Old call to initialise sound system:
       SoloParamHandle(obj, 'sound_machine', 'value', dispatcher('get_sound_machine'), 'saveable', 0);
       Initialize(value(sound_machine)); % Direct initialize to clear all sounds, make room for new
       SoloParamHandle(obj, 'the_sounds', 'saveable', 0, 'value', ...
         {'soundname', 'id', 'uploaded', 'value', 'loop_fg', 'empty_fg'});
       
       
     case 'initialize_machine', % ---------- CASE INITIALIZE_MACHINE -------------
       Initialize(value(sound_machine));
       the_sounds.value = {'soundname', 'id', 'uploaded', 'value', 'loop_fg'};
       
     case 'initialize_machine_resend_sounds',
       Initialize(value(sound_machine));
       for i=2:rows(the_sounds(:,:)), 
           the_sounds{i,uploadCol} = 0; %#ok<AGROW>
       end;
       feval(mfilename, obj, 'send_not_yet_uploaded_sounds');
       
       
     case 'send_not_yet_uploaded_sounds',  % -------- CASE SEND_NOT_YET_UPLOADED_SOUNDS -------       
       for i=2:rows(the_sounds(:,:)),
         if the_sounds{i, uploadCol} == 0,
%            if min(size(the_sounds{i, valueCol}))==1,
%              LoadSound(value(sound_machine), the_sounds{i, idCol}, the_sounds{i, valueCol}, 'both', ...
%                0, 0, the_sounds{i, loopCol});
%            else
            if the_sounds{i, emptyCol} == 1,
                LoadSound(value(sound_machine), the_sounds{i, idCol}, [0 0]', 'both', ...
                 0, 0, the_sounds{i, loopCol});
            else
               LoadSound(value(sound_machine), the_sounds{i, idCol}, the_sounds{i, valueCol}, 'both', ...
                 0, 0, the_sounds{i, loopCol});
            end;
           the_sounds{i, uploadCol} = 1; %#ok<AGROW>
         end;
       end;
       
       cleanEmulatorSounds;
       
       
     case 'set_sound',    % ---------- CASE SET_SOUND --------
       name = arg1; val = arg2; if nargin>=5, lflag = arg3; else lflag = 0; end;
       
       rownum = find(strcmp(the_sounds(2:nsounds+1,nameCol), name));
       if isempty(rownum)
         error('No sound with name %s declared yet', name);
       end;
       rownum = rownum+1;
       if size(val, 1) > 2, val = val'; end;
       if isempty(val), the_sounds{rownum, emptyCol} = 1;
       else             the_sounds{rownum, emptyCol} = 0;
       end;
       the_sounds{rownum, valueCol}  = val;
       the_sounds{rownum, uploadCol} = 0;
       the_sounds{rownum, loopCol}   = lflag; %#ok<NASGU>
       
       
       case 'loop_sound',
       name = arg1; lflag = arg2; 
       
       rownum = find(strcmp(the_sounds(2:nsounds+1,nameCol), name));
       if isempty(rownum)
         error('No sound with name %s declared yet', name);
       end;
       rownum = rownum+1;
       the_sounds{rownum, uploadCol} = 0;
       the_sounds{rownum, loopCol}   = lflag; %#ok<NASGU>
           
       
       
     case 'declare_new_sound',  % ------ DECLARE_NEW_SOUND ------
       name = arg1;

       other = find(strcmp(the_sounds(2:nsounds+1,1), name), 1, 'first');
       if ~isempty(other), warning(['SoundManagerSection : The sound named "%s" was previously declared.\n' ...
           'Unreliable behavior is possible! Clear the SoundManager completely with ''init''\n' ...
           'before calling ''declare_sound'' with a previously used soundname.\n'], name); 
       end;

       new_id = max(cell2mat(the_sounds(2:nsounds+1,idCol))) + 1;
       if isempty(new_id), new_id = 1; end;  % No sounds existed before.
       sz = size(value(the_sounds));
       newrow = sz(1)+1;
       
       the_sounds.value = [value(the_sounds) ; cell(1, sz(2))];
       
       the_sounds{newrow, nameCol}    = name;
       the_sounds{newrow, idCol}      = new_id;
       the_sounds{newrow, uploadCol}  = 0;
       the_sounds{newrow, loopCol}    = 0;
       the_sounds{newrow, emptyCol}   = 1;
       
       if nargin >= 4, val = arg2;
         if size(val, 1) > 2, val = val'; end;
         if isempty(val), the_sounds{newrow, emptyCol} = 1;
         else             the_sounds{newrow, emptyCol} = 0;
         end;
         the_sounds{newrow, valueCol}  = val;
       end;

       if nargin >=5,
         the_sounds{newrow, loopCol}  = arg3; %#ok<NASGU>
       end;

       
     case 'delete_sound',    % ---------- CASE DELETE_SOUND --------
       if ~SoundManagerSection(obj, 'sound_exists', arg1), return; end;
       rownum = find(strcmp(the_sounds(2:nsounds+1,nameCol), arg1));
       % "end" still doesn't work in following context, substituting by "size(the_sounds(:,:),1)"
       the_sounds.value = [the_sounds(1:rownum,:) ; the_sounds(rownum+2:size(the_sounds(:,:),1),:)];
       
       
     case 'sound_exists',   % ------- CASE SOUND_EXISTS -------
       rownum = find(strcmp(the_sounds(2:nsounds+1,nameCol), arg1), 1);
       out = ~isempty(rownum);
       
       
     case 'get_sample_rate',  % -----  CASE GET_SAMPLE_RATE -------
       out = GetSampleRate(value(sound_machine));
       
       
     case 'get_sound_id',   %  -------- CASE GET_SOUND_ID -------------------
       name = arg1;
    
       if strcmp(name,'all')
         out=1:nsounds;
       else
       rownum = find(strcmp(the_sounds(2:nsounds+1,1), name));
       if isempty(rownum),
         error('No sound with name %s declared yet', name);
       else
         out = the_sounds{rownum+1, idCol};
       end;
       end


     case 'get_sound_machine',   %  -------- CASE GET_SOUND_MACHINE -------------------
       out = dispatcher('get_sound_machine');
       

     case 'play_sound',   %  -------- CASE PLAY_SOUND ------------------- 
       name = arg1;
       rownum = find(strcmp(the_sounds(2:nsounds+1,nameCol), name));
       if isempty(rownum)
         error('No sound with name %s declared yet', name);
       end;
       i = rownum+1;
       if the_sounds{i, uploadCol} == 0, % If not yet uploaded, upload it:
%            if min(size(the_sounds{i, valueCol}))==1,
%              LoadSound(value(sound_machine), the_sounds{i, idCol}, the_sounds{i, valueCol}, 'both', ...
%                0, 0, the_sounds{i, loopCol});
%            else
            if the_sounds{i, emptyCol} == 1,
                LoadSound(value(sound_machine), the_sounds{i, idCol}, [0 0]', 'both', ...
                 0, 0, the_sounds{i, loopCol});
            else
                LoadSound(value(sound_machine), the_sounds{i, idCol}, the_sounds{i, valueCol}, 'both', ...
                    0, 0, the_sounds{i, loopCol});
            end;
%            end;
           the_sounds{i, uploadCol} = 1;
       end;
       
       sndm = dispatcher('get_sound_machine');
       %<~>TODO: match playsound and Playsound. All sound machines should
       %       have identical interfaces where plugins are concerned, and
       %       we should not need to know with which machine we're dealing.
       pause(0.01);
       cleanEmulatorSounds;
       if     isa(sndm, 'softsound'),       playsound(sndm, the_sounds{i, idCol});
       elseif isa(sndm, 'RTLSoundMachine'), PlaySound(sndm, the_sounds{i, idCol});
       elseif isa(sndm, 'bpodSound'),       playsound(sndm, the_sounds{i, idCol});
       else
         error('Don''t know how to deal with SoundServers of class "@%s"', class(sndm));
       end;
       
    case 'stop_sound',   %  -------- CASE STOP_SOUND ------------------- 
       name = arg1;
       rownum = find(strcmp(the_sounds(2:nsounds+1,nameCol), name));
       if isempty(rownum)
         error('No sound with name %s declared yet', name);
       end;
       i = rownum+1;
       if the_sounds{i, uploadCol} == 0, % If not yet uploaded, upload it:
%            if min(size(the_sounds{i, valueCol}))==1,
%              LoadSound(value(sound_machine), the_sounds{i, idCol}, the_sounds{i, valueCol}, 'both', ...
%                0, 0, the_sounds{i, loopCol});
%            else
            if the_sounds{i, emptyCol} == 1,
                LoadSound(value(sound_machine), the_sounds{i, idCol}, [0 0]', 'both', ...
                 0, 0, the_sounds{i, loopCol});
            else
                LoadSound(value(sound_machine), the_sounds{i, idCol}, the_sounds{i, valueCol}, 'both', ...
                    0, 0, the_sounds{i, loopCol});
            end;
%            end;
           the_sounds{i, uploadCol} = 1;
       end;
       sndm = dispatcher('get_sound_machine');
       if     isa(sndm, 'softsound'),       playsound(sndm, -1*the_sounds{i, idCol});
       elseif isa(sndm, 'RTLSoundMachine'), PlaySound(sndm, -1*the_sounds{i, idCol});
       elseif isa(sndm, 'bpodSound'),       playsound(sndm, -1*the_sounds{i, idCol});
       else
         error('Don''t know how to deal with SoundServers of class "@%s"', class(sndm));
       end;
       
       
     case 'get_sound_duration',   % ------- CASE GET_SOUND_DURATION ---------
       name = arg1;
       rownum = find(strcmp(the_sounds(2:nsounds+1,1), name));
       if isempty(rownum),
         error('No sound with name %s declared yet', name);
       else
         out = max(size(the_sounds{rownum+1, valueCol}))/GetSampleRate(value(sound_machine));
       end;
       
      case 'get_sound',   %  -------- CASE GET_SOUND -------------------
       name = arg1;
       rownum = find(strcmp(the_sounds(2:nsounds+1,1), name));
       if isempty(rownum),
         error('No sound with name %s declared yet', name);
       else
         out = the_sounds{rownum+1, valueCol};
       end;  
       
       
       
    case 'reinit',       % ---------- CASE REINIT -------------
      % Delete all SoloParamHandles who belong to this object and whose
      % fullname starts with the name of this mfile:
      delete_sphandle('owner', ['^@' class(obj) '$'], ...
                      'fullname', ['^' mfilename]);

      feval(mfilename, obj, 'init');
   end;
   
   return;
   
   
% ----------------------------
   
function [num] = findCol(db, name)

num = find(strcmp(db(1,:), name));



      