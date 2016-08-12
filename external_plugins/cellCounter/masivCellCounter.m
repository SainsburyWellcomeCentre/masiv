classdef masivCellCounter<masivPlugin
    properties
        hFig
        
        cursorListenerInsideAxes
        cursorListenerOutsideAxes
        cursorListenerClick
        keyPressListener
        
        hMarkerButtonGroup
        hMarkerTypeSelection
        hMarkerTypeChangeNameButtons
        hColorIndicatorPanel
        hCountIndicatorAx
        hCountIndicatorText
        
        hModeButtonGroup
        hModeAdd
        hModeDelete
        hSuspendDrawing
        
        cursorX
        cursorY
        
        markerTypes
        markers
        hDisplayedMarkers
        hDisplayedMarkerHighlights
        
        fontName
        fontSize
        
        scrolledListener
        zoomedListener
        pannedListener
        gvClosingListener
        
        changeFlag=0
        
    end
    
    properties(Dependent, SetAccess=protected)
        currentType
        cursorZVoxels
        cursorZUnits
        
        correctionOffset
        deCorrectedCursorX
        deCorrectedCursorY
    end
    
    methods
        %% Constructor
        function obj=masivCellCounter(caller, ~)
            obj=obj@masivPlugin(caller);


            %Add the helper functions to the path. If already there, a duplicate is not created
            pathToPlugin=fullfile(which('masivCellCounter'));
            addpath(fullfile(fileparts(pathToPlugin),'masivMarkers'))


            %% Settings
            obj.fontName=masivSetting('font.name');
            obj.fontSize=masivSetting('font.size');
            try
                pos=masivSetting('cellCounter.figurePosition');
            catch
                ssz=get(0, 'ScreenSize');
                lb=[ssz(3)/3 ssz(4)/3];
                pos=round([lb 400 550]);
                masivSetting('cellCounter.figurePosition', pos)
                masivSetting('cellCounter.markerDiameter.xy', 20);
                masivSetting('cellCounter.markerDiameter.z', 30);
                masivSetting('cellCounter.minimumSize', 20)
                masivSetting('cellCounter.maximumDistanceVoxelsForDeletion', 500)
            end
            masivSetting('cellCounter.importExportDefault', masivSetting('defaultDirectory'))

            %% Main UI initialisation
            obj.hFig=figure(...
                'Position', pos, ...
                'CloseRequestFcn', {@deleteRequest, obj}, ...
                'MenuBar', 'none', ...
                'NumberTitle', 'off', ...
                'Name', ['Cell Counter: ' obj.MaSIV.Meta.stackName], ...
                'Color', masivSetting('viewer.panelBkgdColor'), ...
                'KeyPressFcn', {@keyPress, obj});
            
            %% Marker selection initialisation
            obj.hMarkerButtonGroup=uibuttongroup(...
                'Parent', obj.hFig, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.02 0.6 0.96], ...
                'BackgroundColor', masivSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', masivSetting('viewer.textMainColor'), ...
                'Title', 'Marker Type', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize);
            obj.markerTypes=defaultMarkerTypes(10);
            updateMarkerTypeUISelections(obj);
            
            %% Mode selection initialisation
            obj.hModeButtonGroup=uibuttongroup(...
                'Parent', obj.hFig, ...
                'Units', 'normalized', ...
                'Position', [0.64 0.86 0.34 0.12], ...
                'BackgroundColor', masivSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', masivSetting('viewer.textMainColor'), ...
                'Title', 'Placement Mode', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize);
            obj.hModeAdd=uicontrol(...
                'Parent', obj.hModeButtonGroup, ...
                'Style', 'radiobutton', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.51 0.96 0.47], ...
                'String', 'Add (ctrl+a)', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'Value', 1, ...
                'BackgroundColor', masivSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', masivSetting('viewer.textMainColor'));
            obj.hModeDelete=uicontrol(...
                'Parent', obj.hModeButtonGroup, ...
                'Style', 'radiobutton', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.02 0.96 0.47], ...
                'String', 'Delete (ctrl+d)', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'Value', 0, ...
                'BackgroundColor', masivSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', masivSetting('viewer.textMainColor'));
            
            %% Settings panel
            hSettingPanel=uipanel(...
                'Parent', obj.hFig, ...
                'Units', 'normalized', ...
                'Position', [0.64 0.17 0.34 0.67], ...
                'BackgroundColor', masivSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', masivSetting('viewer.textMainColor'), ...
                'Title', 'Display Settings', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize);
            setUpSettingBox('XY Size', 'cellCounter.markerDiameter.xy', 0.8, hSettingPanel, obj)
            setUpSettingBox('Z Size', 'cellCounter.markerDiameter.z', 0.7, hSettingPanel, obj)
            setUpSettingBox('Min. Size', 'cellCounter.minimumSize', 0.6, hSettingPanel, obj)
            setUpSettingBox('Delete Prox.', 'cellCounter.maximumDistanceVoxelsForDeletion', 0.48, hSettingPanel, obj)
            
            obj.hSuspendDrawing=uicontrol(...
                'Parent', hSettingPanel, ...
                'Style', 'checkbox', ...
                'Units', 'Normalized', ...
                'Position', [0.05 0.38 0.9 0.08], ...
                'BackgroundColor', masivSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', masivSetting('viewer.textMainColor'), ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize - 1, ...
                'String', 'Hide (h)', ...
                'Callback', @(h,e) obj.drawMarkers(h,e));

            %% Import / Export data
           
            uicontrol(...
                'Parent', obj.hFig, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [0.64 0.09 0.34 0.06], ...
                'String', 'Import...', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'Value', 1, ...
                'BackgroundColor', masivSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', masivSetting('viewer.textMainColor'), ...
                'Callback', {@importData, obj});
            uicontrol(...
                'Parent', obj.hFig, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [0.64 0.02 0.34 0.06], ...
                'String', 'Export...', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'Value', 0, ...
                'BackgroundColor', masivSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', masivSetting('viewer.textMainColor'), ...
                'Callback', {@exportData, obj});
            
            %% Listener Declarations
            obj.cursorListenerInsideAxes=event.listener(obj.MaSIV, 'CursorPositionChangedWithinImageAxes', @obj.updateCursorWithinAxes);
            obj.cursorListenerOutsideAxes=event.listener(obj.MaSIV, 'CursorPositionChangedOutsideImageAxes', @obj.updateCursorOutsideAxes);
            obj.cursorListenerClick=event.listener(obj.MaSIV, 'ViewClicked', @obj.mouseClickInMainWindowAxes);
            obj.scrolledListener=event.listener(obj.MaSIV, 'Scrolled', @obj.drawMarkers);
            obj.zoomedListener=event.listener(obj.MaSIV, 'Zoomed', @obj.drawMarkers);
            obj.pannedListener=event.listener(obj.MaSIV, 'Panned', @obj.drawMarkers);
            obj.keyPressListener=event.listener(obj.MaSIV, 'KeyPress', @obj.parentKeyPress);
            obj.gvClosingListener=event.listener(obj.MaSIV, 'ViewerClosing', @obj.parentClosing);
            
        
        end
        
        %% Set up markers
        function updateMarkerTypeUISelections(obj)
            %% Clear controls, if appropriate
            if ~isempty(obj.hMarkerTypeSelection)
                prevSelection=find(obj.hMarkerTypeSelection==obj.hMarkerButtonGroup.SelectedObject);
                delete(obj.hMarkerTypeSelection)
                delete(obj.hMarkerTypeChangeNameButtons)
                delete(obj.hCountIndicatorAx)
            else
                prevSelection=1;
            end
            
            %% Set up radio buttons
            ii=1;
            
            obj.hMarkerTypeSelection=uicontrol(...
                'Parent', obj.hMarkerButtonGroup, ...
                'Style', 'radiobutton', ...
                'Units', 'normalized', ...
                'Position', [0.18 0.98-(0.08*ii) 0.45 0.08], ...
                'String', obj.markerTypes(ii).name, ...
                'UserData', ii, ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'BackgroundColor', masivSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', masivSetting('viewer.textMainColor'));
            setNameChangeContextMenu(obj.hMarkerTypeSelection, obj)
            
            for ii=2:numel(obj.markerTypes)
                obj.hMarkerTypeSelection(ii)=uicontrol(...
                    'Parent', obj.hMarkerButtonGroup, ...
                    'Style', 'radiobutton', ...
                    'Units', 'normalized', ...
                    'Position', [0.18 0.98-(0.08*ii) 0.45 0.08], ...
                    'String', obj.markerTypes(ii).name, ...
                    'UserData', ii, ...
                    'FontName', obj.fontName, ...
                    'FontSize', obj.fontSize, ...
                    'BackgroundColor', masivSetting('viewer.mainBkgdColor'), ...
                    'ForegroundColor', masivSetting('viewer.textMainColor'));
                setNameChangeContextMenu(obj.hMarkerTypeSelection(ii), obj)
                
            end
            obj.hMarkerTypeSelection(1).Value=1;
            
            %% Set up color indicator
            ii=1;
            obj.hColorIndicatorPanel=uipanel(...
                'Parent', obj.hMarkerButtonGroup, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.98-(0.08*ii)+0.01 0.12 0.06], ...
                'UserData', ii, ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize-1, ...
                'BackgroundColor', obj.markerTypes(ii).color);
            setColorChangeContextMenu(obj.hColorIndicatorPanel, obj);
            for ii=2:numel(obj.markerTypes)
                obj.hColorIndicatorPanel(ii)=uipanel(...
                    'Parent', obj.hMarkerButtonGroup, ...
                    'Units', 'normalized', ...
                    'Position', [0.02 0.98-(0.08*ii)+0.01 0.12 0.06], ...
                    'UserData', ii, ...
                    'FontName', obj.fontName, ...
                    'FontSize', obj.fontSize-1, ...
                    'BackgroundColor', obj.markerTypes(ii).color);
                setColorChangeContextMenu(obj.hColorIndicatorPanel(ii), obj);
            end
            
            %% Set up count indicator
            ii=1;
            obj.hCountIndicatorAx=axes(...
                'Parent', obj.hMarkerButtonGroup, ...
                'Units', 'normalized', ...
                'Position', [0.65 0 0.3 1], ...
                'Visible', 'off');
            obj.hCountIndicatorText=text(...
                'Parent', obj.hCountIndicatorAx, ...
                'Units', 'normalized', ...
                'Position', [0.5 0.98-(0.08*ii)+0.04], ...
                'String', '0', ...
                'UserData', ii, ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize+2, ...
                'Color', masivSetting('viewer.textMainColor'), ...
                'HorizontalAlignment', 'center');
            
            obj.hMarkerTypeSelection(ii).Value=1;
            obj.updateMarkerCount(obj.currentType);
            
            for ii=2:numel(obj.markerTypes)
                obj.hCountIndicatorText(ii)=text(...
                    'Parent', obj.hCountIndicatorAx, ...
                    'Units', 'normalized', ...
                    'Position', [0.5 0.98-(0.08*ii)+0.04], ...
                    'String', '0', ...
                    'UserData', ii, ...
                    'FontName', obj.fontName, ...
                    'FontSize', obj.fontSize+2, ...
                    'Color', masivSetting('viewer.textMainColor'), ...
                    'HorizontalAlignment', 'center');
                obj.hMarkerTypeSelection(ii).Value=1;
                obj.updateMarkerCount(obj.currentType);
                
            end
            
            %% Reset Selection
            obj.hMarkerTypeSelection(prevSelection).Value=1;
            
        end
        
        %% Listener Callbacks
        function updateCursorWithinAxes(obj, ~, evData)
            obj.cursorX=round(evData.CursorPosition(1,1));
            obj.cursorY=round(evData.CursorPosition(2,2));
            if ~ obj.MaSIV.contrastMode
                obj.MaSIV.hFig.Pointer='crosshair';
            end
        end
        function updateCursorOutsideAxes(obj, ~, ~)
            obj.MaSIV.hFig.Pointer='arrow';
        end
        function mouseClickInMainWindowAxes(obj, ~, ~)
            tic
            if ~obj.MaSIV.contrastMode
                if obj.hModeAdd.Value
                    obj.UIaddMarker
                elseif obj.hModeDelete.Value
                    obj.UIdeleteMarker
                else
                    error('Unknown mode selection')
                end
            end
        end
        function parentKeyPress(obj, ~,ev)
            keyPress([], ev.KeyPressData, obj);
        end
        function parentClosing(obj, ~, ~)
            deleteRequest([],[], obj,1) %force quit
        end
        
        %% Functions
        function UIaddMarker(obj)
            masivDebugTimingInfo(2, 'CellCounter.UIaddMarker: Beginning',toc,'s')
            newMarker=masivMarker(obj.currentType, obj.deCorrectedCursorX, obj.deCorrectedCursorY, obj.cursorZVoxels);
            masivDebugTimingInfo(2, 'CellCounter.UIaddMarker: New marker created',toc,'s')

            if isempty(obj.markers)
                obj.markers=newMarker;
            else
                obj.markers(end+1)=newMarker;
            end
            masivDebugTimingInfo(2, 'CellCounter.UIaddMarker: Marker added to collection',toc,'s')
            drawMarkers(obj)
            masivDebugTimingInfo(2, 'CellCounter.UIaddMarker: Markers Drawn',toc,'s')

            %% Update count
            obj.incrementMarkerCount(obj.currentType);
            masivDebugTimingInfo(2, 'CellCounter.UIaddMarker: Count updated',toc,'s')
            %% Set change flag
            obj.changeFlag=1;
        end
        
        function UIdeleteMarker(obj)
            masivDebugTimingInfo(2, 'Cellcounter.UIdeleteMarker: beginning', toc, 's')
            if isempty(obj.markers)
                return
            end
            masivDebugTimingInfo(3, 'Cellcounter.UIdeleteMarker: finding markers', toc, 's')
            
            czIdx=find([obj.markers.zVoxel]==obj.cursorZVoxels);
            matchIdx=[obj.markers(czIdx).type]==obj.currentType;
            matchIdxInOriginalList=czIdx(matchIdx);
            masivDebugTimingInfo(3, 'Cellcounter.UIdeleteMarker: found markers', toc, 's')
            if ~isempty(matchIdxInOriginalList)
                markersOfCurrentType=obj.markers(matchIdxInOriginalList);
                masivDebugTimingInfo(3, 'Cellcounter.UIdeleteMarker: found markers of type', toc, 's')
                [dist, closestIdx]=minEucDist2DToMarker(markersOfCurrentType, obj);
                masivDebugTimingInfo(3, 'Cellcounter.UIdeleteMarker: found closest marker', toc, 's')
                if dist<masivSetting('cellCounter.maximumDistanceVoxelsForDeletion')
                    idxToDelete=matchIdxInOriginalList(closestIdx);
                    obj.markers(idxToDelete)=[];
                    obj.drawMarkers;
                    
                    %% Update count
                    obj.decrementMarkerCount(obj.currentType);
                    %% Set change flag
                    obj.changeFlag=1;
                end
            end
           
        end
        
        function drawMarkers(obj, ~, ~)
            if ~isempty(obj.markers)
                if obj.hSuspendDrawing.Value
                    obj.clearMarkers();
                    return
                else
                    masivDebugTimingInfo(2, 'CellCounter.drawMarkers: Beginning',toc,'s')
                    obj.clearMarkers;
                    masivDebugTimingInfo(2, 'CellCounter.drawMarkers: Markers cleared',toc,'s')
                    %% Calculate position and size
                    zRadius=(masivSetting('cellCounter.markerDiameter.z')/2);
                    
                    allMarkerZVoxel=[obj.markers.zVoxel];
                    allMarkerZRelativeToCurrentPlaneVoxels=(abs(allMarkerZVoxel-obj.cursorZVoxels));
                    idx=allMarkerZRelativeToCurrentPlaneVoxels<zRadius;
                    if ~any(idx)
                        return
                    end
                    markersWithinViewOfThisPlane=obj.markers(idx);
                    
                    markerX=[markersWithinViewOfThisPlane.xVoxel];
                    markerY=[markersWithinViewOfThisPlane.yVoxel];
                    markerZ=[markersWithinViewOfThisPlane.zVoxel];
                    
                    [markerX, markerY]=correctXY(obj, markerX, markerY, markerZ);
                    markerRelZ=allMarkerZRelativeToCurrentPlaneVoxels(idx);
                    markerSz=(masivSetting('cellCounter.markerDiameter.xy')*(1-markerRelZ/zRadius)*obj.MaSIV.mainDisplay.viewPixelSizeOriginalVoxels).^2;
                    
                    markerSz=max(markerSz, masivSetting('cellCounter.minimumSize'));
                    
                    markerCol=cat(1, markersWithinViewOfThisPlane.color);
                    
                    hMainImgAx=obj.MaSIV.hMainImgAx;
                    prevhold=ishold(hMainImgAx);
                    hold(hMainImgAx, 'on')
                    %% Eliminate markers not in the current x y view
                    xView=obj.MaSIV.mainDisplay.viewXLimOriginalCoords;
                    yView=obj.MaSIV.mainDisplay.viewYLimOriginalCoords;
                    
                    inViewX=(markerX>=xView(1))&(markerX<=xView(2));
                    inViewY=(markerY>=yView(1))&(markerY<=yView(2));
                    
                    inViewIdx=inViewX&inViewY;
                    
                    markerX=markerX(inViewIdx);
                    markerY=markerY(inViewIdx);
                    markerSz=markerSz(inViewIdx);
                    markerCol=markerCol(inViewIdx, :);
                    %% Draw
                    masivDebugTimingInfo(2, 'CellCounter.drawMarkers: Beginning drawing',toc,'s')
                    obj.hDisplayedMarkers=scatter(obj.MaSIV.hMainImgAx, markerX , markerY, markerSz, markerCol, 'filled', 'HitTest', 'off', 'Tag', 'CellCounter');
                    masivDebugTimingInfo(2, 'CellCounter.drawMarkers: Drawing complete',toc,'s')
                    %% Draw highlights on this plane if we're not too zoomed out
                    
                    obj.drawMarkerHighlights;
                    masivDebugTimingInfo(2, 'CellCounter.drawMarkers: Complete',toc,'s')
                    %% Restore hold
                if ~prevhold
                    hold(hMainImgAx, 'off')
                end
                end
            end
        end
        
        function drawMarkerHighlights(obj)
            allMarkerZVoxel=[obj.markers.zVoxel];
            allMarkerZRelativeToCurrentPlaneUnits=(abs(allMarkerZVoxel-obj.cursorZVoxels));
            %% Draw spots within markers in this plane
            markerInThisPlaneIdx=allMarkerZRelativeToCurrentPlaneUnits==0;
            markersInThisPlane=obj.markers(markerInThisPlaneIdx);
            
            markerX=[markersInThisPlane.xVoxel];
            markerY=[markersInThisPlane.yVoxel];
            markerZ=[markersInThisPlane.zVoxel];

            if~isempty(markerX)
                [markerX, markerY]=correctXY(obj, markerX, markerY, markerZ);
            end
            markerSz=(masivSetting('cellCounter.markerDiameter.xy')*obj.MaSIV.mainDisplay.viewPixelSizeOriginalVoxels)^2;
            
            if markerSz>=masivSetting('cellCounter.minimumSize')
                obj.hDisplayedMarkerHighlights=scatter(obj.MaSIV.hMainImgAx, markerX , markerY, markerSz/4, [1 1 1], 'filled', 'HitTest', 'off', 'Tag', 'CellCounterHighlights');
            end
        end
        
        function clearMarkers(obj)
            if ~isempty(obj.hDisplayedMarkers)
                delete(findobj(obj.MaSIV.hMainImgAx, 'Tag', 'CellCounter'))
            end
            if ~isempty(obj.hDisplayedMarkerHighlights)
                delete(findobj(obj.MaSIV.hMainImgAx, 'Tag', 'CellCounterHighlights'))
            end
        end
        
        function updateMarkerCount(obj, markerTypeToUpdate)
            if isempty(obj.markers)
                num=0;
            else
                num=sum([obj.markers.type]==markerTypeToUpdate);
            end
            idx=obj.markerTypes==markerTypeToUpdate;
            
            obj.hCountIndicatorText(idx).String=sprintf('%u', num);
        end
        
        function incrementMarkerCount(obj, markerTypeToIncrement)
            idx=obj.markerTypes==markerTypeToIncrement;
            prevCount=str2double(obj.hCountIndicatorText(idx).String);
            newCount=prevCount+1;
            obj.hCountIndicatorText(idx).String=sprintf('%u', newCount);
        end
        
        function decrementMarkerCount(obj, markerTypeToDecrement)
            idx=obj.markerTypes==markerTypeToDecrement;
            prevCount=str2double(obj.hCountIndicatorText(idx).String);
            newCount=prevCount-1;
            obj.hCountIndicatorText(idx).String=sprintf('%u', newCount);
        end
        %% Getters
        function type=get.currentType(obj)
            type=obj.markerTypes(obj.hMarkerButtonGroup.SelectedObject.UserData);
        end
        function z=get.cursorZVoxels(obj)
            z=obj.MaSIV.mainDisplay.currentZPlaneOriginalVoxels;
        end
        function z=get.cursorZUnits(obj)
            z=obj.MaSIV.mainDisplay.currentZPlaneUnits;
        end
        
        function offset=get.correctionOffset(obj)
            zvm=obj.MaSIV.mainDisplay.zoomedViewManager;
            if isempty(zvm.xyPositionAdjustProfile)
                offset=[0 0];
            else
                offset=zvm.xyPositionAdjustProfile(obj.cursorZVoxels, :);
            end
        end
        function x=get.deCorrectedCursorX(obj)
            x=obj.cursorX-obj.correctionOffset(2);
        end
        function y=get.deCorrectedCursorY(obj)
             y=obj.cursorY-obj.correctionOffset(1);
        end
        
        %% Setter
        function set.changeFlag(obj, newVal)
            obj.changeFlag=newVal;
            if newVal==1
                obj.registerPluginAsOpenWithParentViewer
                if isempty(strfind(obj.hFig.Name, '*')) %#ok<MCSUP>
                    obj.hFig.Name=[obj.hFig.Name '*']; %#ok<MCSUP>
                end
            elseif newVal==0
                obj.deregisterPluginAsOpenWithParentViewer
                obj.hFig.Name=strrep(obj.hFig.Name, '*', ''); %#ok<MCSUP>
            else
                error('Invalid change flag')
            end
        end
    end
    
    methods(Static)
        function d=displayString()
            d='Cell Counter...';
        end
    end
