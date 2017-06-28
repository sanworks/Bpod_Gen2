% This function finds the right attenuation for signal to get
% a desired sound pressure level.
%
% Santiago Jaramillo - 2007.11.15
% Modified by Peter Znamenskiy - 2009.02.18
% Modified by F. Carnevale - 2015.02.19

function [Amplitude] = find_amplitude(SoundParam,TargetSPL,BandLimits, handles)
    global BpodSystem
    InitialAmplitude = 0.2;
    AcceptableDifference_dBSPL = 0.5;
    MaxIterations = 8;
    SPLref = 20e-6;                         % Pa

    SoundParam.Amplitude = InitialAmplitude;
    
    axes(handles.signalFig);

    for inditer=1:MaxIterations
        if BpodSystem.PluginObjects.SoundCal.Abort
            error('Calibration Manually Aborted. Please restart the calibrator before trying again.')
        end
        [PowerAtThisFrequency, signal_toplot] = response_one_sound(SoundParam,BandLimits);
        PowerAtThisFrequency_dBSPL = 10*log10(PowerAtThisFrequency/SPLref^2);
        
        % plot spectrum of recorded sound
        Fs = 200000; % Sampling frequency
        L = size(signal_toplot,2); % Length of signal
       
        X = signal_toplot(2,:);
        Y = fft(X);

        P2 = abs(Y/L);
        P1 = P2(1:L/2+1);
        P1(2:end-1) = 2*P1(2:end-1);

        f = Fs*(0:(L/2))/L;
    
        plot(f/1000,P1)
        semilogx(f/1000,P1);
        axis([0.01 100 0 0.1])
        New_XTickLabel = get(gca,'xtick');
        set(gca,'XTickLabel',New_XTickLabel);
                
        
        set(handles.freq_lbl,'String', num2str(SoundParam.Frequency));
        set(handles.attn_lbl,'String',num2str(SoundParam.Amplitude));
        set(handles.pwr_lbl,'String',num2str(PowerAtThisFrequency_dBSPL));

        PowerDifference_dBSPL = PowerAtThisFrequency_dBSPL - TargetSPL;
        if(abs(PowerDifference_dBSPL)<AcceptableDifference_dBSPL)
            break;
        elseif(inditer<MaxIterations)
            AmpFactor = sqrt(10^(PowerDifference_dBSPL/10));
            SoundParam.Amplitude = SoundParam.Amplitude/AmpFactor;
            % If it cannot find the right level, set to 0.1
            if(SoundParam.Amplitude>1)
                SoundParam.Amplitude=1;
            end
        end
    end
    
    Amplitude = SoundParam.Amplitude;
 
