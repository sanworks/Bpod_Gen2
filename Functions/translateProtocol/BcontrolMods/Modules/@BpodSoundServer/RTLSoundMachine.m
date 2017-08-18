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
function [sm] = RTLSoundMachine(host,port,def_card)
  sm.host = 'localhost';
  sm.port = 3334;
  sm.sample_rate = 200000; 
  sm.def_card = 0;

  switch nargin
    case 0
      warning('Using defaults for RTLSoundMachine host and port');
    case 1
      if (isa(host,'RTLSoundMachine')), sm = host; return; end;
      sm.host = host;
    case 2
      sm.host = host;
      sm.port = port;
    case 3
      sm.host = host;
      sm.port = port;
      sm.def_card = def_card;
    otherwise
      error('Please pass 3 or fewer arguments to RTLSoundMachine');
  end;
  
  sm.handle = SoundTrigClient('create', sm.host, sm.port);
  sm = class(sm, 'RTLSoundMachine');
  % just to make sure to explode here if the connection failed
  SoundTrigClient('connect', sm.handle);
  ChkConn(sm);
  sm = SetCard(sm, sm.def_card);
  return;


