function closeMessageBoxes(BpodSystem)
% Close message boxes opened during Bpod's verbose/GUI startup
% closeMessageBoxes(BpodSystem)

if ~isprop(BpodSystem, 'GUIHandles')
    return
end

messageBoxFields = {'BpodPhoneHomeFig', 'LiquidCalWarningMessageBox'};

for idx = 1:numel(messageBoxFields)
    fieldName = messageBoxFields{idx};
    if isfield(BpodSystem.GUIHandles, fieldName) && isvalid(BpodSystem.GUIHandles.(fieldName))
        close(BpodSystem.GUIHandles.(fieldName));
        BpodSystem.GUIHandles = rmfield(BpodSystem.GUIHandles, fieldName);
    end
end
