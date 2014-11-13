function goggleViewer(t, idx)
%% Preferences
panelBkgdColor=[0.5 0.5 0.5];
mainFigurePosition=[2561 196 1680 1028];

panIncrement=[10 120]; % shift and non shift; fraction to move view by
scrollIncrement=[10 1]; %shift and non shift; number of images to move view by
zoomRate=1.5;
mainFont='Titillium'; %'DejaVu Sans';
keyboardUpdatePeriod=0.02; %20ms keyboard polling
panModeInvert=0;

%% Get mosaic info if none provided
if nargin<1 ||isempty(t)
    fp=uigetdir('/alzymr/buffer', 'Please select base directory of the stitched mosaic');
    if isempty(fp)
        return
    end
    t=TVStitchedMosaicInfo(fp);
end

%% Main UI object definitions
hFig=figure(...
    'Name', sprintf('GoggleBox: %s', t.experimentName), ...
    'NumberTItle', 'off', ...
    'MenuBar', 'none', ...
    'Position', mainFigurePosition, ...
    'Color', [0.2 0.2 0.2], ...
    'ColorMap', gray(256), ...
    'KeyPressFcn', @hFigMain_KeyPress, ...
    'WindowButtonMotionFcn', @mouseMove, ...
    'WindowScrollWheelFcn', @hFigMain_ScrollWheel, ...
    'CloseRequestFcn', 'delete(timerfind); delete(gcf)', ...
    'BusyAction', 'cancel');
hImgAx=axes(...
    'Box', 'on', ...
    'YDir', 'reverse', ...
    'Color', [0 0 0], ...
    'XTick', [], 'YTick', [], ...
    'Position', [0.02 0.02 0.8 0.96]);

%% Contrast adjustment object definitions
hAxContrastHist=axes(...
    'Box', 'on', ...
    'Color', panelBkgdColor, ...
    'XTick', [], 'YTick', [], ...
    'Position', [0.83 0.87 0.16 0.11], ...
    'Color', [0.1 0.1 0.1]);
hAxContrastMin=uicontrol(...
    'Style', 'edit', ...
    'Parent', hFig, ...
    'Units', 'normalized', ...
    'Position', [0.83 0.84 0.04 0.02], ...
    'BackgroundColor', [0.1 0.1 0.1], ...
    'ForegroundColor', [0.8 0.8 0.8], ...
    'String', '0', ...
    'FontSize', 12, ...
    'Callback', @adjustContrast);
hAxContrastMax=uicontrol(...
    'Style', 'edit', ...
    'Parent', hFig, ...
    'Units', 'normalized', ...
    'Position', [0.875 0.84 0.04 0.02], ...
    'BackgroundColor', [0.1 0.1 0.1], ...
    'ForegroundColor', [0.8 0.8 0.8], ...
    'String', '5000', ...
    'FontSize', 12,...
    'Callback', @adjustContrast);
hAxContrastAuto=uicontrol(...
    'Style', 'pushbutton',...
    'Parent', hFig, ...
    'Units', 'normalized', ...
    'Position', [0.92 0.84 0.04 0.02], ...
    'BackgroundColor', [0.1 0.1 0.1], ...
    'ForegroundColor', [0.8 0.8 0.8], ...
    'String', 'Auto', ...
    'FontSize', 12, ...
    'Callback', @(~,~) msgbox('Not Implemented (yet)')); %#ok<NASGU>

%% Load up and display
if nargin<2||isempty(idx)
overviewDSS=selectDownscaledStack(t.downscaledStacks);
if isempty(overviewDSS)
    close(hFig)
    return
end
else
    overviewDSS=t.downscaledStacks(idx);
end
startDebugOutput;
mainDisplay=goggleViewerDisplay(overviewDSS, hImgAx); %Default to the first available
mainDisplay.drawNewZ();
adjustContrast();
axis(hImgAx, 'equal')

%% Info box declaration
hInfoBox=goggleInfoPanel(hFig, [0.83 0.5 0.16 0.31], mainDisplay);

%% Set fonts to something nice
set(findall(gcf, '-property','FontName'), 'FontName', mainFont)

