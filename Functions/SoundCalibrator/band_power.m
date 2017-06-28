% Estimate the total power within a frequency band given
% the Power Spectrum Density estimate (in dB/Hz).
%
% [BandPower,BandPower_dBSPL] = band_power(PSDvec,PSDfreq,BandLimits)
%
% Santiago Jaramillo - 2007.11.13

function [BandPower,BandPower_dBSPL] = band_power(PSDvec,PSDfreq,BandLimits)

[tmpvar,IndexLowFreq]=min(abs(PSDfreq-BandLimits(1)));
[tmpvar,IndexHigFreq]=min(abs(PSDfreq-BandLimits(end)));
IndexRange = IndexLowFreq:IndexHigFreq;

SPLref = 20e-6;                         % Pa
BandPower = mean(PSDvec(IndexRange)) * diff(PSDfreq(IndexRange([1,end])));
BandPower_dBSPL = 10*log10(BandPower/SPLref^2);

%fprintf('Band power (from PSD)     : %0.6f    (%0.2f dB-SPL)\n',BandPower,BandPower_dBSPL);
