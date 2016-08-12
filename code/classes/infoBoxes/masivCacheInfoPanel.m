classdef masivCacheInfoPanel<handle
    properties(SetAccess=protected)
        parent
        position
        gzvm    
        
        mainPanel
        axMeter
        foregroundBlockingPatch
        cacheStatusText
        
        updateListener
    end
    methods
        %% Constructor
        function obj=masivCacheInfoPanel(parent, position)
            obj.parent=parent;
            obj.position=position;
            obj.gzvm=parent.mainDisplay.zoomedViewManager;

            fSize=masivSetting('font.name');
            if fSize>1
                fSize=0.85;
            end
            
            obj.mainPanel=uipanel(...
                'Parent', parent.hFig, ...
                'Units', 'normalized', ...
                'Position', position, ...
                'BackgroundColor', masivSetting('viewer.panelBkgdColor'), ...
                'ButtonDownFcn', {@clickCallback, obj});
            
            mnuCache=uicontextmenu;
            uimenu(mnuCache, 'Label', 'Clear cache...', 'Callback', {@clearCacheCallback, obj})
            obj.mainPanel.UIContextMenu=mnuCache;
            
            obj.axMeter=axes(...
                'Parent', obj.mainPanel, ...
                'Position', [0.02 0.42 0.96 0.3], ...
                'Units', 'normalized', ...
                'Visible', 'on', ...
                'XTick', [], 'YTick', [], ...
                'Box', 'on', ...
                'XLim', [0 1], 'YLim', [0 1], ...
                'HitTest', 'off');
            uicontrol(...
                'Parent', obj.mainPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.02 0.8 0.96 0.17], ...
                'FontUnits','normalized', ...
                'FontSize',fSize, ...
                'FontName', masivSetting('font.name'), ...
                'FontWeight', 'bold', ...
                'String', 'Zoomed View Cache Usage:', ...
                'HorizontalAlignment', 'center', ...
                'BackgroundColor', masivSetting('viewer.panelBkgdColor'), ...
                'ForegroundColor', masivSetting('viewer.textMainColor'), ...
                'HitTest', 'off');
            
            drawBackgroundPatch(obj.axMeter);
            obj.foregroundBlockingPatch=rectangle(...
                'Parent', obj.axMeter, ...
                'Position', [0.2 0 0.8 1], ...
                'EdgeColor', 'none', ...
                'FaceColor', masivSetting('viewer.mainBkgdColor'), ...
                'HitTest', 'off');
            
            obj.cacheStatusText=uicontrol(...
                'Parent', obj.mainPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.02 0.1 0.96 0.15], ...
                'FontUnits','normalized', ...
                'FontSize',fSize, ...
                'FontName', masivSetting('font.name'), ...
                'HorizontalAlignment', 'center', ...
                'BackgroundColor', masivSetting('viewer.panelBkgdColor'), ...
                'ForegroundColor', masivSetting('viewer.textMainColor'), ...
                'HitTest', 'off');
            obj.updateCacheStatusDisplay();
            obj.updateListener=event.listener(parent, 'CacheChanged', @obj.updateCacheStatusDisplay);
        end
        %% Update
        function updateCacheStatusDisplay(obj, ~, ~)
            cacheLimit=masivSetting('cache.sizeLimitMiB');
            cacheUsed=obj.gzvm.cacheMemoryUsed;
            fracUsed=cacheUsed/cacheLimit;
            obj.cacheStatusText.String=sprintf('%u/%uMiB (%u%%) in use', round(cacheUsed), cacheLimit, round(fracUsed*100));
            obj.foregroundBlockingPatch.Position=[fracUsed, 0, max(0,1-fracUsed), 1];
        end
        %% Destructor
        function delete(obj)
            delete(obj.mainPanel)
        end
    end
end

function clearCacheCallback(~,~,obj)
    obj.parent.mainDisplay.zoomedViewManager.clearCache();
end

function drawBackgroundPatch(hAx)
    x=[0 0.5 1 1 0.5 0];
    y=[0 0  0   1   1   1];
    red=hsv2rgb([0 0.8 0.8]);
    green=hsv2rgb([0.4 0.8 0.8]);
    yellow=hsv2rgb([0.1 0.8 0.8]);
    c=[green;yellow;red;red;yellow;green];
    patch('Parent', hAx, 'Faces', [1 2 3 4 5 6], 'Vertices', [x; y]', 'EdgeColor', 'none',...
        'FaceVertexCData',c,'FaceColor', 'interp', 'HitTest', 'off');
end


function clickCallback(~, ~, obj)
    switch obj.parent.hFig.SelectionType
        case 'alt'
        case 'extend'
        otherwise
            changeCacheSize([], [], obj)
    end
end

function changeCacheSize(~,~, obj)
    persistent waitFlag
    if isempty(waitFlag)
        waitFlag=1; %#ok<NASGU>
        pause(0.2)
        waitFlag=[];
    else
        oldLim=masivSetting('cache.sizeLimitMiB');
        newLim=inputdlg('New Cache Size (MiB)', 'Change Cache Limit', 1, {num2str(oldLim)});
        if ~isempty(newLim)&&~isempty(str2double(newLim))&&~isnan(str2double(newLim))
            if checkCacheSizeOK(obj, str2double(newLim))
                masivSetting('cache.sizeLimitMiB', str2double(newLim))
                if str2double(newLim)<oldLim
                    obj.gzvm.cleanUpCache;
                end
            end
        end
        obj.updateCacheStatusDisplay();
    end
end

function flag=checkCacheSizeOK(obj, newLim)

    [freeMemKiB, totalMemKiB]=systemMemStats;
    freeMemMiB=freeMemKiB/1024;
    totalMemMiB=totalMemKiB/1024;
    usedMemMiB=totalMemMiB-freeMemMiB;

    
    totalNewMemoryUsageMiB=newLim+usedMemMiB-obj.gzvm.cacheMemoryUsed;
    
    if totalNewMemoryUsageMiB>totalMemMiB;
        response=questdlg(sprintf('Specified cache size (%uMiB)\nwould exceed available memory.\nAre you sure you want to do this?', round(newLim)), ...
            'Confirm memory change', 'Yes', 'No', 'No');
        if ~isempty(response)&&strcmp(response, 'Yes')
            flag=1;
        else
            flag=0;
        end
    else
        flag=1;
    end
end