%% Start parallel pool
drawnow();
gcp();

%% Callbacks
    function hFigMain_KeyPress (~, eventdata, ~)
        startDebugOutput
        %% Are we in pan mode?
        persistent panMode
        if isempty(panMode)
            panMode=0;
        end
        %%
        movedFlag=0;
        %% What shall we do?
        switch eventdata.Key
            case 'shift'
                % Do nothing
            case 'uparrow'
                zoom(zoomRate)
                movedFlag=1;
            case 'downarrow'
                zoom(1/zoomRate)
                movedFlag=1;
            case {'leftarrow', 'rightarrow'}
                formatKeyScrollAndAddToQueue(eventdata);
            case {'w' 'a' 's' 'd'}
                formatKeyPanAndAddToQueue(eventdata);                
            case 'c'
                updateContrastHistogram(mainDisplay, hAxContrastHist)
            otherwise
                goggleDebugTimingInfo(0, sprintf('GV.unknownKeypress: %s', eventdata.Key))
        end
        if movedFlag
            changeAxes
        else
            goggleDebugTimingInfo(0, 'GV: No Axis Change',toc, 's')
        end
    end

    function hFigMain_ScrollWheel(~, eventdata)
        startDebugOutput
       
        goggleDebugTimingInfo(0, 'GV: WheelScroll event fired',toc, 's')
        p=scrollIncrement(2);
        
        executeScroll(p*eventdata.VerticalScrollCount);
        
    end

    function mouseMove (~, ~)
        C = get (hImgAx, 'CurrentPoint');
        hInfoBox.currentCursorPosition=C;
    end

%% ---Scrolling 
    function formatKeyScrollAndAddToQueue(eventdata)
        goggleDebugTimingInfo(0, 'GV: KeyScroll event fired',toc, 's')
        mods=eventdata.Modifier;
        if ~isempty(mods)&& any(~cellfun(@isempty, strfind(mods, 'shift')))
            p=scrollIncrement(1);
        else
            p=scrollIncrement(2);
        end
        switch eventdata.Key
            case 'leftarrow'
                keyScrollQueue(-p)
            case 'rightarrow'
                keyScrollQueue(+p);
        end
    end

    function keyScrollQueue(dir)
        persistent numPresses
        if isempty(numPresses)
            numPresses=0;
        end
        
        numPresses=numPresses+dir;
        
        pause(keyboardUpdatePeriod)
        if numPresses~=0
            p=numPresses;
            numPresses=0;
            executeScroll(p)
        end
    end

    function executeScroll(p)
        stdout=mainDisplay.seekZ(p);
        if stdout
            changeAxes
        end
    end

%% ---Panning
    function formatKeyPanAndAddToQueue(eventdata)
        goggleDebugTimingInfo(0, 'GV: KeyPan event fired',toc, 's')
        mods=eventdata.Modifier;
        if ~isempty(mods)&& any(~cellfun(@isempty, strfind(mods, 'shift')))
            p=panIncrement(1);
        else
            p=panIncrement(2);
        end
        switch eventdata.Key
            case 'w'
                keyPanQueue(0, +range(ylim(hImgAx))/p)
            case 'a'
                keyPanQueue(+range(xlim(hImgAx))/p, 0)
            case 's'
                keyPanQueue(0, -range(ylim(hImgAx))/p)
            case 'd'
                keyPanQueue(-range(xlim(hImgAx))/p, 0)
        end
    end

    function keyPanQueue(xChange, yChange)
        persistent xInt yInt
        if isempty(xInt)
            xInt=0;
        end
        if isempty(yInt)
            yInt=0;
        end
        
        xInt=xInt+xChange;
        yInt=yInt+yChange;
        pause(keyboardUpdatePeriod)
        
        if xInt~=0 || yInt~=0
            xOut=xInt;
            yOut=yInt;
            xInt=0;
            yInt=0;
            executePan(xOut,yOut)
        end
    end

    function executePan(xMove,yMove)
        if panModeInvert
            xMove=-xMove;
            yMove=-yMove;
        end
        
        [xMove, yMove]=checkPanWithinLimits(xMove, yMove);
        
        if xMove~=0
            xlim(hImgAx,xlim(hImgAx)+xMove);
        end
        if yMove~=0
            ylim(hImgAx,ylim(hImgAx)+yMove);
        end
        changeAxes
    end

    function [xMove,yMove]=checkPanWithinLimits(xMove,yMove)
        xl=xlim(hImgAx);
        yl=ylim(hImgAx);
        
        if xl(1) + xMove < 0
            xMove = -xl(1);
        end
        if yl(1) + yMove < 0
            yMove = -yl(1);
        end
        if xl(2) + xMove > mainDisplay.imageXLim(2)
            xMove=mainDisplay.imageXLim(2) - xl(2);
        end
        if yl(2) + yMove > mainDisplay.imageYLim(2)
            yMove=mainDisplay.imageYLim(2) - yl(2);
        end
    end
    
