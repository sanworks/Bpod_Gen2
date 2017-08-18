function outSMA=BCtoBpod(inMatrix, inSMA)

%%% main method handles translation of the SMA

%pretty rough at the moment, needs some work

global BpodSystem

%%
%%%---NOTES
% - BControl SMA looks like this:
%row initialized to the max current number, +1
%rows 1 - n: names of states to transition TO on events 1-n being triggered
%row n+1:    name of Tup trans
%row n+2:    Tup time
%row n+3:    Event channel ID (+/-)
%row n+4:    SoundId
%row n+5:    SchedWaveId

%%%%%%Here are the default In events and ids defined in 'BPodSystem' object
%NOTE, we will need to assign our Bcontrol input lines to these
%
%
% 1.  'Port1In'     17. 'BNC1High     21. 'Wire1High'     29. 'SoftCode1'     39. 'Unused'
% 2.  'Port1Out'    18. 'BNC1Low'     22. 'Wire1Low'      30. 'SoftCode2'     40. 'Tup'
% 3.  'Port2In'     19. 'BNC2High'    23. 'Wire2High'     31. 'SoftCode3'
% 4.  'Port2Out'    20. 'BNC2Low'     24. 'Wire2Low''     32. 'SoftCode4'
% 5.  'Port3In'                       25. 'Wire3High'     33. 'SoftCode5'
% 6.  'Port3Out'                      26. 'Wire3Low'      34. 'SoftCode6'
% 7.  'Port4In'                       27. 'Wire4High'     35. 'SoftCode7'
% 8.  'Port4Out'                      28. 'Wire4Low'      36. 'SoftCode8'
% 9.  'Port5In'                                           37. 'SoftCode9'
% 10. 'Port5Out'                                          38. 'SoftCode10'
% 11. 'Port6In'
% 12. 'Port6Out'
% 13. 'Port7In'
% 14. 'Port7Out'
% 15. 'Port8In'
% 16. 'Port8Out'

%and here are the ouputs:

% 1.  'ValveState'
% 2.  'BNCState'
% 3.  'WireState'
% 4.  'Serial1Code'
% 5.  'Serial2Code'
% 6.  'SoftCode'
% 7.  'GlobalTimerTrig'
% 8.  'GlobalTimerCancel'
% 9.  'GlobalCounterReset'
% 10. 'PWM1'
% 11. 'PWM2'
% 12. 'PWM3'
% 13. 'PWM4'
% 14. 'PWM5'
% 15. 'PWM6'
% 16. 'PWM7'
% 17. 'PWM8'

%there are also 'MetaActions' as ouputs:

%MetaActions = {'Valve', 'LED', 'LEDState'}; % Valve is an alternate syntax
% for "ValveState", specifying one valve to open (1-8)
% LED is an alternate syntax for PWM1-8,specifying one LED to set to max
% brightness (1-8)
% LEDState is an alternate syntax for PWM1-8. A byte coding for binary sets
% which LEDs are at max brightness


%%
%%%---SETUP

%---input sma matrix
% in the setup to bcontrol runs, matrices are sent that have multiple
% occurences of states. Here we delete any duplicate state rows for bpod
% compatability

% bcontrol setup crap
nInputs=size(inSMA.input_map,1);
nTimers=size(inSMA.self_timer_map,1);
nOutputs=size(inSMA.output_map,1);

%% change the SMA fields that following the number of state trans as well
origSMA=inSMA;
%inSMA.states          = inSMA.states(rowIds,:);
%inSMA.happList        = inSMA.happList(rowIds);
%inSMA.default_actions = inSMA.default_actions(rowIds);


%loop through entries of the bcontrol stm, and replace any non-numeric
%entries with their proper numeric counterpoart
numericInputStates     = inSMA.states(:,1:size(inSMA.input_map(:,1),1)+1); %plus one includes the tup timer values
numericOutputStates    = inSMA.states(:,size(inSMA.input_map(:,1),1)+2:end);
%% INPUT MATRIX

numericInputStates=numericInputStates'; %make sure we loop through rows

%first replace all strings are are present on the input list with numbers
for b=1:1:numel(inSMA.input_map(:,1))
    idxs=strcmp(numericInputStates,inSMA.input_map(b,1));
    numericInputStates(idxs)=inSMA.input_map(b,2);
end


