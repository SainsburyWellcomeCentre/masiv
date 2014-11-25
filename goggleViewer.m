classdef goggleViewer<handle
    properties(Access=protected)
        
        %% Preferences
        panelBkgdColor=[0.5 0.5 0.5];
        mainFigurePosition=[2561 196 1680 1003];
        
        panIncrement=[10 120]; % shift and non shift; fraction to move view by
        scrollIncrement=[10 1]; %shift and non shift; number of images to move view by
        zoomRate=1.5;
        mainFont='Titillium'; %'DejaVu Sans';
        keyboardUpdatePeriod=0.02; %20ms keyboard polling
        panModeInvert=0;
        
        %% Internal tracking
        numScrolls=0
        panxInt=0
        panyInt=0
    end
    properties
        %% Handles to visible objects
        hFig
        hImgAx
        hAxContrastHist
        hAxContrastMin
        hAxContrastMax
        hAxContrastAuto
        hInfoBox
        
        %% Data
        mosaicInfo
        overviewDSS
        mainDisplay
        
    end
    
   
    methods % Constructor
        function obj=goggleViewer(mosaicInfoIn, idx)
            obj=obj@handle;
            %% Get mosaic info if none provided
            if nargin<1 ||isempty(mosaicInfoIn)
                fp=uigetdir('/alzymr/buffer', 'Please select base directory of the stitched mosaic');
                if isempty(fp)
                    return
                end
                obj.mosaicInfo=TVStitchedMosaicInfo(fp);
            else
                obj.mosaicInfo=mosaicInfoIn;
            end
            
            %% Main UI object definitions
            obj.hFig=figure(...
                'Name', sprintf('GoggleBox: %s', obj.mosaicInfo.experimentName), ...
                'NumberTItle', 'off', ...
                'MenuBar', 'none', ...
                'Position', obj.mainFigurePosition, ...
                'Color', [0.2 0.2 0.2], ...
                'ColorMap', gray(256), ...
                'KeyPressFcn', {@hFigMain_KeyPress, obj}, ...
                'WindowButtonMotionFcn', {@mouseMove, obj}, ...
                'WindowScrollWheelFcn', {@hFigMain_ScrollWheel, obj}, ...
                'CloseRequestFcn', {@closeRequest, obj}, ...
                'BusyAction', 'cancel', 'Visible', 'off');
            obj.hImgAx=axes(...
                'Box', 'on', ...
                'YDir', 'reverse', ...
                'Color', [0 0 0], ...
                'XTick', [], 'YTick', [], ...
                'Position', [0.02 0.02 0.8 0.96]);
            
            %% Menu Object declarations
            mnuMain=uimenu(obj.hFig, 'Label', 'Main');
                    uimenu(mnuMain, 'Label', 'Quit', 'Callback', {@closeRequest, obj})
                    
            mnuImage=uimenu(obj.hFig, 'Label', 'Image');
                    uimenu(mnuImage, 'Label', 'Export Current View to Workspace', ...
                                     'Callback', {@exportViewToWorkspace, obj})
            
            mnuPlugins=uimenu(obj.hFig, 'Label', 'Plugins');
                    addPlugins(mnuPlugins, obj)
            
            %% Contrast adjustment object definitions
            obj.hAxContrastHist=axes(...
                'Box', 'on', ...
                'Color', obj.panelBkgdColor, ...
                'XTick', [], 'YTick', [], ...
                'Position', [0.83 0.87 0.16 0.11], ...
                'Color', [0.1 0.1 0.1]);
            obj.hAxContrastMin=uicontrol(...
                'Style', 'edit', ...
                'Parent', obj.hFig, ...
                'Units', 'normalized', ...
                'Position', [0.83 0.84 0.04 0.02], ...
                'BackgroundColor', [0.1 0.1 0.1], ...
                'ForegroundColor', [0.8 0.8 0.8], ...
                'String', '0', ...
                'FontSize', 12, ...
                'Callback', {@adjustContrast, obj});
            obj.hAxContrastMax=uicontrol(...
                'Style', 'edit', ...
                'Parent', obj.hFig, ...
                'Units', 'normalized', ...
                'Position', [0.875 0.84 0.04 0.02], ...
                'BackgroundColor', [0.1 0.1 0.1], ...
                'ForegroundColor', [0.8 0.8 0.8], ...
                'String', '5000', ...
                'FontSize', 12,...
                'Callback', {@adjustContrast, obj});
            obj.hAxContrastAuto=uicontrol(...
                'Style', 'pushbutton',...
                'Parent', obj.hFig, ...
                'Units', 'normalized', ...
                'Position', [0.92 0.84 0.04 0.02], ...
                'BackgroundColor', [0.1 0.1 0.1], ...
                'ForegroundColor', [0.8 0.8 0.8], ...
                'String', 'Auto', ...
                'FontSize', 12, ...
                'Callback', @(~,~) msgbox('Not Implemented (yet)'));
            
            %% Get DSS if not specified. Load up and display
            if nargin<2||isempty(idx)
                obj.overviewDSS=selectDownscaledStack(obj.mosaicInfo);
                if isempty(obj.overviewDSS)
                    close(obj.hFig)
                    return
                end
            else
                obj.overviewDSS=obj.mosaicInfo.downscaledStacks(idx);
            end
            startDebugOutput;
            obj.mainDisplay=goggleViewerDisplay(obj.overviewDSS, obj.hImgAx); %Default to the first available
            obj.mainDisplay.drawNewZ();
            adjustContrast([], [], obj);
            axis(obj.hImgAx, 'equal')
            
            %% Info box declaration
            obj.hInfoBox=goggleInfoPanel(obj.hFig, [0.83 0.5 0.16 0.31], obj.mainDisplay);
            
            %% Set fonts to something nice
            set(findall(gcf, '-property','FontName'), 'FontName', obj.mainFont)
            
            %% Start parallel pool
            gcp();
            
            %% Show the figure, we're done here!
            obj.hFig.Visible='on';
        end
        
    end
    
    methods(Access=protected)
        
        %% ---Scrolling
        function formatKeyScrollAndAddToQueue(obj, eventdata)
            goggleDebugTimingInfo(0, 'GV: KeyScroll event fired',toc, 's')
            mods=eventdata.Modifier;
            if ~isempty(mods)&& any(~cellfun(@isempty, strfind(mods, 'shift')))
                p=obj.scrollIncrement(1);
            else
                p=obj.scrollIncrement(2);
            end
            switch eventdata.Key
                case 'leftarrow'
                    obj.keyScrollQueue(-p)
                case 'rightarrow'
                    obj.keyScrollQueue(+p);
            end
        end
        
        function keyScrollQueue(obj, dir)
            
            obj.numScrolls=obj.numScrolls+dir;
            
            pause(obj.keyboardUpdatePeriod)
            if obj.numScrolls~=0
                p=obj.numScrolls;
                obj.numScrolls=0;
                obj.executeScroll(p)
            end
        end
        
        function executeScroll(obj, p)
            stdout=obj.mainDisplay.seekZ(p);
            if stdout
                obj.changeAxes;
            else
                goggleDebugTimingInfo(0, 'GV: Scroll did not cause an axis change',toc, 's')
            end
        end
        
        %% ---Panning
        function formatKeyPanAndAddToQueue(obj, eventdata)
            goggleDebugTimingInfo(0, 'GV: KeyPan event fired',toc, 's')
            mods=eventdata.Modifier;
            if ~isempty(mods)&& any(~cellfun(@isempty, strfind(mods, 'shift')))
                p=obj.panIncrement(1);
            else
                p=obj.panIncrement(2);
            end
            switch eventdata.Key
                case 'w'
                    obj.keyPanQueue(0, +range(ylim(obj.hImgAx))/p)
                case 'a'
                    obj.keyPanQueue(+range(xlim(obj.hImgAx))/p, 0)
                case 's'
                    obj.keyPanQueue(0, -range(ylim(obj.hImgAx))/p)
                case 'd'
                    obj.keyPanQueue(-range(xlim(obj.hImgAx))/p, 0)
            end
        end
        
        function keyPanQueue(obj, xChange, yChange)
           
            obj.panxInt=obj.panxInt+xChange;
            obj.panyInt=obj.panyInt+yChange;
            pause(obj.keyboardUpdatePeriod)
            
            if obj.panxInt~=0 || obj.panyInt~=0
                xOut=obj.panxInt;
                yOut=obj.panyInt;
                obj.panxInt=0;
                obj.panyInt=0;
                obj.executePan(xOut,yOut)
            end
        end
        
        function executePan(obj, xMove,yMove)
            if obj.panModeInvert
                xMove=-xMove;
                yMove=-yMove;
            end
            
            [xMove, yMove]=obj.checkPanWithinLimits(xMove, yMove);
            movedFlag=0;
            
            if xMove~=0
                xlim(obj.hImgAx,xlim(obj.hImgAx)+xMove);
                movedFlag=1;
            end
            if yMove~=0
                ylim(obj.hImgAx,ylim(obj.hImgAx)+yMove);
                movedFlag=1;
            end
            
            if movedFlag
                obj.changeAxes;
            else
                goggleDebugTimingInfo(0, 'GV: Pan did not cause an axis change',toc, 's')
            end
        end
        
        function [xMove,yMove]=checkPanWithinLimits(obj, xMove,yMove)
            xl=xlim(obj.hImgAx);
            yl=ylim(obj.hImgAx);
            
            if xl(1) + xMove < 0
                xMove = -xl(1);
            end
            if yl(1) + yMove < 0
                yMove = -yl(1);
            end
            if xl(2) + xMove > obj.mainDisplay.imageXLimOriginalCoords(2)
                xMove=obj.mainDisplay.imageXLimOriginalCoords(2) - xl(2);
            end
            if yl(2) + yMove > obj.mainDisplay.imageYLimOriginalCoords(2)
                yMove=obj.mainDisplay.imageYLimOriginalCoords(2) - yl(2);
            end
        end
        
        %% ---Update axes
        function changeAxes(obj)
            goggleDebugTimingInfo(0, 'GV: Axis Change Complete',toc, 's')
            goggleDebugTimingInfo(0, 'GV: Calling mainDisplay updateZoomedView...',toc, 's')
            obj.mainDisplay.updateZoomedView
            goggleDebugTimingInfo(0, 'GV: mainDisplay updateZoomedView complete',toc, 's')
            obj.hInfoBox.updateDisplay
        end
        
        
    end
