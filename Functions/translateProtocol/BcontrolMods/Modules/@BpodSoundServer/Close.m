% [] = Close(sm) Begone! Begone!
function [] = Close(sm)
  SoundTrigClient('disconnect', sm.handle);
  sm.handle = -1;
end