end

%% Callbacks

function keyPress(~, eventdata, obj)
key=eventdata.Key;
key=strrep(key, 'numpad', '');

ctrlMod=ismember('control', eventdata.Modifier);

switch key
    case {'1' '2' '3' '4' '5' '6' '7' '8' '9'}
        obj.hMarkerTypeSelection(str2double(key)).Value=1;
    case {'0'}
        obj.hMarkerTypeSelection(10).Value=1;
    case 'a'
        if ctrlMod
            obj.hModeAdd.Value=1;
        end
    case 'd'
        if ctrlMod
            obj.hModeDelete.Value=1;
        end
    case 'h'
        obj.hSuspendDrawing.Value=~obj.hSuspendDrawing.Value;
        obj.drawMarkers();
end
end


function deleteRequest(~, ~, obj, forceQuit)
    masivSetting('cellCounter.figurePosition', obj.hFig.Position)
    if obj.changeFlag && ~(nargin>3 && forceQuit ==1)
        agree=questdlg(sprintf('There are unsaved changes that will be lost.\nAre you sure you want to end this session?'), 'Cell Counter', 'Yes', 'No', 'Yes');
        if strcmp(agree, 'No')
            return
        end
    end
    obj.clearMarkers;
    obj.deregisterPluginAsOpenWithParentViewer;
    deleteRequest@masivPlugin(obj);
    obj.MaSIV.hFig.Pointer='arrow';
    delete(obj.hFig);
    delete(obj);
