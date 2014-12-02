classdef goggleCellCounter<goggleBoxPlugin
    properties
        goggleViewer
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
        
        
    end
    
    properties(Dependent, SetAccess=protected)
        currentType
        cursorZVoxels
        cursorZUnits
    end
    
    methods
        %% Constructor
        function obj=goggleCellCounter(caller, ~)
            obj=obj@goggleBoxPlugin;
            obj.goggleViewer=caller.UserData;
            
            %% Settings
            obj.fontName=gbSetting('font.name');
            obj.fontSize=gbSetting('font.size');
            try
                pos=gbSetting('cellCounter.figurePosition');
            catch
                ssz=get(0, 'ScreenSize');
                lb=[ssz(3)/3 ssz(4)/3];
                pos=round([lb 400 550]);
                gbSetting('cellCounter.figurePosition', pos)
                gbSetting('cellCounter.markerDiameter.xy', 20);
                gbSetting('cellCounter.markerDiameter.z', 30);
                gbSetting('cellCounter.unitSizeHideHighlights', 0);
                gbSetting('cellCounter.maximumDistanceVoxelsForDeletion', 500)
            end
            %% Main UI initialisation
            obj.hFig=figure(...
                'Position', pos, ...
                'CloseRequestFcn', {@deleteFig, obj}, ...
                'MenuBar', 'none', ...
                'NumberTitle', 'off', ...
                'Name', ['Cell Counter: ' obj.goggleViewer.mosaicInfo.experimentName], ...
                'Color', gbSetting('viewer.panelBkgdColor'), ...
                'KeyPressFcn', {@keyPress, obj});
            %% Marker selection initialisation
            obj.hMarkerButtonGroup=uibuttongroup(...
                'Parent', obj.hFig, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.02 0.7 0.96], ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'));
            obj.markerTypes=defaultMarkerTypes(10);
            updateMarkerTypeUISelections(obj);
            %% Mode selection initialisation
            obj.hModeButtonGroup=uibuttongroup(...
                'Parent', obj.hFig, ...
                'Units', 'normalized', ...
                'Position', [0.74 0.52 0.24 0.46], ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'));
            obj.hModeAdd=uicontrol(...
                'Parent', obj.hModeButtonGroup, ...
                'Style', 'radiobutton', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.88 0.96 0.1], ...
                'String', 'Add', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'Value', 1, ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'));
            obj.hModeDelete=uicontrol(...
                'Parent', obj.hModeButtonGroup, ...
                'Style', 'radiobutton', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.78 0.96 0.1], ...
                'String', 'Delete', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'Value', 0, ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'));
            %% Listener Declarations
            obj.cursorListenerInsideAxes=event.listener(obj.goggleViewer, 'CursorPositionChangedWithinImageAxes', @obj.updateCursorWithinAxes);
            obj.cursorListenerOutsideAxes=event.listener(obj.goggleViewer, 'CursorPositionChangedOutsideImageAxes', @obj.updateCursorOutsideAxes);
            obj.cursorListenerClick=event.listener(obj.goggleViewer, 'ViewClicked', @obj.mouseClickInMainWindowAxes);
            obj.scrolledListener=event.listener(obj.goggleViewer, 'Scrolled', @obj.drawMarkers);
            obj.zoomedListener=event.listener(obj.goggleViewer, 'Zoomed', @obj.drawMarkers);
            obj.keyPressListener=event.listener(obj.goggleViewer, 'KeyPress', @obj.parentKeyPress);
            %% Freeze menu
            obj.setParentMenuEnabled('off')
            
            
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
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'));
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
                    'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                    'ForegroundColor', gbSetting('viewer.textMainColor'));
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
                'Color', gbSetting('viewer.textMainColor'), ...
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
                    'Color', gbSetting('viewer.textMainColor'), ...
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
            obj.goggleViewer.hFig.Pointer='crosshair';
        end
        function updateCursorOutsideAxes(obj, ~, ~)
            obj.goggleViewer.hFig.Pointer='arrow';
        end
        function mouseClickInMainWindowAxes(obj, ~, ~)
            if obj.hModeAdd.Value
                obj.UIaddMarker
            elseif obj.hModeDelete.Value
                obj.UIdeleteMarker
            else
                error('Unknown mode selection')
            end
            
        end
        function parentKeyPress(obj, ~,ev)
            keyPress([], ev.KeyPressData, obj);
        end
        
        %% Functions
        function UIaddMarker(obj)
            newMarker=goggleMarker(obj.currentType, obj.cursorX, obj.cursorY, obj.cursorZVoxels);
            if isempty(obj.markers)
                obj.markers=newMarker;
            else
                obj.markers=[obj.markers newMarker];
            end
            drawMarkers(obj)
            %% Update count
            obj.updateMarkerCount(obj.currentType);
        end
        
        function UIdeleteMarker(obj)
            if isempty(obj.markers)
                return
            end
            matchIdx=find([obj.markers.type]==obj.currentType&[obj.markers.zVoxel]==obj.cursorZVoxels);
            
            if ~isempty(matchIdx)
                markersOfCurrentType=obj.markers(matchIdx);
                
                [dist, closestIdx]=minEucDist2DToMarker(markersOfCurrentType, obj);
                
                if dist<gbSetting('cellCounter.maximumDistanceVoxelsForDeletion')
                    idxToDelete=matchIdx(closestIdx);
                    obj.markers(idxToDelete)=[];
                    obj.drawMarkers;
                end
            end
            %% Update count
            obj.updateMarkerCount(obj.currentType);
        end
        
        function drawMarkers(obj, ~, ~)
            obj.clearMarkers;
            %% Calculate position and size
            zRadius=(gbSetting('cellCounter.markerDiameter.z')/2);
            
            allMarkerZRelativeToCurrentPlaneVoxels=(abs([obj.markers.zVoxel]-obj.cursorZVoxels));
            
            idx=allMarkerZRelativeToCurrentPlaneVoxels<zRadius;
            if ~any(idx)
                return
            end
            markersWithinViewOfThisPlane=obj.markers(idx);
            
            markerX=[markersWithinViewOfThisPlane.xVoxel];
            markerY=[markersWithinViewOfThisPlane.yVoxel];
            markerRelZ=allMarkerZRelativeToCurrentPlaneVoxels(idx);
            markerSz=(gbSetting('cellCounter.markerDiameter.xy')*(1-markerRelZ/zRadius)*obj.goggleViewer.mainDisplay.viewPixelSizeOriginalVoxels).^2;
            
            markerCol=cat(1, markersWithinViewOfThisPlane.color);
            
            hImgAx=obj.goggleViewer.hImgAx;
            prevhold=ishold(hImgAx);
            hold(hImgAx, 'on')
            %% Draw
            obj.hDisplayedMarkers=scatter(obj.goggleViewer.hImgAx, markerX , markerY, markerSz, markerCol, 'filled', 'HitTest', 'off');
            %% Draw highlights on this plane if we're not too zoomed out
            
            if ~(gbSetting('cellCounter.unitSizeHideHighlights')>obj.goggleViewer.mainDisplay.viewPixelSizeOriginalVoxels)
                obj.drawMarkerHighlights;
            end
            %% Restore hold
            if ~prevhold
                hold(hImgAx, 'off')
            end
        end
        
        function drawMarkerHighlights(obj)
            
            allMarkerZRelativeToCurrentPlaneUnits=(abs([obj.markers.zVoxel]-obj.cursorZVoxels));
            %% Draw rings around markers in this plane
            markerInThisPlaneIdx=allMarkerZRelativeToCurrentPlaneUnits==0;
            markersInThisPlane=obj.markers(markerInThisPlaneIdx);
            
            markerX=[markersInThisPlane.xVoxel];
            markerY=[markersInThisPlane.yVoxel];
            markerSz=(gbSetting('cellCounter.markerDiameter.xy')*obj.goggleViewer.mainDisplay.viewPixelSizeOriginalVoxels).^2;
            
            
            obj.hDisplayedMarkerHighlights=scatter(obj.goggleViewer.hImgAx, markerX , markerY, markerSz/4, [1 1 1], 'filled', 'HitTest', 'off');
            
        end
        
        function clearMarkers(obj)
            if ~isempty(obj.hDisplayedMarkers)
                delete(obj.hDisplayedMarkers)
            end
            if ~isempty(obj.hDisplayedMarkerHighlights)
                delete(obj.hDisplayedMarkerHighlights)
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
        
        function setParentMenuEnabled(obj, val)
            obj.goggleViewer.mnuPlugins.Enable=val;
        end
        
        %% Getters
        function type=get.currentType(obj)
            type=obj.markerTypes(obj.hMarkerButtonGroup.SelectedObject.UserData);
        end
        function z=get.cursorZVoxels(obj)
            z=obj.goggleViewer.mainDisplay.currentZPlaneOriginalVoxels;
        end
        function z=get.cursorZUnits(obj)
            z=obj.goggleViewer.mainDisplay.currentZPlaneUnits;
        end
    end
    
    methods(Static)
        function d=displayString()
            d='Cell Counter...';
        end
    end
end

%% Utilities
function deleteFig(~, ~, obj)
obj.clearMarkers;
obj.goggleViewer.hFig.Pointer='arrow';
obj.setParentMenuEnabled('on')
delete(obj.hFig);
delete(obj);
end

function ms=defaultMarkerTypes(nTypes)
ms(nTypes)=goggleMarkerType;
cols=lines(nTypes);
for ii=1:nTypes
    ms(ii).name=sprintf('Type %u', ii);
    ms(ii).color=cols(ii, :);
end
end

function [dist, idx]=minEucDist2DToMarker(markerCollection, obj)
mX=[markerCollection.xVoxel];
mY=[markerCollection.yVoxel];

x=obj.cursorX;
y=obj.cursorY;

euclideanDistance=sqrt((mX-x).^2+(mY-y).^2);
[dist, idx]=min(euclideanDistance);
end

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
function changeMarkerTypeName(~, ev, obj, parentObj)
oldName=obj.String;
proposedNewName=inputdlg('Change marker name to:', 'Cell Counter: Change Marker Name', 1, {oldName});

if isempty(proposedNewName)
    return
else
    proposedNewName=proposedNewName{1};
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
parentObj.updateMarkerTypeUISelections;
end

function changeMarkerTypeColor(~, ev, obj, parentObj)

end
