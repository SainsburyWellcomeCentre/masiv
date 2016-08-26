classdef niftiViewer<masivPlugin
    %NIFTIVIEWER
    
    properties
        hFig
        
        fontName
        fontSize
        
        segmentation
        hTree

    end
    
    
    properties(Access=private)
        scrolledListener
        hDisplayedMarkers
        markerEditBoxes
    end
    properties(Dependent, SetAccess=private)
        currentPlane
    end
    methods
        function obj=niftiViewer(caller, ~, brainName)
            if nargin < 3
                brainName='';
            end
            obj=obj@masivPlugin(caller);
             %% Settings
            obj.fontName=masivSetting('font.name');
            obj.fontSize=masivSetting('font.size');
            try
                pos=masivSetting('niftiViewer.figurePosition');
            catch
                ssz=get(0, 'ScreenSize');
                lb=[ssz(3)/3 ssz(4)/3];
                pos=round([lb 1000 800]);
                masivSetting('niftiViewer.figurePosition', pos)
                masivSetting('niftiViewer.markerDiameter.xy', 20);
                masivSetting('niftiViewer.markerDiameter.z', 30);
                masivSetting('niftiViewer.minimumSize', 20)
                masivSetting('niftiViewer.maximumDistanceVoxelsForDeletion', 500)
            end

            %% Main UI
             obj.hFig=figure(...
                'Position', pos, ...
                'CloseRequestFcn', {@deleteRequest, obj}, ...
                'MenuBar', 'none', ...
                'NumberTitle', 'off', ...
                'Name', ['nifti Marker Viewer: ' obj.MaSIV.Meta.stackName], ...
                'Color', masivSetting('viewer.panelBkgdColor'), ...
                'KeyPressFcn', {@keyPress, obj});
            
            %% Get markers
            obj.segmentation=getWorkspaceMarkers(brainName);
            if isempty(obj.segmentation)
                deleteRequest([], [], obj)
                return
            end
            
            %% Set up tree view
            obj.hTree=obj.segmentation.treeView(obj.hFig);
            
            %% Set up buttons and selection box
            setupDisplays(obj)
            %% Listeners
            obj.scrolledListener=event.listener(obj.MaSIV, 'Scrolled', @obj.drawMarkers);
        end
        %% Getters
        function z=get.currentPlane(obj)
            z=obj.MaSIV.mainDisplay.currentZPlaneOriginalVoxels;
        end
    end
    
    methods % Callbacks
        
        function drawMarkers(obj, ~, ~)
           
            %% Clear
            obj.clearMarkers();
            %% Get Data
            ML=[];DV=[];PA=[];deWarpedX=[];deWarpedY=[];deWarpedZ=[];originalIdx=[];segmentationAcronym={};contralateral=[];col=[];
            allCells=table(ML, DV, PA, deWarpedX, deWarpedY, deWarpedZ, originalIdx, segmentationAcronym, contralateral, col);
            clear ML DV PA deWarpedX deWarpedY deWarpedZ segmentationAcronym col
            for ii=1:numel(obj.markerEditBoxes)
                if isfield(obj.markerEditBoxes(ii).UserData, 'Active')
                    newCells=obj.markerEditBoxes(ii).UserData.Active;
                    newCells.col=repmat(obj.markerEditBoxes(ii).UserData.Color, ...
                        size(newCells, 1), 1);
                    allCells=[allCells;newCells];
                end
            end
            %% Calculate position and size
            zRadius=(masivSetting('cellCounter.markerDiameter.z')/2);
            
            allMarkerZVoxel=[allCells.PA];
            
            allMarkerZRelativeToCurrentPlaneVoxels=(abs(allMarkerZVoxel-obj.currentPlane));
        
            idx=allMarkerZRelativeToCurrentPlaneVoxels<zRadius;
            if ~any(idx)
                return
            end
            markersWithinViewOfThisPlane=allCells(idx, :);
        
            markerX=markersWithinViewOfThisPlane.ML;
            markerY=markersWithinViewOfThisPlane.DV;
            markerZ=markersWithinViewOfThisPlane.PA;
        
            [markerX, markerY]=correctXY(obj, markerX, markerY, markerZ);
            markerRelZ=allMarkerZRelativeToCurrentPlaneVoxels(idx);
            markerSz=(masivSetting('cellCounter.markerDiameter.xy')*(1-markerRelZ/zRadius)*obj.MaSIV.mainDisplay.viewPixelSizeOriginalVoxels).^2;

            markerSz=max(markerSz, masivSetting('cellCounter.minimumSize'));
        
            markerCol=allCells.col(idx, :);
        
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
            masivDebugTimingInfo(2, 'niftiViewer.drawMarkers: Beginning drawing',toc,'s')
            obj.hDisplayedMarkers=scatter(obj.MaSIV.hMainImgAx, markerX , markerY, markerSz, markerCol,...
                'filled', 'HitTest', 'off', 'Tag', 'CellCounter');
            masivDebugTimingInfo(2, 'niftiViewer.drawMarkers: Drawing complete',toc,'s')
           
            %% Restore hold
                if ~prevhold
                    hold(hMainImgAx, 'off')
                end
        end
        function clearMarkers(obj)
            if ~isempty(obj.hDisplayedMarkers)
                delete(findobj(obj.MaSIV.hMainImgAx, 'Tag', 'CellCounter'))
            end
        end
    end
    methods(Static)
        function d=displayString()
            d='nifti Marker Viewer';
        end
    end