end

function exportData(~, ~, obj)
    [f,p]=uiputfile('*.yml', 'Export Markers', masivSetting('cellCounter.importExportDefault'));
    if isnumeric(f)&&f==0
        return
    end
    
    s=struct;
    for ii=1:numel(obj.markerTypes)
        thisType=obj.markerTypes(ii);
        s.(thisType.name).color=thisType.color;
        if~isempty(obj.markers)
            markersOfThisType=obj.markers([obj.markers.type]==thisType);
            if ~isempty(markersOfThisType)
                s.(thisType.name).markers=markersOfThisType.toStructArray;
            end
        end
    end
    try
        writeSimpleYAML(s, fullfile(p, f))
    catch err
        errordlg('YAML file could not be created', 'Cell Counter')
        rethrow(err)
    end
    
    obj.changeFlag=0;
    
    masivSetting('cellCounter.importExportDefault', fullfile(p, f))
    %% Read it back in to check it's OK
    try
        s=YAML.read(fullfile(p,f));
        [m,t]=convertStructArrayToMarkerAndTypeArrays(s);
        if any(sort(m)~=sort(obj.markers))||any(sort(t)~=sort(obj.markerTypes))
            error('YAML file validation failed')
        else
            msgbox(sprintf('YAML file successfully exported to\n%s\nand validated', fullfile(p, f)))
        end
    catch err
        errordlg(sprintf('Export does not appear to have been successful.\nYAML file seems corrupted, or could not be verified'), 'Cell Counter')
        rethrow(err)
    end
