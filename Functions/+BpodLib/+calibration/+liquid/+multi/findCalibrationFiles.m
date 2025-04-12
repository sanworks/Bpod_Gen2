function filenames = findCalibrationFiles(BpodSystem)
% Find LiquidCalibration-COMX files
% :return: Cell array of filenames for liquid calibration files
% :rtype: cell

calibrationFolder = fullfile(BpodSystem.Path.LocalDir, 'Calibration Files');

itemlist = dir(calibrationFolder);
existing_filenames = {itemlist.name};

filenames = {};
for filename = existing_filenames
    [~, name, ext] = fileparts(filename);
    % name = name
    if numel(name) < 17
        continue % shorter than LiquidCalibration
    end
    
    postsplit = strsplit(name, '-');
    if numel(postsplit) ~= 2
        continue
    end
    comport = postsplit{2};
    filenames = [filenames ['LiquidCalibration-' comport ext]];
end

end