end

%% Callback functions

function keyPress(~, ~, ~)

end

function deleteRequest(~, ~, obj)
    obj.clearMarkers()
    masivSetting('niftiViewer.figurePosition', obj.hFig.Position)
    obj.deregisterPluginAsOpenWithParentViewer;
    deleteRequest@masivPlugin(obj);
    delete(obj.hFig);
    delete(obj);
end

%% Utilities

function markers=getWorkspaceMarkers(brainName)
    markers=[];
    bwsVariables=evalin('base', 'whos;');
    segBrainVariables=bwsVariables(strcmp({bwsVariables.class}, 'warpedBrain'));
    if isempty(segBrainVariables)
        msgbox('No warped brain objects in the workspace. Quitting.')
        return
    end
    if numel(segBrainVariables)>1
        selection=listdlg(...
            'ListString', {segBrainVariables.name}, ...
            'SelectionMode', 'single', ...
            'Name', 'Select Brains Variable');
        if isempty(selection )
            return
        end
    else
        selection=1;
    end
    segBrains=evalin('base', sprintf('%s;', segBrainVariables(selection).name));
    
    if numel(segBrains)>1
        if ~isempty(brainName) && any(strcmpi({segBrains.name}, brainName))
            selection=strcmpi({segBrains.name}, brainName);
        else
            selection=listdlg(...
                'ListString', {segBrains.name}, ...
                'SelectionMode', 'single', ...
                'Name', 'Select Brains Object');
            if isempty(selection )
            return
        end
        end
    else
        selection = 1;
    end
    markers=segBrains(selection);
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

function setupDisplays(obj)

nDisplays=9;

displayColors=flipud(distinguishable_colors(nDisplays, [0.3 0.3 0.3]));
        
for ii=1:nDisplays;
    
    ySpacing=0.1;
    
    editBox=uicontrol(...
        'Parent', obj.hFig, ...
        'Style', 'text', ...
        'Units', 'normalized', ...
        'Position', [0.65 0.1+(ii-1)*ySpacing 0.33 0.03], ...
        'String', '', ...
        'FontSize', 14, ...
        'BackgroundColor', masivSetting('viewer.mainBkgdColor'), ...
        'ForegroundColor', masivSetting('viewer.textMainColor'));
    
    colPanel=uipanel(...
        'Parent', obj.hFig, ...
        'Units', 'normalized', ...
        'Position', [0.58 0.1+(ii-1)*ySpacing 0.05 0.03], ...
        'BackgroundColor', displayColors(ii, :));
    hHideButton=uicontrol(...
        'Parent', obj.hFig, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.58 0.06+(ii-1)*ySpacing 0.05 0.03], ...
        'String', 'Hide', ...
        'Enable', 'off', ...
        'BackgroundColor', masivSetting('viewer.panelBkgdColor'), ...
        'ForegroundColor', masivSetting('viewer.textMainColor'));
    
    
     bg = uibuttongroup(...
         'Units', 'normalized', ...
         'Position', [0.65 0.06+(ii-1)*ySpacing, 0.28, 0.03], ...
         'BackgroundColor', masivSetting('viewer.panelBkgdColor'), ...
         'SelectionChangedFcn', @(~, x) changeSelected(x, editBox));
     
     hSelectAll=uicontrol(bg, ...
         'Style', 'radiobutton', ...
         'Units', 'normalized', ...
         'Position', [0 0 0.3 1], ...
         'String', 'All', ...
         'BackgroundColor', masivSetting('viewer.mainBkgdColor'), ...
         'ForegroundColor', masivSetting('viewer.textMainColor'), ...
         'Enable', 'off');
      
     hSelectTheseOnly=uicontrol(bg, ...
         'Style', 'radiobutton', ...
         'Units', 'normalized', ...
         'Position', [0.3 0 0.7 1], ...
         'String', 'This region only', ...
         'BackgroundColor', masivSetting('viewer.mainBkgdColor'), ...
         'ForegroundColor', masivSetting('viewer.textMainColor'), ...
         'Enable', 'off');
    
    hClearButton=uicontrol(...
        'Parent', obj.hFig, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.52 0.06+(ii-1)*ySpacing 0.05 0.03], ...
        'String', 'Clear', ...
        'Enable', 'off', ...
        'BackgroundColor', masivSetting('viewer.panelBkgdColor'), ...
        'ForegroundColor', masivSetting('viewer.textMainColor'), ...
        'Callback', @(x,~) clearMarker(obj, x, editBox, hHideButton, bg));
    
    uicontrol(...
        'Parent', obj.hFig, ...
        'Style', 'pushbutton', ...
        'Units', 'normalized', ...
        'Position', [0.52 0.1+(ii-1)*ySpacing 0.05 0.03], ...
        'String', 'Add', ...
        'BackgroundColor', masivSetting('viewer.panelBkgdColor'), ...
        'ForegroundColor', masivSetting('viewer.textMainColor'), ...
        'Callback', @(~,~) setMarker(obj, editBox, hClearButton, hHideButton, hSelectAll, hSelectTheseOnly, colPanel, bg));
     
    registerEditBoxForMarkerDisplay(obj, editBox);
    hHideButton.Callback=@(x, ~) toggleHide(obj, x, editBox);