end

function importData(~, ~, obj)
     if obj.changeFlag
        agree=questdlg(sprintf('There are unsaved changes that will be lost.\nAre you sure you want to import markers?'), 'Cell Counter', 'Yes', 'No', 'Yes');
        if strcmp(agree, 'No')
            return
        end
     end
    [f,p]=uigetfile('*.yml', 'Import Markers', masivSetting('cellCounter.importExportDefault'));
    
    try
        s=YAML.read(fullfile(p, f));
    catch
        errordlg('Import error', 'Cell Counter')
        rethrow(err)
    end
    [m,t]=convertStructArrayToMarkerAndTypeArrays(s);
    obj.markerTypes=t;
    obj.markers=m;
    obj.updateMarkerTypeUISelections();
    obj.drawMarkers();
end

%% Utilities
function ms=defaultMarkerTypes(nTypes)
ms(nTypes)=masivMarkerType;
cols=lines(nTypes);
for ii=1:nTypes
    ms(ii).name=sprintf('Type%u', ii);
    ms(ii).color=cols(ii, :);
end
end

function [dist, idx]=minEucDist2DToMarker(markerCollection, obj)
mX=[markerCollection.xVoxel];
mY=[markerCollection.yVoxel];

x=obj.deCorrectedCursorX;
y=obj.deCorrectedCursorY;

