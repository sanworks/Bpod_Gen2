function SendBpodSoftCode(Code)
BpodSerialWrite(['VS' Code], 'uint8');