%replace any non-string states that have a name, with the name string
%so we dont have to worry about mixed nuermical and non-numerical states
numericIdx=cellfun(@(x) ~isnumeric(x),numericInputStates);
nonStringIdxs=ismember(unique(numericInputStates(numericIdx)),inSMA.state_name_list(:,1));
nonStringNames=inSMA.state_name_list(nonStringIdxs,1);
for b=1:1:numel(nonStringNames)
    stateNum=inSMA.state_name_list{strcmp(nonStringNames(b),inSMA.state_name_list(:,1)),2};
    tmpidx=find(cellfun(@(x) isnumeric(x) && x==stateNum, numericInputStates));
    if ~isempty(tmpidx) %prep state 'state_0' isnt in the sma
        numericInputStates(tmpidx) = repmat(nonStringNames(b),numel(tmpidx),1);
        numericIdx=cellfun(@(x) ~isnumeric(x),numericInputStates);
    end
end

%any remaining non-numerics are state names
idxs=find(cellfun(@(x) ~isnumeric(x), numericInputStates));
[~,a,~]=unique(idxs);
finalIdxs=idxs(a);
[cols,rows] = ind2sub(size(numericInputStates),finalIdxs);

statecounter=1;%counts states that are named
newStateNameList={};
for k=1:1:size(numericInputStates,2) %loop through rows
    %most frequent numeric in row is the current state
    row=k;
    third=0; %third row of inSMA.state_name_list, not sure what it is

    %bit of a kludge here, but to determine the state in the current row,
    %look at the ORIGINAL sma, which will still have numbers, and use moden
    curr_state =  mode(cell2mat(inSMA.states(row,cellfun(@(x) isnumeric(x),inSMA.states(row,1:end-1)))));
    state_name=['state_' num2str(curr_state)];

    %if curr_state==153 
    %    keyboard
    %end
    
    %idxs of non-numerics in the matrix
    nNonNumericInRow=sum(rows==row);
    theseIdxs=finalIdxs(rows==row);

    if isempty(newStateNameList)
        newStateNameList(statecounter,:)={state_name curr_state third};
        statecounter=statecounter+1;
   %if this state number isnt already on the new state name list...
    elseif ~any(curr_state==cell2mat(newStateNameList(:,2)))
        %and if its number is on the original list
        if any(curr_state==cell2mat(inSMA.state_name_list(:,2)))
            %check if this name for this state num is on the list of
            %states we are about to alter
            tmpname=inSMA.state_name_list{curr_state==cell2mat(inSMA.state_name_list(:,2)),1};
            if ~any(strcmp(tmpname,numericInputStates(theseIdxs)))
                %if so, add
                newStateNameList(statecounter,:)={tmpname curr_state third};
                statecounter=statecounter+1;
            %elseif isempty(tmpname)
            %    newStateNameList(statecounter,:)={state_name curr_state third};
            %    statecounter=statecounter+1;
            end
        %number is not on the orignal list, so add a made up name    
        else    
            newStateNameList(statecounter,:)={state_name curr_state third};
            statecounter=statecounter+1;
        end
    end
    
    %deal with non-numerics in this row
    for j=1:1:nNonNumericInRow
        %reset curr_state 
        curr_state =  mode(cell2mat(inSMA.states(row,cellfun(@(x) isnumeric(x),inSMA.states(row,1:end-1)))));

        state_name=[];
        third=0; %third row of inSMA.state_name_list, not sure what it is
        strval=numericInputStates{theseIdxs(j)};

        %handle special cases first
        if strcmp(strval,'check_next_trial_ready')
            state_name='check_next_trial_ready';
            numericInputStates(theseIdxs(j)) = {35};
            curr_state=35;
        elseif strcmp(strval,'state_0')
            state_name='state_0';
            numericInputStates(theseIdxs(j)) = {0};
            curr_state=0;
        elseif ~isempty(strfind(strval,'current_state'))
            statechange=str2num(strval(13+strfind(strval,'current_state'):end));
            if isempty(statechange)
                numericInputStates(theseIdxs(j))={curr_state};
            else
                numericInputStates(theseIdxs(j))={curr_state+statechange};
                curr_state=curr_state+statechange;
            end
            state_name=['state_' num2str(curr_state)];
  
        elseif any(strcmp(strval,inSMA.state_name_list(:,1)))
            %is it on the state list (name
            curr_state=inSMA.state_name_list{strcmp(strval,inSMA.state_name_list(:,1)),2};
            numericInputStates(theseIdxs(j))=inSMA.state_name_list(strcmp(strval,inSMA.state_name_list(:,1)),2);
            state_name=inSMA.state_name_list{strcmp(strval,inSMA.state_name_list(:,1)),1};
            third=inSMA.state_name_list{strcmp(strval,inSMA.state_name_list(:,1)),3};
        else
            %likely a soft state
            %check fully assemebled state matrix to see at correspinding row
            %and col to see how this was assembled by Bcontrol;
            numericInputStates(theseIdxs(j)) = {inMatrix(row,cols(finalIdxs==theseIdxs(j)))};
            state_name=['state_' num2str(numericInputStates{theseIdxs(j)})];
            curr_state=numericInputStates{theseIdxs(j)};
            
        end
        
        if any(curr_state==cell2mat(inSMA.state_name_list(:,2)))
            state_name=inSMA.state_name_list{curr_state==cell2mat(inSMA.state_name_list(:,2)),1};
            third=inSMA.state_name_list{curr_state==cell2mat(inSMA.state_name_list(:,2)),3};
            curr_state=inSMA.state_name_list{curr_state==cell2mat(inSMA.state_name_list(:,2)),2};
        end
        

    
        %add to state name list
        if isempty(newStateNameList)
            newStateNameList(statecounter,:)={state_name curr_state third};
            statecounter=statecounter+1;curr
        elseif ~any(strcmp(newStateNameList(:,1),state_name))
            newStateNameList(statecounter,:)={state_name curr_state third};
            statecounter=statecounter+1;
        end
        
    end
        
end

numericInputStates=numericInputStates';

%INPUT MATRIX CLEANUP
%delete rows that are all state_35 rows ('setup' rows)

for b=1:1:size(numericInputStates,1)
    %if diff is 0 for all, its bad
    if any(cell2mat(numericInputStates(b,1:end-1))-35)
        idx35s(b)=0;
    else
        %flag this row for deletion
        idx35s(b)=1;
    end
end


numericInputStates(find(idx35s),:)=[];
numericOutputStates(find(idx35s),:)=[];

%check that all staterows have at least one transition
for b=1:1:size(numericInputStates,1)
    if any(diff(cell2mat(numericInputStates(b,1:end-1)))) %any different numbered states?
        noTransition(b)  = 0;
    else %if not, then no transition
        noTransition(b)  =  1;
    end
end

numericInputStates(find(noTransition),:)=[];
numericOutputStates(find(noTransition),:)=[];

%make sure any tranisitions to state 35 actually go to nan, for bpod exit
numericInputStates(cell2mat(numericInputStates)==35)={nan};

%finall, remove the state35/check_trial state from the statename
%list
newStateNameList(strcmp(newStateNameList(:,1),'check_next_trial_ready'),:)=[];

%if there is nothing left in the matrix, this is a bcontrol setup matrix
if isempty(cell2mat(numericInputStates))
    outSMA = NewStateMachine();
    outSMA = AddState(outSMA, ...
        'Name', 'vapid', ...
        'Timer', .001,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {});
    return;
end


%%
nrows=size(numericInputStates,1);

%---output bpod matrix
outSMA = NewStateMachine();

outSMA.StateNames = newStateNameList(:,1);
outSMA.Manifest(1:numel(outSMA.StateNames)) = outSMA.StateNames;
outSMA.nStatesInManifest = sum(cellfun(@(x) ~isempty(x), outSMA.Manifest));
outSMA.StatesDefined = ones(numel(outSMA.StateNames),1);
outSMA.nStates=0;

%make sure outSMA fields have the right dimensionality
%is this necessary??
outSMA.InputMatrix = repmat(mode(cell2mat(numericInputStates),2),1,outSMA.meta.InputMatrixSize);
outSMA.OutputMatrix = zeros(nrows,BpodSystem.StateMachineInfo.nOutputChannels);
outSMA.GlobalTimerStartMatrix = ones(nrows,BpodSystem.HW.n.GlobalTimers);
outSMA.GlobalTimerEndMatrix = ones(nrows,BpodSystem.HW.n.GlobalTimers);
outSMA.GlobalCounterMatrix = ones(nrows,BpodSystem.HW.n.GlobalCounters);
outSMA.ConditionMatrix = ones(nrows,BpodSystem.HW.n.Conditions);
%JPL - these want to be backwards when sending...why?
%outSMA.StateTimerMatrix = ones(nrows,1);
%outSMA.StateTimers = ones(nrows,1);
outSMA.StateTimerMatrix = ones(1,nrows);
outSMA.StateTimers = ones(1,nrows);

colCount=1;
%%
%--INPUT MATRIX EVENT REPLACEMENT

%replace numerical event values with the remapped values for bpod

%check for input_line_map...some Brody .conf files didnt have this
%specified, so it didnt get put into the translation object.
if ~isfield(inSMA,'input_line_map');
    inSMA.input_line_map = inSMA.input_map;
    %lazy
    for g=1:1:numel(inSMA.input_map(:,2))
        inSMA.input_line_map(g,2)={nan};
    end
end

soloRemapInput=BpodSystem.ProtocolTranslation.soloRemapInput;

for i=1:1:nInputs
    
    [chanName, chanCol] = inSMA.input_map{i,:};
    
    %dont bother with tup or scheduled wave-assocated i/o here
    %notes: swaves automatically have _In and _Out events assocaited with tme
    if ~strcmp(chanName,'Tup') && ~any(cellfun(@(x) ~isempty(strfind(chanName,x)),{inSMA.sched_waves.name}))
        
        %was the solo event rising or falling edge?
        input_line=inSMA.input_line_map{find(strcmp(chanName,...
            inSMA.input_line_map(:,1))),2};
        
        rising=[];
        if ~isnan(input_line)
            %use input_line_map
            if input_line > 0 %rising edge
                rising=1;
            else              %falling edge
                rising=0;
            end
        else
            %try and infer from name
            %maybe issue a warning
            if ~isempty(strfind(chanName,'in'))
                rising=1;
            elseif ~isempty(strfind(chanName,'out'))
                rising=0;
            else
                %warning, assume rising
                rising=1;
            end
        end
        
        %%%get corresponding bpod data
        remapIdx=find(cellfun(@(x) strcmp(chanName,x.SoloName),...
            soloRemapInput));
        
        %if not found on the remap index, this is (likely) because this
        %input was added in StateMatrixSetion and not specified in the
        %settgings file for the rig
        
        Module=soloRemapInput{remapIdx}.Module; %bpod module name
        if isempty(Module)
            Module='Bpod';
        end
        
        Chan=soloRemapInput{remapIdx}.Chan;   %chan name
        Pin=soloRemapInput{remapIdx}.Pin;     %pin name
        
        %find events associated with this channel
        idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,Chan)),...
            BpodSystem.StateMachineInfo.EventNames,'UniformOutput',false)));
        
        candidateEvents=BpodSystem.StateMachineInfo.EventNames(idx);
        
        %depending on bpod channel type, can have different types of events
        if ~isempty(strfind(Chan,'BNC'))           %BNC types
            if rising
                %high condition
                idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,'High')),...
                    candidateEvents,'UniformOutput',false)));
            else
                %low conditiond
                idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,'Low')),...
                    candidateEvents,'UniformOutput',false)));
            end
            Event(colCount).name=candidateEvents(idx);
            Event(colCount).idx=find(strcmp(BpodSystem.StateMachineInfo.EventNames,...
                Event(colCount).name));
            
        elseif ~isempty(strfind(Chan,'Serial'))    %Serial types
            
            if ~isempty(strfind(Chan,'Jump'))      %Serial#Jump event
                
            else                                    %Serial#_# event
                
            end
            
        elseif ~isempty(strfind(Chan,'SoftCode'))  %SoftCode types
            
        elseif ~isempty(strfind(Chan,'SoftJump'))  %SoftJump types
            
        elseif ~isempty(strfind(Chan,'Wire'))      %Wire types
            if rising
                %high condition
                idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,'High')),...
                    candidateEvents,'UniformOutput',false)));
            else
                %low conditiond
                idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,'Low')),...
                    candidateEvents,'UniformOutput',false)));
            end
            Event(colCount).name=candidateEvents(idx);
            Event(colCount).idx=find(strcmp(BpodSystem.StateMachineInfo.EventNames,...
                Event(colCount).name));
            
        elseif ~isempty(strfind(Chan,'Port'))      %Port types
            if rising
                %high condition
                idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,'In')),...
                    candidateEvents,'UniformOutput',false)));
            else
                %low conditiond
                idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,'Out')),...
                    candidateEvents,'UniformOutput',false)));
            end
            Event(colCount).name=candidateEvents(idx);
            Event(colCount).idx=find(strcmp(BpodSystem.StateMachineInfo.EventNames,...
                Event(colCount).name));
            
        elseif ~isempty(strfind(Chan,'Condition')) %Condition types
            %nothing to be done
        else
            warning('translateProtocol:: do not recognize the this event type')
        end
        
        outSMA.InputMatrix(:,Event(colCount).idx)=cell2mat(numericInputStates(:,chanCol));
        colCount=colCount+1;
    end
