% Get the sound intensity produced by a pure tone of a particular
% amplitude and frequency going into the speaker.
%
% Santiago Jaramillo - 2007.11.14
% Uri  - 2013.05.27
% Fede - 2015.09.10

function [BandPower, signal_toplot, Parameters, ThisPSD] = response_one_sound(SoundParam,BandLimits)
global BpodSystem
% --- Parameters of the test ---
Parameters.ToneDuration = 1;%0.8;         % sec
Parameters.TimeToRecord = 0.3;        % sec
Parameters.FsOut = 192000;              % Sampling frequency
tvec = 0:1/Parameters.FsOut:Parameters.ToneDuration;

% --- Setting up PSD estimation ---
hPSD = spectrum.welch;
hPSD.SegmentLength=2048*8;

% --- Set the acquisition card ---
channel = 1;
n_chan = 1; 

Parameters.FsIn = 200000;
n_data = Parameters.TimeToRecord*Parameters.FsIn;

% --- Creating and loading sounds ---
SoundVec = SoundParam.Amplitude * sin(2*pi*SoundParam.Frequency*tvec);

if SoundParam.Speaker==1
    SoundVec = [ SoundVec; zeros(1,length(SoundVec)) ];
end
if SoundParam.Speaker==2
    SoundVec = [ zeros(1,length(SoundVec)); SoundVec ];
end

% Load sound
PsychToolboxSoundServer('Load', 1, SoundVec);

% --- Play the sound ---
PsychToolboxSoundServer('Play', 1);

pause(0.1);
if ispc
    start(BpodSystem.PluginObjects.USB1608G.Board);
    pause(.5);
    RawSignal = getdata(BpodSystem.PluginObjects.USB1608G.Board)';
else
    data = mcc_daq('n_scan',n_data,'freq',Parameters.FsIn,'n_chan',n_chan);
    RawSignal = data(channel,:); 
end

pause(Parameters.ToneDuration);

signal_toplot = [0:1/Parameters.FsIn:(size(RawSignal,2)-1)/Parameters.FsIn; RawSignal];

PsychToolboxSoundServer('StopAll');

% --- Calculate power ---
ThisPSD = psd(hPSD,RawSignal,'Fs',Parameters.FsIn);
BandPower = band_power(ThisPSD.Data,ThisPSD.Frequencies,BandLimits);


function StimuliVec=SqCosBeeper(RR,SR,Freq,BeepDuration,CosRamp,MaxToneDuration)

t1=0:1/SR:((BeepDuration/1000)-(1/SR));
T=1/SR:1/SR:MaxToneDuration;
GetOnset=mod(T,(1/RR));%% find beep onset index
GetOnset=[1 find(diff(diff(GetOnset)>0)==-1)+3];
CosRampLength=floor(CosRamp/1000*SR);
BeepLength=floor(BeepDuration/1000*SR);
ramp=(cos(t1(1:CosRampLength)*pi*2*1000/CosRamp)*-1+1)/2;
SpitRampInx=find(diff(ramp)<=0,1,'first');
UpRamp=ramp(1:SpitRampInx);
DwRamp=ramp(SpitRampInx+1:end);
Ramp=[UpRamp ones(1,BeepLength-CosRampLength),DwRamp];
FreqComponenmts=sum(sin(2*pi*T'*Freq+repmat(rand(1,length(Freq))*2*pi, length(T), 1)),2)';

% integrate beep into one long vec
BeepVec=zeros(size(T));
for ii=GetOnset
    BeepVec(ii:ii+length(t1)-1)=Ramp;
end
BeepVec(MaxToneDuration*SR+1:end)=[];
StimuliVec=FreqComponenmts.*BeepVec;
