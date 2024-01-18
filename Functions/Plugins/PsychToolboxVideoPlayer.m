%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) Sanworks LLC, Rochester, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}

% PsychToolboxVideoPlayer is a class to play videos on a second monitor,
% using PsychToolbox's Screen class. Videos are loaded to a library in advance, 
% and played back by index during the trial. A configurable "sync patch" in the corner of the
% screen can drive a photodiode for synchronization of frame onset time.
%
% Usage Notes:
%
% V = PsychToolboxVideoPlayer(monitorID, viewPortSize, viewPortOffset, syncPatchSize, syncPatchYOffset)
%
% monitorID: Index of the monitor to use (e.g. 1 or 2 in a dual monitor setup)
%
% viewPortSize: A portion of the window [x, y] in pixels can be used to show the video. Window area not in the viewport will be black,
% and can contain the sync patch. Set ViewPortSize to 0 to use the entire screen.
%
% viewPortOffset: Offset of the view port, [x, y] in pixels
%
% syncPatchSize: Size of the sync patch, [x, y] in pixels. The sync patch is rendered in the lower right corner of the screen. 
% It alternates from white to black with each subsequent frame to signal frame changes to an optical sensor.
%
% syncPatchYOffset: Offset of the sync patch from the bottom screen edge


classdef PsychToolboxVideoPlayer < handle
    properties
        Window % PsychToolbox Window object
        DetectedFrameRate % Detected frame rate of the target display in Hz
        Videos % Cell array containing videos loaded with obj.loadVideo()
        TextStrings % Cell array containing text strings
        TimerMode = 0; % Use MATLAB timer object to trigger frame flips (default = blocking code loop)
        ShowViewportBorder = 0; % Draw gray border around viewport
        ViewPortDimensions % [y, x]
        SyncPatchIntensity = 128; % In range 0, 255. Set this bright enough to detect, but be careful to avoid saturating the sensor
        SyncPatchActiveArea = 0.8; % Fraction of sync patch dimensions set to white when drawing a white patch. 
                                   % Permanently dark pixels surrounding the sensor helps to hide the sync patch from the test subject
    end
    properties (Access = private)
        nVideosLoaded = 0;
        WindowDimensions % window dimensions
        ViewPortOffset = [0 0]; % x, y from top-left corner of the screen
        MaxVideos = 100;
        SyncPatchSizeX = 30; % Size of sync patch in X dimension, in pixels
        SyncPatchSizeY = 30; % Size of sync patch in Y dimension, in pixels
        SyncPatchYOffset % Sync patch offset from window bottom on Y axis (in pixels)
        SyncPatchDimensions = [0 0 0 0];
        SyncPatchActiveDimensions = [0 0 0 0];
        BlankScreen; % Texture of blanks screen
        Timer % Timer object that controls playback
        TimerFPS = 50; % Frames per second
        CurrentFrame = 1; % Current frame
        StimulusIndex = 1; % Current stimulus
        TextStringFontSize
        TextStringStartPos
        FontName  % Font to use when displaying text objects. Run listfonts; to see installed font names.
        AllFonts % List of all fonts installed on the system
        StimulusType % Vector of 0 = video, 1 = frame with centred text
    end
    methods
        function obj = PsychToolboxVideoPlayer(monitorID, viewPortSize, viewPortOffset, syncPatchSize, syncPatchYOffset)
            % Destroy any orphaned timers from previous instances
            t = timerfindall;
            for i = 1:length(t)
                thisTimer = t(i);
                thisTimerTag = get(thisTimer, 'tag');
                if strcmp(thisTimerTag, 'PTV')
                    warning('off');
                    delete(thisTimer);
                    warning('on');
                end
            end
            obj.AllFonts = listfonts;
            Screen('Preference','SkipSyncTests', 1);
            obj.Videos = cell(1,obj.MaxVideos);
            obj.TextStrings = cell(1,obj.MaxVideos);
            obj.TextStringStartPos = cell(1,obj.MaxVideos);
            obj.TextStringFontSize = ones(1,obj.MaxVideos)*36;
            obj.StimulusType = zeros(1,obj.MaxVideos);
            obj.ViewPortDimensions = viewPortSize;
            obj.ViewPortOffset = viewPortOffset;
            obj.SyncPatchSizeX = syncPatchSize(1);
            obj.SyncPatchSizeY = syncPatchSize(2);
            obj.SyncPatchYOffset = syncPatchYOffset;
            if length(monitorID) ~= 1 
                error('Error: Monitor ID must be a single integer value')
            end
            [obj.Window, monitorSize] = Screen('OpenWindow', monitorID, 0);
            monitorSize(1:2) = 1;
            windowSize = monitorSize(3:4);
            obj.WindowDimensions = [monitorSize(3)-windowSize(1) monitorSize(4)-windowSize(2)... 
            monitorSize(3) monitorSize(4)];
            obj.DetectedFrameRate = Screen('FrameRate', obj.Window);
            obj.TimerFPS = obj.DetectedFrameRate;
            frame = zeros(windowSize(2), windowSize(1));
            yEnd = windowSize(2);
            xEnd = windowSize(1);
            patchStartY = yEnd-obj.SyncPatchSizeY - syncPatchYOffset;
            patchStartX = xEnd-obj.SyncPatchSizeX;
            obj.SyncPatchDimensions = [patchStartY patchStartY+obj.SyncPatchSizeY patchStartX xEnd];
            obj.SyncPatchActiveDimensions = round([patchStartY+(obj.SyncPatchSizeY*(1-obj.SyncPatchActiveArea))... 
                                                   patchStartY+obj.SyncPatchSizeY... 
                                                   patchStartX+(obj.SyncPatchSizeX*(1-obj.SyncPatchActiveArea)) xEnd]);
            if obj.ViewPortDimensions == 0
                obj.ViewPortDimensions = obj.WindowDimensions(3:4);
            end
            if obj.ShowViewportBorder
                frame = obj.addShowViewportBorder(frame);
            end
            obj.Timer = timer('TimerFcn','', 'Period', round(1/obj.TimerFPS*1000)/1000, 'ExecutionMode', 'fixedRate', 'Tag', 'PTV');
            obj.BlankScreen = Screen('MakeTexture', obj.Window, frame);
            Screen('DrawTexture', obj.Window, obj.BlankScreen);
            Screen('Flip', obj.Window);
        end

        function set.SyncPatchIntensity(obj, value)
            if value > 255 || value < 0
                error('Error: Sync Patch Intensity must be an integer in range [0, 255]')
            end
            if obj.nVideosLoaded > 0
                disp(['***Warning*** The sync patch was previously rendered in the video frames loaded to the server.'... 
                      char(10) 'Existing videos must be re-loaded manually to use the new sync patch parameter.'])
            end
            obj.SyncPatchIntensity = value;
        end

        function set.SyncPatchActiveArea(obj, value)
            if value > 1 || value < 0
                error('Error: Sync Patch Active Area must be a value in range [0, 1]')
            end
            if obj.nVideosLoaded > 0
                disp(['***Warning*** The sync patch was previously rendered in the video frames loaded to the server.'... 
                      char(10) 'Existing videos must be re-loaded manually to use the new sync patch parameter.'])
            end
            obj.SyncPatchActiveDimensions = [obj.SyncPatchDimensions(1) + (obj.SyncPatchSizeY*(1-value))... 
                                             obj.SyncPatchDimensions(1) + obj.SyncPatchSizeY... 
                                             obj.SyncPatchDimensions(3) + (obj.SyncPatchSizeX*(1-value))... 
                                             obj.SyncPatchDimensions(4)];
            obj.SyncPatchActiveArea = value;
        end

        function set.ShowViewportBorder(obj, value)
            if value > 1 || value < 0
                error('Viewport Border must be 0 (off) or 1 (on)')
            end
            frame = zeros(obj.WindowDimensions(4)-obj.WindowDimensions(2), obj.WindowDimensions(3)-obj.WindowDimensions(1));
            if obj.ShowViewportBorder
                frame = obj.addShowViewportBorder(frame);
            end
            obj.BlankScreen = Screen('MakeTexture', obj.Window, frame);
            Screen('DrawTexture', obj.Window, obj.BlankScreen);
            Screen('Flip', obj.Window);
            disp(['Viewport border set. You must now manually re-load any stimuli you had previously loaded with loadVideo(),' ...
                  'because the border is rendered into the video frames.'])
            obj.ShowViewportBorder = value;
        end

        function loadVideo(obj, videoIndex, videoMatrix)
            if ~isempty(obj.Videos{videoIndex})
                Screen('Close', obj.Videos{videoIndex}.Data);
            end
            obj.Videos{videoIndex} = struct;
            matrixSize = size(videoMatrix);
            vpDim = obj.ViewPortDimensions;
            dimensionError = 0;
            if ~(matrixSize(1) == vpDim(2)) && (matrixSize(2) == vpDim(1))
                 dimensionError = 1;
            end
            if length(matrixSize) == 4
                if matrixSize(3) == 3
                    matrixType = 2; % Stack of RGB Frames
                    nFrames = matrixSize(4);
                else
                    dimensionError = 1;
                end
            elseif length(matrixSize) == 3
                if matrixSize(3) == 3
                     matrixType = 2; % Single RGB Frame
                     nFrames = 1;
                else
                     matrixType = 1; % Stack of B&W Frames
                     nFrames = matrixSize(3);
                end
            elseif length(matrixSize) == 2
                matrixType = 1; % Single B&W Frame
                nFrames = 1;
            else
                error('Error: Video data must be a stack of 2-D images.')
            end
            if dimensionError
                error(['Error loading video: The video dimensions must match the viewport dimensions: ' num2str(vpDim(1)) ' X ' num2str(vpDim(2))]);
            end
            obj.Videos{videoIndex}.nFrames = nFrames+1; % +1 to account for blank frame at the end
            obj.Videos{videoIndex}.Data = zeros(1,nFrames);
            signalOn = 1;
            for i = 1:nFrames
                switch matrixType
                    case 1
                        frame = zeros(obj.WindowDimensions(4)-obj.WindowDimensions(2), obj.WindowDimensions(3)-obj.WindowDimensions(1));
                        frame(1+obj.ViewPortOffset(2):obj.ViewPortDimensions(2)+obj.ViewPortOffset(2),... 
                              1+obj.ViewPortOffset(1):obj.ViewPortDimensions(1)+obj.ViewPortOffset(1)) = videoMatrix(:,:,i);
                        frame(obj.SyncPatchDimensions(1):obj.SyncPatchDimensions(2),obj.SyncPatchDimensions(3):obj.SyncPatchDimensions(4)) = 0;
                        frame(obj.SyncPatchActiveDimensions(1):obj.SyncPatchActiveDimensions(2),...
                              obj.SyncPatchActiveDimensions(3):obj.SyncPatchActiveDimensions(4)) = signalOn*obj.SyncPatchIntensity;
                    case 2
                        frame = zeros(obj.WindowDimensions(4)-obj.WindowDimensions(2), obj.WindowDimensions(3)-obj.WindowDimensions(1), 3);
                        frame(1+obj.ViewPortOffset(2):obj.ViewPortDimensions(2)+obj.ViewPortOffset(2),... 
                            1+obj.ViewPortOffset(1):obj.ViewPortDimensions(1)+obj.ViewPortOffset(1), :) = videoMatrix(:,:,:,i);
                        frame(obj.SyncPatchDimensions(1):obj.SyncPatchDimensions(2),obj.SyncPatchDimensions(3):obj.SyncPatchDimensions(4),:) = 0;
                        frame(obj.SyncPatchActiveDimensions(1):obj.SyncPatchActiveDimensions(2),...
                            obj.SyncPatchActiveDimensions(3):obj.SyncPatchActiveDimensions(4),:) = signalOn*obj.SyncPatchIntensity;
                end
                if obj.ShowViewportBorder
                    frame = obj.addShowViewportBorder(frame);
                end
                obj.Videos{videoIndex}.Data(i) = Screen('MakeTexture', obj.Window, frame);
                if signalOn == 1
                    signalOn = 0;
                else
                    signalOn = 1;
                end
            end
            % Add final blank frame
            frame = zeros(obj.WindowDimensions(4)-obj.WindowDimensions(2), obj.WindowDimensions(3)-obj.WindowDimensions(1)); % Use actual window width
            if obj.ShowViewportBorder
                    frame = obj.addShowViewportBorder(frame);
            end
            obj.Videos{videoIndex}.Data(i+1) = Screen('MakeTexture', obj.Window, frame);
            obj.StimulusType(videoIndex) = 0;
            obj.nVideosLoaded = obj.nVideosLoaded + 1;
        end

        function loadText(obj, textIndex, textString, varargin)
            obj.TextStrings{textIndex} = cell(1,1);
            obj.TextStrings{textIndex}{1} = textString;
            obj.TextStrings{textIndex}{2} = '';
            if nargin > 3
                if ~isempty(varargin{1})
                    obj.TextStrings{textIndex}{2} = varargin{1};
                end
            end
            obj.TextStringFontSize(textIndex) = 50;
            if nargin > 4
                if ~isempty(varargin{2})
                    obj.TextStringFontSize(textIndex) = varargin{2};
                end
            end
            obj.TextStringStartPos{textIndex} = obj.ViewPortDimensions/2;
            if nargin > 5
                if ~isempty(varargin{3})
                    obj.TextStringStartPos{textIndex} = varargin{3};
                end
            end
            obj.FontName{textIndex} = 'Arial';
            if nargin > 6
                if ~isempty(varargin{4})
                    candidateFont = varargin{4};
                    if sum(strcmp(candidateFont, obj.AllFonts)) == 0
                        error(['Error: ''' candidateFont ''' is not a font installed on the system.' char(10)... 
                            'Run ''listfonts'' at the MATLAB command line for a list of valid font names.'])
                    end
                    obj.FontName{textIndex} = candidateFont;
                end
            end
            obj.StimulusType(textIndex) = 1;
        end

        function play(obj, stimulusIndex)
            if stimulusIndex == 0
                Screen('DrawTexture', obj.Window, obj.BlankScreen);
                Screen('Flip', obj.Window);
            else
                switch obj.StimulusType(stimulusIndex)
                    case 0 % Play video
                        if obj.Videos{stimulusIndex}.nFrames == 1
                            if ~isempty(obj.Timer)
                                stop(obj.Timer);
                            end
                            Screen('DrawTexture', obj.Window, obj.Videos{stimulusIndex}.Data(1));
                            Screen('Flip', obj.Window);
                        else
                            obj.CurrentFrame = 1;
                            obj.StimulusIndex = stimulusIndex;
                            if obj.TimerMode == 1
                                set(obj.Timer, 'TimerFcn', @(x,y)obj.playNextFrame());
                                start(obj.Timer);
                            else
                                for iFrame = 1:obj.Videos{stimulusIndex}.nFrames
                                    Screen('DrawTexture', obj.Window, obj.Videos{obj.StimulusIndex}.Data(iFrame));
                                    [VBLts, SonsetTime, FlipTimestamp, Missed, BeamPos] = Screen('Flip', obj.Window);
                                end
                            end
                        end
                    case 1 % Display text
                        if ~isempty(obj.Timer)
                            stop(obj.Timer);
                        end
                        strings = obj.TextStrings{stimulusIndex};
                        nStrings = sum(~cellfun('isempty', strings));
                        fontSize = obj.TextStringFontSize(stimulusIndex);
                        Screen('TextFont',obj.Window, obj.FontName{stimulusIndex});
                        Screen('TextSize',obj.Window, fontSize);
                        Screen('TextStyle', obj.Window, 1);
                        startPos = obj.TextStringStartPos{stimulusIndex};
                        Y = startPos(1);
                        X = startPos(2);
                        Screen('DrawTexture', obj.Window, obj.BlankScreen);
                        for i = 1:nStrings
                            textSize = Screen('TextBounds', obj.Window, strings{i});
                            ysize = textSize(3);
                            xsize = textSize(4);
                            xoffsetAmt = xsize;
                            if i == 1 && nStrings > 1
                                xoffsetAmt = xsize*1.5;
                            end
                            Screen('DrawText', obj.Window, strings{i}, Y-(ysize/2), X-xoffsetAmt, [255, 255, 255, 255]); X=X+(xsize*1.5);
                        end
                        Screen('Flip', obj.Window);
                end
            end
        end

        function stop(obj)
            stop(obj.Timer);
            set(obj.Timer, 'TimerFcn', '');
            Screen('DrawTexture', obj.Window, obj.BlankScreen);
            Screen('Flip', obj.Window);
        end

        function frame = addShowViewportBorder(obj, frame)
            frame(1+obj.ViewPortOffset(2):obj.ViewPortOffset(2)+obj.ViewPortDimensions(2), 1+obj.ViewPortOffset(1),:) = 64; % Left
            frame(1+obj.ViewPortOffset(2):obj.ViewPortDimensions(2)+obj.ViewPortOffset(2), obj.ViewPortDimensions(1)+obj.ViewPortOffset(1),:) = 64; % Right
            frame(obj.ViewPortDimensions(2)+obj.ViewPortOffset(2), 1+obj.ViewPortOffset(1):obj.ViewPortDimensions(1)+obj.ViewPortOffset(1),:) = 64; % Bottom
            frame(1+obj.ViewPortOffset(2), 1+obj.ViewPortOffset(1):obj.ViewPortDimensions(1)+obj.ViewPortOffset(1),:) = 64; % Top
        end

        function setSyncPatch(obj, state)
            % For calibration. State = 0 (black) or 1 (sync patch intensity)
            if ~(state == 0 || state == 1)
                error('setSyncPatch: state must be 0 or 1');
            end
            frame = ones(obj.WindowDimensions(4)-obj.WindowDimensions(2), obj.WindowDimensions(3)-obj.WindowDimensions(1))*128;
            frame(obj.SyncPatchDimensions(1):obj.SyncPatchDimensions(2),obj.SyncPatchDimensions(3):obj.SyncPatchDimensions(4),:) = 0;
            frame(obj.SyncPatchActiveDimensions(1):obj.SyncPatchActiveDimensions(2),obj.SyncPatchActiveDimensions(3):obj.SyncPatchActiveDimensions(4),:) =... 
                  state*obj.SyncPatchIntensity;
            texture = Screen('MakeTexture', obj.Window, frame);
            Screen('DrawTexture', obj.Window, texture);
            Screen('Flip', obj.Window);
        end

        function playNextFrame(obj, e)
            thisFrame = obj.CurrentFrame;
            Screen('DrawTexture', obj.Window, obj.Videos{obj.StimulusIndex}.Data(thisFrame));
            Screen('Flip', obj.Window);
            nextFrame = thisFrame+1;
            if nextFrame > obj.Videos{obj.StimulusIndex}.nFrames
                stop(obj.Timer);
                set(obj.Timer, 'TimerFcn', '');
            end
            obj.CurrentFrame = nextFrame;
        end

        function delete(obj)
            if ~isempty(obj.Timer)
                stop(obj.Timer);
                delete(obj.Timer);
                obj.Timer = [];
            end
            for i = 1:obj.MaxVideos
                if ~isempty(obj.Videos{i})
                    Screen('Close', obj.Videos{i}.Data);
                end
            end
            Screen('CloseAll');
        end
    end
end