end

%%
% -- Timer Matrix
[tupCols]=cell2mat(inSMA.self_timer_map(:,2)); %column for timer VALUES.

outSMA.StateTimerMatrix = cell2mat(numericInputStates(:,inSMA.input_map{find(strcmp('Tup',inSMA.input_map(:,1))),2}))';
outSMA.StateTimers = cell2mat(numericInputStates(:,tupCols))';


%%
%--OUTPUT MATRIX
soloRemapOutput=BpodSystem.ProtocolTranslation.soloRemapOutput;

for i=1:1:nOutputs
    
    %%%get solo input assoc. with this column
    [chanName, chanCol] = inSMA.output_map{i,:};
    
    %%%get corresponding bpod data
    remapIdx=find(cellfun(@(x) strcmp(chanName,x.SoloName),...
        soloRemapOutput));
    
    if ~isempty(remapIdx)
        
        Module=soloRemapOutput{remapIdx}.Module;     %bpod module name
        SoloType=soloRemapOutput{remapIdx}.SoloType; %type of solo output
        %(Dout is really the only option.
        %schewdwaves and sounds handled elsewhere)
        Chan=soloRemapOutput{remapIdx}.Chan;         %chan name
        Pin=soloRemapOutput{remapIdx}.Pin;           %pin name
        
        %depending on bpod channel type, can have different types of events
        if ~isempty(strfind(Chan,'BNC'))           %BNC types
            if rising
                %high condition
                idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,'High')),...
                    candidateEvents,'UniformOutput',false)));
            else
                %low conditiond
                idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,'Low')),...
                    candidateEvents,'UniformOutput',false)));
            end
            Event.name=candidateEvents(idx);
            Event.idx=find(strcmp(BpodSystem.StateMachineInfo.EventNames,...
                Event.name));
            
        elseif ~isempty(strfind(Chan,'Serial'))    %Serial types
            
            if ~isempty(strfind(Chan,'Jump'))      %Serial#Jump event
                
            else                                    %Serial#_# event
                
            end
            
        elseif ~isempty(strfind(Chan,'SoftCode'))  %SoftCode types
            
        elseif ~isempty(strfind(Chan,'SoftJump'))  %SoftJump types
            
        elseif ~isempty(strfind(Chan,'Wire'))      %Wire types
            if rising
                %high condition
                idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,'High')),...
                    candidateEvents,'UniformOutput',false)));
            else
                %low conditiond
                idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,'Low')),...
                    candidateEvents,'UniformOutput',false)));
            end
            Event.name=candidateEvents(idx);
            Event.idx=find(strcmp(BpodSystem.StateMachineInfo.EventNames,...
                Event.name));
            
        elseif ~isempty(strfind(Chan,'Port'))      %Port types
            if rising
                %high condition
                idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,'In')),...
                    candidateEvents,'UniformOutput',false)));
            else
                %low conditiond
                idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,'Out')),...
                    candidateEvents,'UniformOutput',false)));
            end
            Event.name=candidateEvents(idx);
            Event.idx=find(strcmp(BpodSystem.StateMachineInfo.EventNames,...
                Event.name));
            
        elseif ~isempty(strfind(Chan,'Condition')) %Condition types
            %nothing to be done
        else
            warning('translateProtocol:: dont recognize this event type')
        end
        
        %place this event into the proper row and column of the outSMA
        outSMA.OutputMatrix(:,Event.idx(i))=cell2mat(numericOutputStates(:,chanCol));
        
    else
        
        %cant find the mapping between the solo output and the bpod
        %output...this might be ok, depending on where we are calling from
        %(eg. dispatcher initialization)
        
    end
    
    colCount=colCount+1;
    
