% function [res] = SendAllAOWaves(sm)
% function [res] = SendAllAOWaves(sm,swap_state_0_flg)
%    Updates the AO waves from the in-memory settings to the
%    server.  This is normally implicitly called by
%    SetStateMatrix.m and SetStateProgram.m and needs not be called explicitly
function [res] = SendAllAOWaves(varargin)

  if (nargin < 1 | nargin > 2), error('Invalid number of args to SendAllAOWaves'); end;
  sm = varargin{1};
  swap_state_0_flg = 0;
  if (nargin == 2), swap_state_0_flg = varargin{2}; end;
  
  res = 1;
  
  % now, send the AO waves *that changed* Note that sending an empty matrix
  % is like clearing a specific wave
  for idx=1:size(sm.sched_waves_ao, 1),
      id = sm.sched_waves_ao{idx,1};
      ao = sm.sched_waves_ao{idx,2}-1;
      loop = sm.sched_waves_ao{idx,3};
      mat = sm.sched_waves_ao{idx,4};
      mat(2,:) = mat(2,:)-1; % translate matrix to 0-indexed -- meaning invalid evt cols are negative
      [m,n] = size(mat);
      [res] = FSMClient('sendstring', sm.handle, sprintf('SET AO WAVE %u %u %u %u %u %u\n', m, n, id, ao, loop, swap_state_0_flg));
      if (m && n), 
           ReceiveREADY(sm, 'SET AO WAVE'); 
          [res] = FSMClient('sendmatrix', sm.handle, mat);
      end;          
      ReceiveOK(sm, 'SET AO WAVE');  
  end;