end
end

function setMarker(obj, editBox, hClearButton, hHideButton, hSelectAll, hSelectTheseOnly, hColPanel, bg)
    selNode = obj.hTree.getSelectedNodes;
    editBox.String=strtok(selNode(1).getName.toCharArray', ':');  
    hClearButton.Enable='on';
    hHideButton.Enable='on';
    %% Get cells and total cells and stick in userdata of the edit box
    selectedAcronym = strtok(selNode(1).getValue, ':');
    if strcmp(selectedAcronym, 'All Cells')
        dat.selectedCells = [];
        dat.totalCells = ...
            [obj.segmentation.segmentation.findRegion('grey').totalCells;
             obj.segmentation.unsegmentedCells];
    elseif strcmp(selectedAcronym, 'unsegmented')
        dat.selectedCells=obj.segmentation.unsegmentedCells;
        dat.totalCells=obj.segmentation.unsegmentedCells;
        dat.totalCells.segmentationAcronym=repmat({'unsegmented'}, size(dat.totalCells, 1), 1);
    else
        dat.selectedCells = obj.segmentation.segmentation.findRegion(selectedAcronym).cells;
        dat.totalCells = obj.segmentation.segmentation.findRegion(selectedAcronym).totalCells;
    end
    editBox.UserData=dat;
    hSelectAll.Value=1;
    editBox.UserData.Active=editBox.UserData.totalCells;
    %% Put counts on selectAll and selectTheseOnly radio buttons
    hSelectAll.String=sprintf('All (%u)', size(dat.totalCells, 1));
    hSelectTheseOnly.String=sprintf('This region only (%u)', size(dat.selectedCells, 1));
    %% Set color
    editBox.UserData.Color=hColPanel.BackgroundColor;
    %% Enable type selection
    set(bg.Children, 'Enable', 'on');
    %% Draw
    obj.drawMarkers();
end

function clearMarker(obj, clearButton, editBox, hHideButton, bg)
    editBox.String='';
    editBox.UserData=[];
    clearButton.Enable='off';
    hHideButton.Enable='off';
    set(bg.Children, 'Enable', 'off');
    obj.drawMarkers();
end

function toggleHide(obj, hideButton, editBox)
    switch hideButton.String
        case 'Hide'
            hideButton.String='Show';
            editBox.UserData.Inactive=editBox.UserData.Active;
            editBox.UserData=rmfield(editBox.UserData, 'Active');
        case 'Show'
            hideButton.String='Hide';
            editBox.UserData.Active=editBox.UserData.Inactive;
    end
    obj.drawMarkers();
end

function changeSelected(bg, editBox)
if strfind(bg.NewValue.String, 'All')
    editBox.UserData.Active=editBox.UserData.totalCells;
else
    editBox.UserData.Active=editBox.UserData.selectedCells;
end
end

function obj=registerEditBoxForMarkerDisplay(obj, editBox)
    if isempty(obj.markerEditBoxes)
        obj.markerEditBoxes=editBox;
    else
        obj.markerEditBoxes=[obj.markerEditBoxes editBox];
    end
    
end

