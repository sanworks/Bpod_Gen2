function [DecimalEvents, Timestamps] = OpenEphysEvents2Bpod(filename)
[data, pinChangeTimestamps, info] = load_open_ephys_data(filename);
Pos = find(info.eventId==1, 1, 'first');
BinaryEventCode = '0000000';
nPinChanges = length(pinChangeTimestamps)-Pos+1;
nTotalTimestamps = length(pinChangeTimestamps);
DecimalEvents = zeros(1,nPinChanges);
Timestamps = zeros(1,nPinChanges);
nEvents = 0;

while Pos <= nTotalTimestamps
    nPinsChanged = sum(pinChangeTimestamps == pinChangeTimestamps(Pos));
    for x = 1:nPinsChanged
        BinaryEventCode(8-(data(Pos)+1)) = num2str(info.eventId(Pos));
        Pos = Pos + 1;
    end
    nEvents = nEvents + 1;
    if (Pos <= nTotalTimestamps)
        DecimalEvents(nEvents) = bin2dec(BinaryEventCode);
        Timestamps(nEvents) = pinChangeTimestamps(Pos);
    else
        i = nPinChanges;
    end
end
DecimalEvents = DecimalEvents(1:nEvents-1);
Timestamps = Timestamps(1:nEvents-1);
% Some systems that read TTL inputs exactly during sync pin update will
% report a false value, followed by the true value on the next measurement.
% The following code will filter out Bpod events that appear to occur less than 1 ephys
% cycle (50us) apart. Note that Bpod cycles every 150us, so this is the
% smallest possible difference between events.
RealEvents = diff(Timestamps) > 0.00005;
RealEvents = [1 RealEvents]; % Add a 1 so the indexes of the misreads align
DecimalEvents = DecimalEvents(RealEvents);
Timestamps = Timestamps(RealEvents);