%% ---Update axes
    function changeAxes()
        goggleDebugTimingInfo(0, 'GV: Axis Change Complete',toc, 's')
        goggleDebugTimingInfo(0, 'GV: Calling mainDisplay updateZoomedView...',toc, 's')
        mainDisplay.updateZoomedView
        goggleDebugTimingInfo(0, 'GV: mainDisplay updateZoomedView complete',toc, 's')
        hInfoBox.updateDisplay
    end
    
%% ---Contrast Adjustment
    function adjustContrast(obj,~)
        if nargin<1
            obj=[];
        end
        if ~isempty(obj)&&~all(isstrprop(obj.String, 'digit')) %it's invalid, use the previous value
            if obj==hAxContrastMin
                obj.String=mainDisplay.contrastLims(1);
            elseif obj==hAxContrastMax
                obj.String=mainDisplay.contrastLims(2);
            end
        else
            mainDisplay.contrastLims=[str2double(hAxContrastMin.String) str2double(hAxContrastMax.String)];
        end
    end

end


function updateContrastHistogram(dsStack,hContrastHist_Axes)
data=dsStack.hImg.CData;
n=hist(double(data(:)), numel(data)/100);n=n/max(n);
bar(linspace(0, 1, length(n)), n, 'Parent', hContrastHist_Axes, 'FaceColor', [0.8 0.8 0.8])
hContrastHist_Axes.Color=[0.1 0.1 0.1];
hold(hContrastHist_Axes, 'on')

% Overlay fake axes
line([0 0], [-0.08 1.1], 'Color', [0.8 0.8 0.8],'Parent', hContrastHist_Axes) %y axis
line([-0.05 0.01], [1 1],  'Color', [0.8 0.8 0.8],'Parent', hContrastHist_Axes) %top y axis tick
line([1 1], [-0.08 0.001], 'Color', [0.8 0.8 0.8],'Parent', hContrastHist_Axes) %end x tick
%        rectangles cover any funny error pixels
rectangle('Position', [-0.08 1 2 1], 'FaceColor',[0.1 0.1 0.1], 'EdgeColor', 'none','Parent', hContrastHist_Axes)
rectangle('Position', [-1.001 -1.001 1 1], 'FaceColor', [0.1 0.1 0.1], 'EdgeColor', 'none','Parent', hContrastHist_Axes)
rectangle('Position', [1.01 -1.001 1 1], 'FaceColor', [0.1 0.1 0.1],'EdgeColor', 'none','Parent', hContrastHist_Axes)

% Ovelay limit lines
%        line(ones(2, 1)*contrastMin, [-0.05 1], 'Parent', hContrastHist_Axes)
%        line(ones(2, 1)*contrastMax, [-0.05 1], 'Parent', hContrastHist_Axes)
hold(hContrastHist_Axes, 'off')
set(hContrastHist_Axes, 'XTick', [], 'XColor', get(0, 'defaultuicontrolbackgroundcolor'))
set(hContrastHist_Axes, 'YTick', [], 'YColor', get(0, 'defaultuicontrolbackgroundcolor'))
xlim(hContrastHist_Axes, [-0.05 1.1])
ylim(hContrastHist_Axes, [-0.1 1.1])
end

function startDebugOutput
tic
clc
end

