function InputsEnabled = defineDefaultInputsEnabled(BpodSystem)
% Define default InputsEnabled/InputConfig
% InputsEnabled = defineDefaultInputsEnabled(BpodSystem)

InputsEnabled = zeros(1,BpodSystem.HW.n.Inputs);
portPos = find(BpodSystem.HW.Inputs == 'P');
if ~isempty(portPos)
    InputsEnabled(portPos(1:3)) = 1;
end
InputsEnabled(BpodSystem.HW.Inputs == 'B') = 1;
if BpodSystem.MachineType > 1 % v0.7+ uses optoisolators on wire channels; OK to enable by default
    InputsEnabled(BpodSystem.HW.Inputs == 'W') = 1;
end
if BpodSystem.MachineType == 4
    InputsEnabled(BpodSystem.HW.Inputs == 'F') = 1; % Enable all flex inputs (for testing)
end

end