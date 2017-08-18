function [out, cloud, cloud_toplot] = GenerateToneCloud(rewarded, r, StimSettings)
%{ 
GENERATETONECLOUD: Generates Cloud of tones

This function is based on MakeToneCloud (written by P.Z.) which can be found in SoundSection.m
Not all features have been imported to this version. 

% To do:
error handling
%}

%r is as defined by PZ (0 to 1), 0 meaning that the probability of target and non target freq is the same

global BpodSystem

nTones = StimSettings.nTones;
ToneOverlap = StimSettings.ToneOverlap;
ToneDuration = StimSettings.ToneDuration;
minFreq = StimSettings.minFreq;
maxFreq = StimSettings.maxFreq;
SamplingRate = StimSettings.SamplingRate;
nTones_noEvidence = StimSettings.Noevidence;
Volume = StimSettings.Volume;
 
nFreq = StimSettings.nFreq; % Number of different frequencies to sample from
toneFreq = logspace(log10(minFreq),log10(maxFreq),nFreq); % Nfreq logly distributed
SoundCal = BpodSystem.CalibrationTables.SoundCal;
toneAtt = polyval(SoundCal(1,1).Coefficient,toneFreq)';

diffSPL = Volume - SoundCal(1,1).TargetSPL;
attFactor = sqrt(10.^(diffSPL./10));

att = toneAtt.*repmat(attFactor,nFreq,1);

nTones_Evidence = nTones - nTones_noEvidence; % Number of tones with controlled evidence
ramp = StimSettings.ramp; % Fraction of tone duration that is used for the envelope

seed = 1;
% if ~isnan(seed) 
%     rand('twister',seed);
% end
        
noEvidence_ind = randi(nFreq,1,nTones_noEvidence); % Frequency indices of no evidence tones

pTarget = (1/2+r/2);
%boundy = [nFreq/3 2/3*nFreq]; % debugging purposes


switch true
    case strcmp(rewarded,'low')

        Evidence_ind = randi(nFreq/3,1,nTones_Evidence)+nFreq*2/3; % Fill everything with nontarget (high)
        
        %this gives exactly the number of tones according to the pTarget
        %nTarget = round(nTones_Evidence*pTarget); % Number of tones with target frequencies
        %ind_replace = randperm(nTones_Evidence); % Indices to replace with target frequencies
        %Evidence_ind(ind_replace(1:nTarget))=randi(nFreq/3,1,nTarget); % Replace with target freqs (low)
        
        %this draws a independent random numbers for each slot
        %note that the amount of slots with target freq will vary from
        %trial to trial, even when the same pTarget
        ind_replace = find(rand(1,nTones_Evidence)<pTarget);
        nTarget = size(ind_replace,2); % Number of tones with target frequencies
        Evidence_ind(ind_replace)=randi(nFreq/3,1,nTarget); % Replace with target freqs (low)
        

    case strcmp(rewarded,'high')

        Evidence_ind = randi(nFreq/3,1,nTones_Evidence); % Fill everything with nontarget (low)
        
        %this gives exactly the number of tones according to the pTarget
        %nTarget = round(nTones_Evidence*pTarget); % Number of tones with target frequencies
        %ind_replace = randperm(nTones_Evidence); % Indices to replace with target frequencies
        %Evidence_ind(ind_replace(1:nTarget))=randi(nFreq/3,1,nTarget)+2/3*nFreq; % Replace with target freqs (high)
        
        %this draws a independent random numbers for each slot
        %note that the amount of slots with target freq will vary from
        %trial to trial, even when the same pTarget
        ind_replace = find(rand(1,nTones_Evidence)<pTarget);
        nTarget = size(ind_replace,2); % Number of tones with target frequencies
        Evidence_ind(ind_replace)=randi(nFreq/3,1,nTarget)+2/3*nFreq; % Replace with target freqs (high)
end

cloud = [noEvidence_ind Evidence_ind]; % Complete stream of tones
freqs = toneFreq(cloud); % Frequencies
Amps = att(cloud,:); % Tone amplitudes
toneVec = 1/SamplingRate:1/SamplingRate:ToneDuration; % Here go the tones

omega=(acos(sqrt(0.1))-acos(sqrt(0.9)))/ramp; % This is for the envelope
t=0 : (1/SamplingRate) : pi/2/omega;
t=t(1:(end-1));
RaiseVec= (cos(omega*t)).^2;

Envelope = ones(length(toneVec),1); % This is the envelope
Envelope(1:length(RaiseVec)) = fliplr(RaiseVec);
Envelope(end-length(RaiseVec)+1:end) = (RaiseVec);
Envelope = repmat(Envelope,1,length(freqs));

tones = (sin(toneVec'*freqs*2*pi)).*Envelope; % Here are the enveloped tones as a matrix

% Create the stream

%uncomment for using two channels
%out = zeros(round(length(freqs)*length(toneVec)-(length(freqs)-1)*ToneOverlap*length(toneVec)),2);

out = zeros(1,round(length(freqs)*length(toneVec)-(length(freqs)-1)*ToneOverlap*length(toneVec)));

cloud_toplot = nan(nFreq,floor(round(length(freqs)*length(toneVec)-(length(freqs)-1)*ToneOverlap*length(toneVec))/100));
for ind = 1:length(cloud)
    tonePos = round((ind-1)*length(toneVec)*(1-ToneOverlap))+1:round((ind-1)*(1-ToneOverlap)*length(toneVec))+length(toneVec);
    out(1,tonePos) = out(1,tonePos) + tones(:,ind)'*Amps(ind,1)';
    
    %uncomment for using two channels
    %out(2,tonePos) = out(2,tonePos) + tones(:,ind)'*Amps(ind,2)';
    
    cloud_toplot(cloud(ind),unique(ceil(tonePos/100))) = cloud(1,ind); 
end

%%plot waveform
%figure
%plot(out(:,1))
%plot tone cloud_toplot
%hold off; plot(cloud_toplot','k','linewidth',3);hold on;plot(boundy(1)*ones(1,length(cloud_toplot)),'--k');plot(boundy(2)*ones(1,length(cloud_toplot)),'--k');axis([0 length(out) 0 18])

%rand('twister',sum(clock));     % reset random seed

return