euclideanDistance=sqrt((mX-x).^2+(mY-y).^2);
[dist, idx]=min(euclideanDistance);
end

function [m, t]=convertStructArrayToMarkerAndTypeArrays(s)
    f=fieldnames(s);
    t(numel(f))=masivMarkerType;
    m=[];
    for ii=1:numel(f)
        t(ii).name=f{ii};
        col=s.(f{ii}).color;
        if iscell(col)
            col=col{:};
            col=str2num(col); %#ok<ST2NM>
            t(ii).color=col;
        end
        if isnumeric(col) && numel(col) == 3
            t(ii).color=col;
        else
            error('Unknown color specification')
        end
        if isfield(s.(f{ii}), 'markers')
            sm=s.(f{ii}).markers;
            m=[m masivMarker(t(ii), [sm.x], [sm.y], [sm.z])]; %#ok<AGROW>
        end
    end
end

function [markerX, markerY]=correctXY(obj, markerX, markerY, markerZ)
    zvm=obj.MaSIV.mainDisplay.zoomedViewManager;
    if isempty(zvm.xyPositionAdjustProfile)
        return
    else
        offsets=zvm.xyPositionAdjustProfile(markerZ, :);
        markerX=markerX+offsets(: , 2)';
        markerY=markerY+offsets(: , 1)';
    end
        
