function SendBpodSoftCode(Code)
global BpodSystem
if BpodSystem.Status.InStateMatrix == 1
    if Code <= BpodSystem.HW.n.SoftCodes && Code ~= 0
        BpodSystem.SerialPort.write(['~' Code-1], 'uint8');
    else
        error(['Error: cannot send soft code ' num2str(Code) '; Soft codes must be in range: [0 ' num2str(BpodSystem.HW.n.SoftCodes) '].']) 
    end
else
    error('Error sending soft code: Bpod must be running a trial.')
end
