function closePhoneHome(BpodSystem)
if isprop(BpodSystem, 'GUIHandles')
    if isfield(BpodSystem.GUIHandles, 'BpodPhoneHomeFig') && isvalid(BpodSystem.GUIHandles.BpodPhoneHomeFig)
        close(BpodSystem.GUIHandles.BpodPhoneHomeFig)
        % BpodSystem.phoneHomeRegister(0) % this is a private method
    end
end
end