end

%%
%%-%-- deal with ScheduledWaves (Bpod 'GlobalTimers')

%can set via SetGlobalTimer(), with the following arguments pairs:

%TimerNumber: The number of the timer you are setting (an integer, 1-5).
%TimerDuration: The duration of the timer, following timer start (0-3600 seconds)
%OnsetDelay: A fixed interval following timer trigger, before the timer start event (default = 0 seconds)
%   If set to 0, the timer starts immediately on trigger and no separate start event is generated.
%OutputChannel: A string specifying an output channel to link to the timer (default = none)
%    Valid output channels are listed in BpodSystem.StateMachineInfo.OutputChannelNames
%OnsetValue: The value to write to the output channel on timer start (default = none)
%   If the linked output channel is a digital output (BNC, Wire), set to 1 = High; 5V or 0 = Low, 0V
%   If the linked output channel is a pulse width modulated line (port LED), set between 0-255.
%   If the linked output channel is a serial module, OnsetValue specifies a byte message to send on timer start.
%OffsetValue: The value to write to the output channel on timer end (default = none)

%syntax translation notes:

% Scheduled Wave -> Global Timer
% name           -> Name
% preamble       -> 'OnsetDelay'
% sustain        -> 'Duration'
% dio_line       -> 'Channel' , note in Solo could have '-1' as internal