end

%% Set up context menus to change markers
function setNameChangeContextMenu(h, obj)
mnuChangeMarkerName=uicontextmenu;
uimenu(mnuChangeMarkerName, 'Label', 'Change name...', 'Callback', {@changeMarkerTypeName, h, obj})
h.UIContextMenu=mnuChangeMarkerName;
end

function setColorChangeContextMenu(h, obj)
mnuChangeMarkerColor=uicontextmenu;
uimenu(mnuChangeMarkerColor, 'Label', 'Change color...','Callback', {@changeMarkerTypeColor, h, obj})
h.UIContextMenu=mnuChangeMarkerColor;
end

%% Marker change callbacks
function changeMarkerTypeName(~, ~, obj, parentObj)
oldName=obj.String;
proposedNewName=inputdlg('Change marker name to:', 'Cell Counter: Change Marker Name', 1, {oldName});

if isempty(proposedNewName)
    return
else
    proposedNewName=matlab.lang.makeValidName(proposedNewName{1});
end
if ismember(proposedNewName, {parentObj.markerTypes.name})
    msgbox(sprintf('Name %s is alread taken!', proposedNewName), 'Cell Counter')
    return
end
%% Change type
oldType=parentObj.markerTypes(obj.UserData);
newType=oldType;newType.name=proposedNewName;
parentObj.markerTypes(obj.UserData)=newType;

