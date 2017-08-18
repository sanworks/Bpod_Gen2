% sm = RTLSoundMachine('host', port, soundcard_number) 
%                Construct a new RTLSoundMachine handle.
%                The host and port that the sound server is listening on
%                Defaults to 'localhost', 3334.  
%
%                The soundcard_number indicates which of the soundcards on the 
%                soundmachine is the intended soundcard to use.  Otherwise an 
%                8th parameter to LoadSound is required to override this.  
%                This parameter is for soundmachines that have more than 1 
%                soundcard.
%
%                A newly constructed RTLSoundMachine has the
%                following default properties:
%
%                Sample Rate:  200000
function [sma] = BpodSoundServer(host,port,def_card)
  sma.host = 'jfrc-68feeb6a95';
  sma.port = 3334;
  sma.sample_rate = 200000; 
  sma.def_card = 0;

  switch nargin
    case 0
      warning('Using defaults for BpodSoundServer host and port');
    case 1
      if (isa(host,'BpodSoundServer')), sma = host; return; end;
      sma.host = host;
    case 2
      sma.host = host;
      sma.port = port;
    case 3
      sma.host = host;
      sma.port = port;
      sma.def_card = def_card;
    otherwise
      error('Please pass 3 or fewer arguments to BpodSoundServer');
  end;

  %JPL - SoundTrigClient not being found...
  %sma.handle = SoundTrigClient('create', sma.host, sma.port);
  sma.handle=0;
  
  sma = class(sma, 'BpodSoundServer');
  % just to make sure to explode here if the connection failed
  %JPL - SoundTrigClient not being found...
  %SoundTrigClient('connect', sma.handle);
  
  %JPL
  %ChkConn(sma);
  
  %DoQueryCmd(sma,'GET CARD')
  %sma = SetCard(sma, sma.def_card);
  return;


