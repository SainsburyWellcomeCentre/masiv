function goggleViewer(t)
%% Preferences
panelBkgdColor=[0.5 0.5 0.5];
mainFigurePosition=[2561 196 1680 1028];

panIncrement=[10 120]; % shift and non shift; fraction to move view by
scrollIncrement=[10 1]; %shift and non shift; number of images to move view by
zoomRate=1.5;
%% Main object definitions
hFig=figure(...
    'Name', sprintf('GoggleBox: %s', t.experimentName), ...
    'NumberTItle', 'off', ...
    'MenuBar', 'none', ...
    'Position', mainFigurePosition, ...
    'ColorMap', gray(256), ...
    'KeyPressFcn', @hFigMain_KeyPress, ...
    'BusyAction', 'cancel'); %#ok<NASGU>
hImgAx=axes(...
    'Box', 'on', ...
    'YDir', 'reverse', ...
    'Color', [0 0 0], ...
    'XTick', [], 'YTick', [], ...
    'Position', [0.02 0.02 0.8 0.96]);
%% UI object definitions
hAxContrastHist=axes(...
    'Box', 'on', ...
    'Color', panelBkgdColor, ...
    'XTick', [], 'YTick', [], ...
    'Position', [0.83 0.87 0.16 0.11]);
%% Background variables

%% Run
dsStack=goggleViewerDisplay(t.downscaledStacks(1), hImgAx); %Default to the first available
dsStack.contrastLims=[0 2000];
dsStack.drawNow();
axis(hImgAx, 'equal')


%% Callbacks
    function hFigMain_KeyPress (~, eventdata, ~)
        %% Are we in pan mode?
        persistent panMode
        if isempty(panMode)
            panMode=0;
        end
        %% Have we moved?
        movedFlag=0;
        %% What shall we do?
        switch eventdata.Key
            case 'shift'
         
            case 'uparrow'
                zoom(zoomRate)
                movedFlag=1;
            case 'downarrow'
                zoom(1/zoomRate)
                movedFlag=1;
            case {'leftarrow', 'rightarrow'}
                movedFlag=keyScroll(eventdata);
            case {'w' 'a' 's' 'd'}
                keyPan(eventdata)
                movedFlag=1;
            case 'p'
                %% Not currently allowed
%                 if panMode
%                     pan off
%                     panMode=panMode-1;
%                 else
%                     pan on
%                     % Override the annoying lack of ability to control keypress
%                     hManager = uigetmodemanager(gcf);
%                     hManager.currentMode.WindowKeyPressFcn=@hFigMain_KeyPress;
%                     panMode=2; % The keypress function will be called TWICE, the first from the uimodemanager. So we want to 'turn it off' twice
%                 end
           
            case 'c'
                updateContrastHistogram(dsStack, hAxContrastHist)
            otherwise
                disp(eventdata.Key)
        end
        if movedFlag
            dsStack.createZoomedView
        end
    end
    function keyPan(eventdata)
        mods=eventdata.Modifier;
        if ~isempty(mods)&& any(~cellfun(@isempty, strfind(mods, 'shift')))
            p=panIncrement(1);
        else
            p=panIncrement(2);
        end
        switch eventdata.Key
            case 'w'
                ylim(hImgAx,ylim(hImgAx)+range(ylim(hImgAx))/p);
            case 's'
                ylim(hImgAx,ylim(hImgAx)-range(ylim(hImgAx))/p);
            case 'a'
                xlim(hImgAx,xlim(hImgAx)+range(xlim(hImgAx))/p);
            case 'd'
                xlim(hImgAx,xlim(hImgAx)-range(xlim(hImgAx))/p);
        end
    end
    function stdout=keyScroll(eventdata)
        mods=eventdata.Modifier;
        if ~isempty(mods)&& any(~cellfun(@isempty, strfind(mods, 'shift')))
            p=scrollIncrement(1);
        else
            p=scrollIncrement(2);
        end
        switch eventdata.Key
            case 'leftarrow'
                stdout=dsStack.seekZ(-p);
            case 'rightarrow'
                stdout=dsStack.seekZ(+p);
        end
    end



   
end


function updateContrastHistogram(dsStack,hContrastHist_Axes)
data=dsStack.hImg.CData;
n=hist(double(data(:)), numel(data)/100);n=n/max(n);
bar(linspace(0, 1, length(n)), n, 'Parent', hContrastHist_Axes)
hold(hContrastHist_Axes, 'on')

% Overlay fake axes
line([0 0], [-0.08 1.1], 'Color', [0.1, 0.1, 0.1],'Parent', hContrastHist_Axes) %y axis
line([-0.05 0.01], [1 1],  'Color', [0.1 0.1 0.1],'Parent', hContrastHist_Axes) %top y axis tick
line([1 1], [-0.08 0.001], 'Color', [0.1, 0.1, 0.1],'Parent', hContrastHist_Axes) %end x tick
%        rectangles cover any funny error pixels
rectangle('Position', [-0.08 1 2 1], 'FaceColor', [1 1 1], 'EdgeColor', 'none','Parent', hContrastHist_Axes)
rectangle('Position', [-1.001 -1.001 1 1], 'FaceColor', [1 1 1], 'EdgeColor', 'none','Parent', hContrastHist_Axes)
rectangle('Position', [1.01 -1.001 1 1], 'FaceColor', [1 1 1],'EdgeColor', 'none','Parent', hContrastHist_Axes)

% Ovelay limit lines
%        line(ones(2, 1)*contrastMin, [-0.05 1], 'Parent', hContrastHist_Axes)
%        line(ones(2, 1)*contrastMax, [-0.05 1], 'Parent', hContrastHist_Axes)
hold(hContrastHist_Axes, 'off')
set(hContrastHist_Axes, 'XTick', [], 'XColor', get(0, 'defaultuicontrolbackgroundcolor'))
set(hContrastHist_Axes, 'YTick', [], 'YColor', get(0, 'defaultuicontrolbackgroundcolor'))
xlim(hContrastHist_Axes, [-0.05 1.1])
ylim(hContrastHist_Axes, [-0.1 1.1])

end