% n/a            -> timerId
% n/a            -> 'onsetValue'
% n/a            -> 'offsetValue'

% sound_trig     -> n/a, but could make this happen via the teensy server
% refraction     -> n/a,

%loop through ScheduledWaves, and set corresponding GlobalTimers
if numel(inSMA.sched_waves)>size(outSMA.GlobalTimerStartMatrix,2)
    warning(['translateProtocol.BCtoBpod::you have ' ...
        sprintf('%0.1f',numel(inSMA.sched_waves)) ' Scheduled Waves'])
    warning(['translateProtocol.BCtoBpod::current Bpod setting allow only ' ...
        sprintf('%0.1f',numel(outSMA.GlobalTimers)) ' Global Timers'])
    warning(['translateProtocol.BCtoBpod::translating the first ' ...
        sprintf('%0.1f',numel(outSMA.GlobalTimers)-numel(outSMA.GlobalTimers))...
        ' Scheduled Waves to Global Timers'])
    nswaves=numel(outSMA.GlobalTimers);
else
    nswaves=numel(inSMA.sched_waves);
end

dio_sched_col=inSMA.dio_sched_wave_cols;

for m=1:1:nswaves
    %udpate outSMA.GlobalTimer according to inSMA's sched waves
    
    %NOTE sched wave creation in solo automatically creates two columns in
    %the input matrix per sched wave: one for the start of the wave, and
    %one for the end of the wave
    
    %we will have to determine which state transitions depended on these
    %events, and change them to depend on Bpod Global Timer events
    
    %solo also created one output column per sched wave, holding the name
    %(NOT the numerical id) of the wave
    
    %bpod wants dio line as a string. detect match from remapper
    dio_line = inSMA.sched_waves(m).dio_line;
    
    %bpod uses id as an index! make sure we dont have any zero ids.
    if any(cell2mat({inSMA.sched_waves.id})==0)
        %add one to all ids
        for h=1:1:numel(inSMA.sched_waves)
            inSMA.sched_waves(h).id=inSMA.sched_waves(h).id+1;
        end
    end
    % Optional arguments: (..., Duration, myduration, OnsetDelay, mydelay, Channel, mychannel, ...
    %                      OnMessage, my_onmessage, OffMessage, my_offmessage, LoopMode, my_loopmode,...
    %                      SendEvents, y_n, LoopInterval, myInterval)
    
    outSMA = SetGlobalTimer(outSMA, 'TimerID', inSMA.sched_waves(m).id,...
        'Duration',   inSMA.sched_waves(m).sustain,...  % sustain
        'OnsetDelay', inSMA.sched_waves(m).preamble,... % premable
        'Channel',    inSMA.sched_waves(m).dio_line,... % output channel, by string! e.g. 'BNC1'
        'OnsetValue', 0,...                             %
        'OffsetValue',0);                               %
    
end

if exist('SchedWaveRows','var')
    for b=1:1:size(schedWaveRows,1)
        %JPL - is this the right thing to set
        outSMA.globalTimers(b)=schedWaveRows{b,2};
    end
end


%%
%%%--Bpod stuff

%eg. handle case where people want hybdrid SMA with bpod + solo
%features, e.g. global counters

%UNDER DEVELOPMENT

end