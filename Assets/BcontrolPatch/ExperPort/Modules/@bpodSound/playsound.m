function [] = playsound(sm, trigger)
    global BpodSystem
    debugging = 0;
    
   mydata = get(sm.myfig, 'UserData');
   
   if (trigger < 0),
       BpodSystem.PluginObjects.SoundServer.stop;
   else
       if ~ismember(trigger, mydata.allowed_trigs),
          error(['trigger must be one of ' sprintf('%d ',mydata.allowed_trigs)]);
       end;

       soundname = ['sound' num2str(trigger)];
       drawnow;
       if debugging, fprintf(1, 'Hop 1\n'); end;
       BpodSystem.PluginObjects.SoundServer.play(trigger);
   end

end
   