end

function startDebugOutput
tic
clc
end    

%% Callbacks
function hFigMain_KeyPress (~, eventdata, obj)

    startDebugOutput

    movedFlag=0;
    %% What shall we do?
    switch eventdata.Key
        case 'shift'
            % Do nothing
        case 'uparrow'
            zoom(obj.zoomRate)
            movedFlag=1;
        case 'downarrow'
            zoom(1/obj.zoomRate)
            movedFlag=1;
        case {'leftarrow', 'rightarrow'}
            obj.formatKeyScrollAndAddToQueue(eventdata);
        case {'w' 'a' 's' 'd'}
            obj.formatKeyPanAndAddToQueue(eventdata);
        case 'c'
            updateContrastHistogram(obj.mainDisplay, obj.hAxContrastHist)
        otherwise
            goggleDebugTimingInfo(0, sprintf('GV.unknownKeypress: %s', eventdata.Key))
    end
    if movedFlag
        obj.changeAxes
    else
        goggleDebugTimingInfo(0, 'GV: No Axis Change',toc, 's')
    end
end
function mouseMove (~, ~, obj)
    C = get (obj.hImgAx, 'CurrentPoint');
    obj.hInfoBox.currentCursorPosition=C;
end
function hFigMain_ScrollWheel(~, eventdata, obj)
    startDebugOutput

    goggleDebugTimingInfo(0, 'GV: WheelScroll event fired',toc, 's')
    p=obj.scrollIncrement(2);

    obj.executeScroll(p*eventdata.VerticalScrollCount);

