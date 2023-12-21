function UpdateBpodComponents(TrialParams, TrialTypes, nStartedTrials, Stimuli)

Stim1Modality = TrialParams.StimulusModality1(nStartedTrials);
Stim2Modality = TrialParams.StimulusModality2(nStartedTrials);

%% Update olfactometer flow rates
try
    if strcmp(Stim1Modality{1}, 'Odor')
        Stim1ID = TrialParams.StimulusID1(nStartedTrials);
        if Stim1ID > 0
            OdorTable = Stimuli.OdorStimuli;
            Bank1FlowRate = OdorTable{Stim1ID+1, 4};
            Bank2FlowRate = OdorTable{Stim1ID+1, 5};
            load OlfConfig
            OlfServerIP = OlfConfig.OlfServerIP;
            IPString = [num2str(OlfServerIP(1)) '.' num2str(OlfServerIP(2)) '.' num2str(OlfServerIP(3)) '.' num2str(OlfServerIP(4))];
            % Change Flowrates
            TCPWrite(IPString, 3336, ['WRITE BankFlow' num2str(1+OlfConfig.BankPairOffset) '_Actuator ' num2str(Bank1FlowRate)]);
            pause(.05)
            TCPWrite(IPString, 3336, ['WRITE BankFlow' num2str(2+OlfConfig.BankPairOffset) '_Actuator ' num2str(Bank2FlowRate)]);
        end
    elseif (strcmp(Stim2Modality{1}, 'Odor')) && (TrialParams.UsingStim2(nStartedTrials) == 1)
        Stim2ID = TrialParams.StimulusID2(nStartedTrials);
        if Stim2ID > 0
            OdorTable = Stimuli.OdorStimuli;
            Bank1FlowRate = OdorTable{Stim2ID+1, 4};
            Bank2FlowRate = OdorTable{Stim2ID+1, 5};
            load OlfConfig
            OlfServerIP = OlfConfig.OlfServerIP;
            IPString = [num2str(OlfServerIP(1)) '.' num2str(OlfServerIP(2)) '.' num2str(OlfServerIP(3)) '.' num2str(OlfServerIP(4))];
            % Change Flowrates
            TCPWrite(IPString, 3336, ['WRITE BankFlow' num2str(1+OlfConfig.BankPairOffset) '_Actuator ' num2str(Bank1FlowRate)]);
            pause(.05)
            TCPWrite(IPString, 3336, ['WRITE BankFlow' num2str(2+OlfConfig.BankPairOffset) '_Actuator ' num2str(Bank2FlowRate)]);
        end
    end
catch
    BpodErrorSound
    msgbox('Olfactometer com failure. Close protocol and check olfactometer.', 'modal');
end