%% Change matching markers
if ~isempty(parentObj.markers)
    markersWithOldTypeIdx=find([parentObj.markers.type]==oldType);
    for ii=1:numel(markersWithOldTypeIdx)
        parentObj.markers(markersWithOldTypeIdx(ii)).type=newType;
    end
end
%% Refresh panel
obj.String=proposedNewName;
%% Set change flag
            parentObj.changeFlag=1;
end

function changeMarkerTypeColor(~, ~, obj, parentObj)
oldType=parentObj.markerTypes(obj.UserData);
newCol=uisetcolor(oldType.color);
if numel(newCol)<3
    return
end
%% Change type
newType=oldType;newType.color=newCol;
parentObj.markerTypes(obj.UserData)=newType;
%% Change matching markers

if ~isempty(parentObj.markers)
    markersWithOldTypeIdx=find([parentObj.markers.type]==oldType);
    for ii=1:numel(markersWithOldTypeIdx)
        parentObj.markers(markersWithOldTypeIdx(ii)).type=newType;
    end
end

%% Change panel indicator
set(findobj(parentObj.hColorIndicatorPanel, 'UserData', obj.UserData), 'BackgroundColor', newType.color);

%% Redraw markers
parentObj.drawMarkers;
%% Set change flag
            parentObj.changeFlag=1;