end
function adjustContrast(hContrastLim, ~, obj)
    if nargin<1
        hContrastLim=[];
    end
    if ~isempty(hContrastLim)&&~all(isstrprop(hContrastLim.String, 'digit')) %it's invalid, use the previous value
        if hContrastLim==obj.hAxContrastMin
            hContrastLim.String=obj.mainDisplay.contrastLims(1);
        elseif hContrastLim==obj.hAxContrastMax
            hContrastLim.String=obj.mainDisplay.contrastLims(2);
        end
    else
        obj.mainDisplay.contrastLims=[str2double(obj.hAxContrastMin.String) str2double(obj.hAxContrastMax.String)];
    end
end
function closeRequest(~,~,obj)
delete(timerfind); 
delete(obj.hFig); 
delete(obj)
end

%% Utilities
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

function exportViewToWorkspace(~,~,obj)
    if obj.mainDisplay.zoomedViewManager.imageVisible;
        I=obj.mainDisplay.zoomedViewManager.currentImageViewData;
    else
        I=obj.mainDisplay.currentImageViewData;
    end
    xView=round(obj.hImgAx.XLim);xView(xView<1)=1;
    yView=round(obj.hImgAx.YLim);yView(yView<1)=1;
    proposedImageName=sprintf('%s_%s_x%u_%u_y%u_%u_layer%04u',...
        obj.overviewDSS.experimentName, ...
        obj.overviewDSS.channel, ...
        xView(1), xView(2), ...
        yView(1), yView(2), ...
        obj.mainDisplay.currentZPlaneOriginalLayerID);
    assignin('base', proposedImageName, I);
end

%% Plugins menu creation
function addPlugins(hMenuBase, obj)
    pluginsDir=fullfile(fileparts(which('goggleViewer')), 'plugins');
    
    if ~exist(pluginsDir, 'dir')
        error('plugins directory not found')
    end
    
    pluginsFound=dir(fullfile(pluginsDir, '*.m'));
    
    for ii=1:numel(pluginsFound)
        if ~isAbstractPlugin(pluginsDir, pluginsFound(ii).name)
            
            [pluginDisplayString, pluginStartCallback]=getPluginInfo(pluginsFound(ii));
                       
            uimenu(hMenuBase, 'Label', pluginDisplayString, 'Callback', pluginStartCallback, 'UserData', obj)
            
        end
    end
end


function abstractPluginFlag=isAbstractPlugin(pluginsDir, pluginsFile)
f=fopen(fullfile(pluginsDir, pluginsFile));
codeStr=fread(f, Inf, '*char')';
abstractPluginFlag=strfind(lower(codeStr), 'abstract');
if isempty(abstractPluginFlag)
    abstractPluginFlag=0;
else
    abstractPluginFlag=1;
end
fclose(f);
end

function [pluginDisplayString, pluginStartCallback]=getPluginInfo(pluginFile)
pluginDisplayString=eval(strrep(pluginFile.name, '.m', '.displayString;'));
pluginStartCallback={eval(['@', strrep(pluginFile.name, '.m', '')])};
end




















