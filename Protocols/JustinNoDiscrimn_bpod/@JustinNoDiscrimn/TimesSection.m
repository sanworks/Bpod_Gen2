function [x, y] = TimesSection(obj, action, x, y)

GetSoloFunctionArgs;

switch action
    case 'init',
        % Save the figure and the position in the figure where we are
        % going to start adding GUI elements:
        fnum=gcf;
        SoloParamHandle(obj, 'my_gui_info', 'value', [x y fnum.Number]);
        
        NumeditParam(obj,'MinimumITI', 2, x, y,'TooltipString',...
            'Used by MotorsSection to pause trial after motor moving to meet the minimum ITI');
        next_row(y);
        MenuParam(obj, 'WaterValveDelay', {'0.0','0.001','0.2','0.4','0.5','0.6','0.7','0.8'},...
            '0.0', x, y, 'TooltipString','Time allowed for removing the pole before start answering period');
        next_row(y);
        NumeditParam(obj, 'WaterValveTime', 0.06, x, y, 'TooltipString','Water Valve Open Time');
        next_row(y);
        MenuParam(obj, 'SamplingPeriodTime', {'1.0','1.5','2.0','2.5','3.0','4.0','5.0'},'3.0', x, y);
        next_row(y);
        MenuParam(obj, 'AnswerPeriodTime',{'0.75','1.0','1.25','1.5','1.75','2.0','2.5','3.0'}, '1.5', x,y); %
        next_row(y);
        MenuParam(obj, 'DrinkTime',{'0.75','1.0','1.25','1.5','1.75','2.0','2.5','3.0'}, '0.75', x,y); %
        next_row(y);
        MenuParam(obj, 'InitHoldTime',{'0.0','0.001','0.2','0.5','0.75','1.0','1.25','1.5','1.75','2.0','2.5','3.0'}, '0.001', x,y); %
        next_row(y);
        MenuParam(obj, 'TimeOutWaitDur',{'0.0','0.001','0.2','0.5','0.75','1.0','1.25','1.5','1.75','2.0','2.5','3.0'}, '0.001', x,y); % 
        next_row(y);
        MenuParam(obj, 'PoleCueDur',{'0.2','0.5','0.75','1.0','1.25','1.5','1.75','2.0','2.5','3.0'}, '0.5', x,y); % 
        next_row(y);
        MenuParam(obj, 'RewCueDur', {'0.2','0.5','0.75','1.0','1.25','1.5','1.75','2.0','2.5','3.0'},'0.5', x,y); % 
        next_row(y);
        MenuParam(obj, 'AnswerDelayDur', {'0.0', '0.001', '0.25','0.5', '0.75', '1.0', '1.25','1.5','1.75', '2.0','2.25', '2.5','2.75', '3.0','random'},'0.001', x,y); % 
        next_row(y);
        MenuParam(obj, 'DelayPeriodTime', {'0.0', '0.001', '0.25','0.5', '0.75', '1.0', '1.25','1.5','1.75', '2.0','2.25', '2.5','2.75', '3.0','random'},'0.001', x, y);
        next_row(y);
        MenuParam(obj, 'pole_delay', {'0.0','0.001', '0.25','0.5', '0.75', '1.0','random'},'random',x,y);
        next_row(y);
        MenuParam(obj, 'GoCueDur',{'0.2','0.5','0.75','1.0','1.25','1.5','1.75','2.0','2.5','3.0'}, '0.5', x,y); % 
        next_row(y);
        MenuParam(obj, 'InitCueDur',{'0.2','0.5','0.75','1.0','1.25','1.5','1.75','2.0','2.5','3.0'}, '0.5', x,y); % 
        next_row(y);
        MenuParam(obj, 'FailCueDur',{'0.2','0.5','0.75','1.0','1.25','1.5','1.75','2.0','2.5','3.0'}, '0.5', x,y); % 
        next_row(y);
        NumeditParam(obj, 'TouchFiltWinMean', 0.001, x, y, 'TooltipString',...
            'Length if avg ewindow for touch snsor filtering in S.');
        next_row(y);
        NumeditParam(obj, 'TouchFiltWinMedian', 0.0007, x, y, 'TooltipString',...
            'Length if avg ewindow for touch snsor filtering in S.');
        next_row(y);
        NumeditParam(obj, 'TouchBaseline', 2*value(TouchFiltWinMean), x, y, 'TooltipString',...
            'Length of touch baseline period in S.'); 
        next_row(y);
        NumeditParam(obj, 'ResonanceTO', 0.72, x, y, 'TooltipString',...
            'Length of touch sensor resonance delay in S.');         
        
        next_row(y, 1.5);
        
    case 'reinit',
        currfig = gcf;
        
        % Get the original GUI position and figure:
        x = my_gui_info(1); y = my_gui_info(2); figure(my_gui_info(3));
        
        % Delete all SoloParamHandles who belong to this object and whose
        % fullname starts with the name of this mfile:
        delete_sphandle('owner', ['^@' class(obj) '$'], ...
            'fullname', ['^' mfilename]);
        
        % Reinitialise at the original GUI position and figure:
        [x, y] = feval(mfilename, obj, 'init', x, y);
        
        % Restore the current figure:
        figure(currfig);
end;

%give StateMatrixSection access to timing variables
SoloFunctionAddVars('StateMatrixSection','rw_args',{'MinimumITI',...
    'WaterValveDelay','WaterValveTime','DelayPeriodTime','pole_delay','SamplingPeriodTime',...
    'AnswerPeriodTime','DrinkTime','InitHoldTime','TimeOutWaitDur','PoleCueDur','RewCueDur',...
    'AnswerDelayDur','GoCueDur','InitCueDur','FailCueDur' ,...
    'TouchFiltWinMean','TouchFiltWinMedian','TouchBaseline','ResonanceTO'});

%give MotorsSection access ITI length
SoloFunctionAddVars('MotorsSection','ro_args',{'MinimumITI'});



   
      