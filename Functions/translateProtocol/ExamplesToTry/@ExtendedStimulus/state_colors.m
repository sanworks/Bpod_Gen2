function SC = state_colors(obj)


% Colors that the various states take when plotting
SC = struct( ...
          'wait_for_cpoke',      [218 112 214]/300, ...  % orchid
          'wait_for_cpoke2',     [218 200 214]/300, ...  % green+ orchid
          'center_to_center_gap',[255 236 139]/305, ...  % darker goldenrod 
          'center_to_side_gap',  [255 236 139]/255, ...  % light goldenrod 
          'center_to_side_gap2', [255 236 139]/280, ...  % slightly darker goldenrod 
          'wait_for_spoke',      [132 111 255]/255, ...  % slate blue
          'hit_state',           [50  255  50]/255, ...  % green
          'left_reward',         [50  205  50]/255, ...  % spring green
          'right_reward',        [50  205  50]/255, ...  % spring green
          'warning',             [0.3  0    0],    ...   % dark maroon
          'danger',              [0.5  0.05 0.05], ...   % lighter maroon
          'soft_drink_state',    [40  255  40]/255, ...  % also green
          'iti',                 [0.5 0.5 0.5], ...
          'error_state',         [255   0   0]/255, ...  % red
          'state_0',             [1   1   1  ],  ...
          'check_next_trial_ready',     [0.7 0.7 0.7]);