end

%% Settings change
function setUpSettingBox(displayName, settingName, yPosition, parentPanel, parentObject)
    fn=masivSetting('font.name');
    fs=masivSetting('font.size');
    
    hEdit=uicontrol(...
        'Style', 'edit', ...
        'Parent', parentPanel, ...
        'Units', 'normalized', ...
        'Position', [0.66 yPosition+0.05 0.32 0.09], ...
        'FontName', fn, ...
        'FontSize', fs, ...
        'BackgroundColor', masivSetting('viewer.mainBkgdColor'), ...
        'ForegroundColor', masivSetting('viewer.textMainColor'), ...
        'UserData', settingName);
    
    hEdit.String=num2str(masivSetting(settingName));
    hEdit.Callback={@checkAndUpdateNewNumericSetting, parentObject};
    
    uicontrol(...
        'Style', 'text', ...
        'Parent', parentPanel, ...
        'Units', 'normalized', ...
        'Position', [0.02 yPosition+0.035 0.61 0.07], ...
        'HorizontalAlignment', 'right', ...
        'FontName', fn, ...
        'FontSize', fs-1, ...
        'BackgroundColor', masivSetting('viewer.mainBkgdColor'), ...
        'ForegroundColor', masivSetting('viewer.textMainColor'), ...
        'String', displayName);

end

function checkAndUpdateNewNumericSetting(obj,ev, parentObject)
    numEquiv=(str2num(ev.Source.String)); %#ok<ST2NM>
    if ~isempty(numEquiv)
        masivSetting(obj.UserData, numEquiv)
    else
        obj.String=num2str(masivSetting(obj.UserData));
    end
    parentObject.drawMarkers();
end







