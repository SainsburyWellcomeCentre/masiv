classdef goggleNeuriteTracer<goggleBoxPlugin


    % goggleNeuriteTracer
    %
    % Purpose 
    % goggleNeuriteTracer is a plugin for goggleViewer that implements 
    % a trakEM-style neurite tracer. 
    % The first point is the "root" node. It can have more than one child
    % node but can not have a parent node. The point from which we will 
    % "grow" is highlighted in red. This point can be moved by holding 
    % down "ALT" and mousing over other points in the current depth 
    % (highlighted by white dots). 
    %
    % 
    % REQUIRES:
    % https://github.com/raacampbell13/matlab-tree.git
    %
    % Rob Campbell - Basel 2015

    properties
        hFig
        pluginName
        
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

        hNeuriteButtonGroup
        hAxon
        hDendrite

        cursorX
        cursorY
        
        markerTypes
        neuriteTrees %Stores the neurite traces in a tree structure
        currentTree %The current neuron
        lastNode % index of the last node in tree. Can be re-set to add branches, etc.

        %consider replacing the handles with a structure of handles (TODO)
        neuriteTraceHandles

        
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
        function obj=goggleNeuriteTracer(caller, ~)
            obj=obj@goggleBoxPlugin(caller); %call constructor of goggleBoxPlugin
            obj.goggleViewer=caller.UserData;
     

            %% Settings
            obj.fontName=gbSetting('font.name');
            obj.fontSize=gbSetting('font.size');
            obj.currentTree=1; %By default we draw on neuron (tree) 1

            try
                pos=gbSetting('neuriteTracer.figurePosition');
            catch
                ssz=get(0, 'ScreenSize');
                lb=[ssz(3)/3 ssz(4)/3];
                pos=round([lb 400 550]);
                gbSetting('neuriteTracer.figurePosition', pos)
                gbSetting('neuriteTracer.markerDiameter.xy', 20);
                gbSetting('neuriteTracer.markerDiameter.z', 30);
                gbSetting('neuriteTracer.minimumSize', 1) %sets when the highlights are drawn. Likely we will eventually ditch this
                gbSetting('neuriteTracer.maximumDistanceVoxelsForDeletion', 500)
            end
            gbSetting('neuriteTracer.importExportDefault', gbSetting('defaultDirectory'))

            obj.pluginName='Neurite Tracer';

            %% Main UI initialisation
            obj.hFig=figure(...
                'Position', pos, ...
                'CloseRequestFcn', {@deleteRequest, obj}, ...
                'MenuBar', 'none', ...
                'NumberTitle', 'off', ...
                'Name', [obj.pluginName, ': ' obj.goggleViewer.mosaicInfo.experimentName], ...
                'Color', gbSetting('viewer.panelBkgdColor'), ...
                'KeyPressFcn', {@keyPress, obj});
            
            %% Marker selection initialisation
            obj.hMarkerButtonGroup=uibuttongroup(...
                'Parent', obj.hFig, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.02 0.6 0.96], ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'), ...
                'Title', 'Marker Type', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize);
            obj.markerTypes=defaultMarkerTypes(1);
            updateMarkerTypeUISelections(obj);
            


            %% Placement mode (add/delete) selection initialisation 
            obj.hModeButtonGroup=uibuttongroup(...
                'Parent', obj.hFig, ...
                'Units', 'normalized', ...
                'Position', [0.64 0.86 0.34 0.12], ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'), ...
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
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'));
            obj.hModeDelete=uicontrol(...
                'Parent', obj.hModeButtonGroup, ...
                'Style', 'radiobutton', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.02 0.96 0.47], ...
                'String', 'Delete (ctrl+d)', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'Value', 0, ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'));
            


            %% Axon/dendrite radio group selection initialisation 
            obj.hNeuriteButtonGroup=uibuttongroup(...
                'Parent', obj.hFig, ...
                'Units', 'normalized', ...
                'Position', [0.64 0.73 0.34 0.12], ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'), ...
                'Title', 'Neurite Type', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize);
            obj.hAxon=uicontrol(...
                'Parent', obj.hNeuriteButtonGroup, ...
                'Style', 'radiobutton', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.45 0.96 0.47], ...
                'String', 'Axon', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'Value', 1, ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'));
            obj.hDendrite=uicontrol(...
                'Parent', obj.hNeuriteButtonGroup, ...
                'Style', 'radiobutton', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.02 0.96 0.47], ...
                'String', 'Dendrite', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'Value', 0, ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'));


            %% Settings panel
            hSettingPanel=uipanel(...
                'Parent', obj.hFig, ...
                'Units', 'normalized', ...
                'Position', [0.64 0.17 0.34 0.55], ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'), ...
                'Title', 'Display Settings', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize);            

            setUpSettingBox('XY Size', 'neuriteTracer.markerDiameter.xy', 0.8, hSettingPanel, obj)
            setUpSettingBox('Z Size', 'neuriteTracer.markerDiameter.z', 0.7, hSettingPanel, obj)
            setUpSettingBox('Min. Size', 'neuriteTracer.minimumSize', 0.6, hSettingPanel, obj)
            setUpSettingBox('Delete Prox.', 'neuriteTracer.maximumDistanceVoxelsForDeletion', 0.48, hSettingPanel, obj)




            %% Import / Export data buttons           
            uicontrol(...
                'Parent', obj.hFig, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [0.64 0.09 0.34 0.06], ...
                'String', 'Import...', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'Value', 1, ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'), ...
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
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'), ...
                'Callback', {@exportData, obj});
            
            %% Listener Declarations
            obj.cursorListenerInsideAxes=event.listener(obj.goggleViewer, 'CursorPositionChangedWithinImageAxes', @obj.updateCursorWithinAxes);
            obj.cursorListenerOutsideAxes=event.listener(obj.goggleViewer, 'CursorPositionChangedOutsideImageAxes', @obj.updateCursorOutsideAxes);
            obj.cursorListenerClick=event.listener(obj.goggleViewer, 'ViewClicked', @obj.mouseClickInMainWindowAxes);
            obj.scrolledListener=event.listener(obj.goggleViewer, 'Scrolled', @obj.drawMarkers);
            obj.zoomedListener=event.listener(obj.goggleViewer, 'Zoomed', @obj.drawMarkers);
            obj.pannedListener=event.listener(obj.goggleViewer, 'Panned', @obj.drawMarkers);
            obj.keyPressListener=event.listener(obj.goggleViewer, 'KeyPress', @obj.parentKeyPress);
            obj.gvClosingListener=event.listener(obj.goggleViewer, 'ViewerClosing', @obj.parentClosing);
            

            %set up the handles for the plot elements
            obj.neuriteTraceHandles = ...
            struct(...
                'hDisplayedMarkers',[],...
                'hDisplayedLines',[],...
                'hDisplayedMarkerHighlights',[],...
                'hDisplayedLinesHighlight',[],...
                'hHighlightedMarker',[],...
                'hRootNode',[]);
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
        function updateCursorWithinAxes(obj, ~, cursorEventData)                          
            obj.cursorX=round(cursorEventData.CursorPosition(1,1));
            obj.cursorY=round(cursorEventData.CursorPosition(2,2));
            obj.goggleViewer.hFig.Pointer='crosshair';
        
            %If alt is pressed we highlight the nearest data point 
            %within the delete proximity and if the user also clicks
            %a new branch is drawn 
            if ismember('alt',get(obj.goggleViewer.hFig,'currentModifier'))
                highlightMarker(obj)
            end
        end    

        function updateCursorOutsideAxes(obj, ~, ~)
            obj.goggleViewer.hFig.Pointer='arrow';
        end
        function mouseClickInMainWindowAxes(obj, ~, ~)
            tic
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
        function parentClosing(obj, ~, ~)
            deleteRequest([],[], obj,1) %force quit
        end
        


        %------------------------------------------------------------------------------------------
        %% Functions
        function UIaddMarker(obj)
            goggleDebugTimingInfo(2, 'NeuriteTracer.UIaddMarker: Beginning',toc,'s')
            newMarker=goggleMarker(obj.currentType, obj.deCorrectedCursorX, obj.deCorrectedCursorY, obj.cursorZVoxels);

            goggleDebugTimingInfo(2, 'NeuriteTracer.UIaddMarker: New marker created',toc,'s')

            if isempty(obj.neuriteTrees) %Currently we handle just one cell per brain
                obj.neuriteTrees{obj.currentTree} = tree(newMarker); %Add first point to tree root
                obj.lastNode=1;
            else
                %Append a point 
                [obj.neuriteTrees{obj.currentTree},obj.lastNode] = ...
                    obj.neuriteTrees{obj.currentTree}.addnode(obj.lastNode,newMarker); 
            end


            goggleDebugTimingInfo(2, 'NeuriteTracer.UIaddMarker: Marker added to collection',toc,'s')
            drawMarkers(obj)
            goggleDebugTimingInfo(2, 'NeuriteTracer.UIaddMarker: Markers Drawn',toc,'s')

            %% Update count
            obj.incrementMarkerCount(obj.currentType); %TODO: I don't think this even works
            goggleDebugTimingInfo(2, 'NeuriteTracer.UIaddMarker: Count updated',toc,'s')
            %% Set change flag
            obj.changeFlag=1;
        end
        
        function idx = findMarkerNearestToCursor(obj)
            %Find marker nearest the cursor and return its index if it's within the delete distance
            %otherwise return nothing
            if isempty(obj.neuriteTrees)
                idx=[];
                return
            end

            %Get all markers from current tree in the current depth only. [TODO: consider allowing other depths as an option]
            nodes=[obj.neuriteTrees{obj.currentTree}.Node{:}];

            matchIdx=find([nodes.zVoxel]==obj.cursorZVoxels);
            if isempty(matchIdx)
                idx=[];
                return
            end

            markersOfCurrentTrace=nodes(matchIdx);                
            [dist, closestIdx]=minEucDist2DToMarker(markersOfCurrentTrace, obj);
            if dist<gbSetting('neuriteTracer.maximumDistanceVoxelsForDeletion')
                idx=matchIdx(closestIdx);
            else
                idx=[];
            end
        
        end
        
        function UIdeleteMarker(obj)
            goggleDebugTimingInfo(2, 'Entering UIdeleteMarker',toc,'s')

            idx = findMarkerNearestToCursor(obj);
            if isempty(idx)            
                fprintf('No points in current z-depth.\n')
                goggleDebugTimingInfo(2, 'Leaving UIdeleteMarker',toc,'s')
                return
            end
            if length(obj.neuriteTrees{obj.currentTree}.getchildren(idx))>1
                fprintf('Can Not Delete Branch Points!\n')
                goggleDebugTimingInfo(2, 'Leaving UIdeleteMarker',toc,'s')
                return
            end

            obj.lastNode = obj.neuriteTrees{obj.currentTree}.Parent(obj.lastNode);
            obj.neuriteTrees{obj.currentTree} = obj.neuriteTrees{obj.currentTree}.removenode(idx);
                
            obj.drawMarkers;

            %% Update count
            obj.decrementMarkerCount(obj.currentType);
            %% Set change flag
            obj.changeFlag=1;
            goggleDebugTimingInfo(2, 'Leaving UIdeleteMarker',toc,'s')
        end
        


        function drawMarkers(obj, ~, ~)
        %The main marker-drawing function 

            if isempty(obj.neuriteTrees) %If no neurite trees exist we do not attempt to draw
                return
            end

            %Clear markers from any previous draws
            goggleDebugTimingInfo(2, 'NeuriteTracer.drawMarkers: Beginning',toc,'s')
            obj.clearMarkers;
            goggleDebugTimingInfo(2, 'NeuriteTracer.drawMarkers: Markers cleared',toc,'s')



            %% Calculate position and size
            nodes=[obj.neuriteTrees{obj.currentTree}.Node{:}]; %Get all nodes from the current tree (current neuron)
            allMarkerZVoxel=[nodes.zVoxel]; %z depth of all points from this tree
            allMarkerZRelativeToCurrentPlaneVoxels=abs(allMarkerZVoxel-obj.cursorZVoxels); %Difference between current depth and marker depth


            %Check how many markers are visible from this depth. Remember that not in the current plane are likely 
            %also visible. This will depend on the Z marker diameter setting. 
            zRadius=(gbSetting('neuriteTracer.markerDiameter.z')/2); 
            idx=allMarkerZRelativeToCurrentPlaneVoxels<zRadius; %1s indicate visible and 0s not visible 

            if ~any(idx) %If no markers are visible from the current z-plane we leave the function 
                return
            end



            msg=sprintf('Found %d markers within view of this z-plane. %d are in this z-plane.',...
                            length(idx), sum(allMarkerZRelativeToCurrentPlaneVoxels==0));
            goggleDebugTimingInfo(2, msg,toc,'s')


            %Search all branches of the tree for nodes that cross the plane. 
            %Note that the following search (tree.findpath method) traces back 
            %each leaf to the root node. So there will be be many redundant points
            %in each branch. Fixing this may speed up performance slightly for trees
            %with many branches. 
            leaves = obj.neuriteTrees{obj.currentTree}.findleaves; %all the leaves of the tree
            paths ={};
            n=1;
            goggleDebugTimingInfo(2, sprintf('Found %d leaves',length(leaves)),toc,'s')

            visibleNodeIdx = find(idx); %index of visible nodes in all branches 
            for ii=1:length(leaves)
                thisPath =  obj.neuriteTrees{obj.currentTree}.findpath(leaves(ii),1);
          
                if ~isempty(mFind(thisPath,visibleNodeIdx)) %Does this branch contain indexes that are in this z-plane?
                    paths{n}=thisPath; 
                    n=n+1;
                end
            end

            %sort the paths by length
            [~,ind]=sort(cellfun(@length,paths),'descend');
            paths=paths(ind);

            %remove points from shorter paths that intersect with the longest path
            %this should help reduce the number of plotted points somewhat.

            xView=obj.goggleViewer.mainDisplay.viewXLimOriginalCoords;
            yView=obj.goggleViewer.mainDisplay.viewYLimOriginalCoords;
            for ii=length(paths):-1:1

                if ii>1
                    [~,pathInd]=intersect(paths{ii},paths{1});

                    if length(pathInd)>1
                        pathInd(end)=[];
                    end
                    
                    initialSize=length(paths{ii});
                    paths{ii}(pathInd)=[]; %trim
                end

                %remove points not in view. 
                if 1 %keep in if statement for now to thoroughly test it
                    x=[nodes(paths{ii}).xVoxel];
                    y=[nodes(paths{ii}).yVoxel];
                    
                    inViewX=(x>=xView(1))&(x<=xView(2));
                    inViewY=(y>=yView(1))&(y<=yView(2));

                    notInView = ~(inViewY & inViewX);
                    paths{ii}(notInView)=[];

                end

                goggleDebugTimingInfo(2, sprintf('Trimmed path %d from %d to %d points',ii,initialSize,length(paths{ii})),toc,'s')
                if isempty(paths{ii})
                    paths(ii)=[];
                end

            end

            %Paths contains the indexes of all nodes in each branch that crosses this plane.
            %Some nodes from a given branch may be out of plane and so not all should be plotted.
            if isempty(paths)
                goggleDebugTimingInfo(2, 'No neurite paths cross this plane',toc,'s')
                return
            end
            goggleDebugTimingInfo(2, 'Found neurite paths that cross this plane',toc,'s')



            % The following loop goes through each candidate branch and finds and plots the points 
            % visible to the current z-plane. 
            hImgAx=obj.goggleViewer.hImgAx;

            prevhold=ishold(hImgAx);
            hold(hImgAx, 'on')

            goggleDebugTimingInfo(2, 'NeuriteTracer.drawMarkers: Beginning drawing',toc,'s')

            %Extract some constants here that we don't need to recalculate each time time in the loop
            markerDimXY=gbSetting('neuriteTracer.markerDiameter.xy');
            markerMinSize=gbSetting('neuriteTracer.minimumSize');
            markerCol=nodes(1).color; %Get the tree's colour from the root node.

            for ii=1:length(paths)

                %node indexes from the *current* branch (path) that are visible in this z-plane
                %Note: any jumps in the indexing of visiblePathIdx indicate nodes that are not visible from the current plane.
                visiblePathIdx=mFind(paths{ii},visibleNodeIdx);
                if isempty(visiblePathIdx)
                    continue %Do not proceed if no nodes are visible from this path
                end

                goggleDebugTimingInfo(2, sprintf('===> Plotting path %d',ii),toc,'s')

                visibleNodesInPathIdx=paths{ii}(visiblePathIdx); %Index values of nodes in the full tree which are also visible nodes

                %Now we can extract the visible nodes and their corresponding relative z positions
                visibleNodesInPath=nodes(visibleNodesInPathIdx); %Extract the visible nodes from the list of all nodes
               

                goggleDebugTimingInfo(2, sprintf('Found visible %d nodes in current branch',length(visibleNodesInPathIdx)), toc, 's')


                %embed into a nan vector to handle lines that leave and re-enter the plane
                %this approach replaces points not to be plotted with nans.
                markerX = nan(1,length(paths{ii}));
                markerY = nan(1,length(paths{ii}));
                markerZ = nan(1,length(paths{ii}));
                markerSz = nan(1,length(paths{ii}));

                %Make a vector that includes all numbers in the range of visiblePathIdx. e.g. if visiblePathIdx
                %is [2,3,9,10] then markerInd will be [1,2,8,9] so that the middle 5 values remain as NaNs. 
                markerInd = visiblePathIdx-min(visiblePathIdx)+1 ;

                %Populate points that are visible with the correct values
                markerX(markerInd) = [nodes(visibleNodesInPathIdx).xVoxel];
                markerY(markerInd) = [nodes(visibleNodesInPathIdx).yVoxel];
                markerZ(markerInd) = [nodes(visibleNodesInPathIdx).zVoxel];

                [markerX, markerY]=correctXY(obj, markerX, markerY, markerZ); %Shift coords in the event of a section being translation corrected

                visibleNodesInPathRelZ=abs(markerZ-obj.cursorZVoxels);%relative z position of each node
                markerSz=(markerDimXY*(1-visibleNodesInPathRelZ/zRadius)*obj.goggleViewer.mainDisplay.viewPixelSizeOriginalVoxels).^2;
                markerSz=max(markerSz, markerMinSize);





                %% Draw basic markers and lines 
                obj.neuriteTraceHandles.hDisplayedLines=plot(hImgAx, markerX , markerY, '-','color',markerCol,...
                    'Tag', 'NeuriteTracer','HitTest', 'off');
                obj.neuriteTraceHandles.hDisplayedMarkers=scatter(hImgAx, markerX , markerY, markerSz, markerCol,...
                    'filled', 'HitTest', 'off', 'Tag', 'NeuriteTracer');


                %Points that are not the root or leaves should all have at least one parent and child. 
                %These may not be be drawn, however, if a parent or child is very far away from the current
                %Z-plane. It would be helpful for the user to know where these out of plane connections are 
                %and to indicate if they are above or below. 

                %Let's start by appending an extra line to all terminal nodes in the current layer that are not leaves
                if isempty(find(leaves==visibleNodesInPathIdx(end)))
                    lastNode=visibleNodesInPathIdx(end);
                    x=nodes(lastNode).xVoxel;
                    y=nodes(lastNode).yVoxel;
                    z=nodes(lastNode).zVoxel;
                    childNodes=obj.neuriteTrees{obj.currentTree}.getchildren(lastNode);
                    for c=1:length(childNodes)
                        x(2)=nodes(childNodes(c)).xVoxel;
                        y(2)=nodes(childNodes(c)).yVoxel;

                        if z>nodes(childNodes(c)).zVoxel;
                            lineType='--';
                        elseif z<nodes(childNodes(c)).zVoxel;
                            lineType=':';
                        elseif z==nodes(childNodes(c)).zVoxel; %may be a point outside of the plot area and on the same layer
                            lineType='-';
                        end
                        plot(hImgAx, x,y,lineType,'Tag', 'NeuriteTracer','HitTest', 'off','Color',markerCol); %note, these are cleared by virtue of the tag. No handle is needed.
                        if ~strcmp(lineType,'-')
                            text(x(2),y(2),['Z:',num2str(nodes(childNodes(c)).zVoxel)],'Color',markerCol,'tag','NeuriteTracer','HitTest', 'off') %TODO: target to axes?
                        end
                    end
                end


                %Make leaves have a triangle
                if ~isempty(find(leaves==visibleNodesInPathIdx(end)))   
                    leafNode=visibleNodesInPathIdx(end);
                    mSize = markerSz(1)/10;
                    if mSize<5 %TODO: do not hard-code this. 
                        mSize=5;
                    end
                    if mSize>10 %TODO: hard-coded horribleness
                        lWidth=2;
                    else
                        lWidth=1;
                    end
                    plot(hImgAx, markerX(1),markerY(1),'^w','markerfacecolor',markerCol,'linewidth',lWidth,'HitTest', 'off','Tag','NeuriteTracer','MarkerSize',mSize) 
                end

                %Now we add the line leading into the first point from a different layer, if this point is not the root node
                if 0 %Doesn't work yet!
                    firstInd=find(~isnan(markerX));
                    firstInd=firstInd(end);
                    L=visibleNodesInPathIdx(end)
                    parentNode=obj.neuriteTrees{obj.currentTree}.getparent(L);
                    nodes(parentNode).zVoxel %hmmm... seems wrong
                    plot(hImgAx, markerX(firstInd),markerY(firstInd),'xw','markerfacecolor',markerCol,'linewidth',lWidth,'HitTest', 'off','Tag','NeuriteTracer','MarkerSize',mSize) 
                end
            

                %Overlay a larger, different, symbol over the root node if it's visible
                if ~isempty(find(visibleNodesInPathIdx==1))
                    rootNode = obj.neuriteTrees{obj.currentTree}.Node{1};
                    rootNodeInd = find(visibleNodesInPathIdx==1);

                    mSize = markerSz(rootNodeInd)/5;
                    if mSize<5 %TODO: do not hard-code this. 
                        mSize=5;
                    end

                    obj.neuriteTraceHandles.hRootNode = plot(hImgAx, rootNode.xVoxel, rootNode.yVoxel, 'd',...
                        'MarkerSize', mSize, 'color', 'w', 'MarkerFaceColor',rootNode.color,...
                        'Tag', 'NeuriteTracer','HitTest', 'off', 'LineWidth', median(markerSz)/75);
                 end

 

                %% Draw highlights over points in the plane
                if any(visibleNodesInPathRelZ==0)
                    f=find(visibleNodesInPathRelZ==0);

                    %The following currently draws lines between points the shouldn't be joined
                    %when stuff enters and leaves the z-plane
                    %obj.neuriteTraceHandles.hDisplayedLinesHighlight=plot(hImgAx,  markerX(f), markerY(f), '-',...
                    %    'Color',obj.neuriteTraceHandles.hDisplayedLines.Color,'LineWidth',2,'Tag', 'NeuriteTracer','HitTest', 'off');
                    obj.neuriteTraceHandles.hDisplayedMarkerHighlights=scatter(hImgAx, markerX(f), markerY(f), markerSz(f)/4, [1,1,1],...
                            'filled', 'HitTest', 'off', 'Tag', 'NeuriteTracerHighlights');

                end


                %If the node append highlight is on the current branch, we attempt to plot it
                if ~isempty(find(visibleNodesInPathIdx==obj.lastNode))
                    goggleDebugTimingInfo(2, sprintf('Plotting node highlighter on path %d',ii), toc, 's')

                    highlightNode = obj.neuriteTrees{obj.currentTree}.Node{obj.lastNode}; %The highlighted node

                    %Get the size of the node 
                    lastNodeInd = find(visibleNodesInPathIdx==obj.lastNode);

                    %Calculate marker size. (WE NEED A BETTER WAY OF DOING THIS. TOO CONFUSING NOW)
                    lastNodeRelZ=abs(highlightNode.zVoxel-obj.cursorZVoxels);
                    mSize=(markerDimXY*(1-lastNodeRelZ/zRadius)*obj.goggleViewer.mainDisplay.viewPixelSizeOriginalVoxels).^2;
                    mSize = mSize/10;
                    if mSize<5
                        mSize=7;
                    end

                    obj.neuriteTraceHandles.hHighlightedMarker = plot(hImgAx, highlightNode.xVoxel, highlightNode.yVoxel,...
                                                  'or', 'markersize', mSize, 'LineWidth', 2,...
                                                  'Tag','LastNode','HitTest', 'off'); 
                end




            end %close paths{ii} loop


            goggleDebugTimingInfo(2, 'NeuriteTracer.drawMarkers: Drawing complete',toc,'s')
            %% Restore hold state
            if ~prevhold
                hold(hImgAx, 'off')
            end
        end %function drawMarkers(obj, ~, ~)
        



        
        function highlightMarker(obj)       
            tic

            idx = findMarkerNearestToCursor(obj);
            if isempty(idx)
                return
            else
                %Now we set the last node to be the highlighted node. Allows for branching.
                obj.lastNode=idx;
            end


            lastNodeObj = findobj(obj.goggleViewer.hImgAx, 'Tag', 'LastNode') ;
            verbose=0;
            if ~isempty(lastNodeObj)
                thisMarker = obj.neuriteTrees{obj.currentTree}.Node{idx};
                set(obj.neuriteTraceHandles.hHighlightedMarker, 'XData', thisMarker.xVoxel, 'YData', thisMarker.yVoxel);
                if verbose, goggleDebugTimingInfo(2, 'Moved lastnode marker',toc,'s'), end
            else
                drawMarkers(obj)
            end


        end

        function clearMarkers(obj)
            if ~isempty(obj.neuriteTraceHandles.hDisplayedMarkers)
                delete(findobj(obj.goggleViewer.hImgAx, 'Tag', 'NeuriteTracer'))
            end
            if ~isempty(obj.neuriteTraceHandles.hDisplayedMarkerHighlights)
                delete(findobj(obj.goggleViewer.hImgAx, 'Tag', 'NeuriteTracerHighlights'))
            end
            if  ~isempty(obj.neuriteTraceHandles.hHighlightedMarker)
                 delete(findobj(obj.goggleViewer.hImgAx, 'Tag', 'LastNode'))
            end
        end
        
        function updateMarkerCount(obj, markerTypeToUpdate)
            if isempty(obj.neuriteTrees)
                num=0;
            else
                num=sum([obj.neuriteTrees.type]==markerTypeToUpdate);
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



        %--------------------------------------------------------------------------------------
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
        
        function offset=get.correctionOffset(obj)
            zvm=obj.goggleViewer.mainDisplay.zoomedViewManager;
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
            d='Neurite Tracer';
        end
    end
end



%------------------------------------------------------------------------------------------------------------------------
%% Callbacks

function deleteRequest(~, ~, obj, forceQuit)
    gbSetting('neuriteTracer.figurePosition', obj.hFig.Position)
    if obj.changeFlag && ~(nargin>3 && forceQuit ==1)
        agree=questdlg(sprintf('There are unsaved changes that will be lost.\nAre you sure you want to end this session?'), 'Cell Counter', 'Yes', 'No', 'Yes');
        if strcmp(agree, 'No')
            return
        end
    end
    obj.clearMarkers;
    obj.deregisterPluginAsOpenWithParentViewer;
    deleteRequest@goggleBoxPlugin(obj);
    obj.goggleViewer.hFig.Pointer='arrow';
    delete(obj.hFig);
    delete(obj);
end

function exportData(~, ~, obj)

    [f,p]=uiputfile('*.mat', 'Export Markers', gbSetting('neuriteTracer.importExportDefault'));
    if isnumeric(f)&&f==0
        return
    end
    
    neurite_markers=obj.neuriteTrees;
    try
        save(fullfile(p, f),'neurite_markers')
    catch err
        errordlg('File could not be created', 'Neurite Tracer')
        rethrow(err)
    end

end

function importData(~, ~, obj)
     if obj.changeFlag
        agree=questdlg(sprintf('There are unsaved changes that will be lost.\nAre you sure you want to import markers?'), obj.pluginName, 'Yes', 'No', 'Yes');
        if strcmp(agree, 'No')
            return
        end
     end
    [f,p]=uigetfile('*.mat', 'Import Markers', gbSetting('neuriteTracer.importExportDefault'));

    
    try
        m=load(fullfile(p, f));
        f=fields(m);
        if length(f)>1
            fprintf('Loading variable %s\n',f{1})
        end
        m=m.(f{1});
    catch
        errordlg('Import error', obj.pluginName)
        rethrow(lasterror)
    end

    obj.neuriteTrees=m;
    obj.currentTree=1; %TODO: fix. For now we just set to first neuron
    obj.lastNode=length(obj.neuriteTrees{obj.currentTree}.Node); %set node to last point in tree

    deltaZ=obj.neuriteTrees{obj.currentTree}.Node{obj.lastNode}.zVoxel-obj.goggleViewer.mainDisplay.currentIndex;
    stdout=obj.goggleViewer.mainDisplay.seekZ(deltaZ)

    %obj.updateMarkerTypeUISelections();

    if stdout
        obj.goggleViewer.mainDisplay.updateZoomedView;
    end

    obj.drawMarkers();
end

%% Utilities
function ms=defaultMarkerTypes(nTypes)
ms(nTypes)=goggleMarkerType;
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

function [m, t]=convertStructArrayToMarkerAndTypeArrays(s)
    f=fieldnames(s);
    t(numel(f))=goggleMarkerType;
    m=[];
    for ii=1:numel(f)
        t(ii).name=f{ii};
        t(ii).color=s.(f{ii}).color;
        if isfield(s.(f{ii}), 'markers')
            sm=s.(f{ii}).neuriteTrees;
            m=[m goggleMarker(t(ii), [sm.x], [sm.y], [sm.z])]; %#ok<AGROW>
        end
    end
end

function [markerX, markerY]=correctXY(obj, markerX, markerY, markerZ)
    zvm=obj.goggleViewer.mainDisplay.zoomedViewManager;
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
if ~isempty(parentObj.neuriteTrees)
    markersWithOldTypeIdx=find([parentObj.neuriteTrees.type]==oldType);
    for ii=1:numel(markersWithOldTypeIdx)
        parentObj.neuriteTrees(markersWithOldTypeIdx(ii)).type=newType;
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

    if ~isempty(parentObj.neuriteTrees)
        markersWithOldTypeIdx=find([parentObj.neuriteTrees.type]==oldType);
        for ii=1:numel(markersWithOldTypeIdx)
            parentObj.neuriteTrees(markersWithOldTypeIdx(ii)).type=newType;
        end
    end

    %% Change panel indicator
    set(findobj(parentObj.hColorIndicatorPanel, 'UserData', obj.UserData),...
     'BackgroundColor', newType.color);

    %% Redraw markers
    parentObj.drawMarkers;
    %% Set change flag
    parentObj.changeFlag=1;
end


%% Settings change
function setUpSettingBox(displayName, settingName, yPosition, parentPanel, parentObject)
    fn=gbSetting('font.name');
    fs=gbSetting('font.size');
    
    hEdit=uicontrol(...
        'Style', 'edit', ...
        'Parent', parentPanel, ...
        'Units', 'normalized', ...
        'Position', [0.66 yPosition+0.05 0.32 0.09], ...
        'FontName', fn, ...
        'FontSize', fs, ...
        'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
        'ForegroundColor', gbSetting('viewer.textMainColor'), ...
        'UserData', settingName);
    
    hEdit.String=num2str(gbSetting(settingName));
    hEdit.Callback={@checkAndUpdateNewNumericSetting, parentObject};
    
    uicontrol(...
        'Style', 'text', ...
        'Parent', parentPanel, ...
        'Units', 'normalized', ...
        'Position', [0.02 yPosition+0.035 0.61 0.07], ...
        'HorizontalAlignment', 'right', ...
        'FontName', fn, ...
        'FontSize', fs-1, ...
        'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
        'ForegroundColor', gbSetting('viewer.textMainColor'), ...
        'String', displayName);

end

function checkAndUpdateNewNumericSetting(obj,ev, parentObject)
    numEquiv=(str2num(ev.Source.String)); %#ok<ST2NM>
    if ~isempty(numEquiv)
        gbSetting(obj.UserData, numEquiv)
    else
        obj.String=num2str(gbSetting(obj.UserData));
    end
    parentObject.drawMarkers();
end







