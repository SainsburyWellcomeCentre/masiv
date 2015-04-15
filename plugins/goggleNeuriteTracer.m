classdef goggleNeuriteTracer<goggleBoxPlugin


    % goggleNeuriteTracer
    %
    % Purpose 
    % Implements a trakEM-style neurite tracer within goggleViewer. 
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
        hDisplayedMarkers
        hDisplayedLines
        hDisplayedMarkerHighlights
        hDisplayedLinesHighlight
        hHighlightedMarker %the handle for the highlight around the marker that will be the parent of the next point (i.e. the last)

        
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
            else
                %delete(obj.hHighlightedMarker) %TODO: decide if we want to do this. For now we won't delete it as it marks the new branch point.
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
            
            % delete(obj.hHighlightedMarker)  %TODO: maybe better location for this

            if isempty(obj.neuriteTrees)
                return
            end

            goggleDebugTimingInfo(2, 'NeuriteTracer.drawMarkers: Beginning',toc,'s')
            obj.clearMarkers;
            goggleDebugTimingInfo(2, 'NeuriteTracer.drawMarkers: Markers cleared',toc,'s')


            %% Calculate position and size
            zRadius=(gbSetting('neuriteTracer.markerDiameter.z')/2); 

            nodes=[obj.neuriteTrees{obj.currentTree}.Node{:}];

            allMarkerZVoxel=[nodes.zVoxel];
            
            allMarkerZRelativeToCurrentPlaneVoxels=(abs(allMarkerZVoxel-obj.cursorZVoxels));


            idx=allMarkerZRelativeToCurrentPlaneVoxels<zRadius; %1 if visible 
            if ~any(idx)
                return
            end
            fprintf('Found %d markers within view of this z-plane. %d are in this z-plane.\n',...
                length(idx), sum(allMarkerZRelativeToCurrentPlaneVoxels==0))
            visibleNodeIdx = 1:length(nodes); 
            visibleNodeIdx = visibleNodeIdx(idx); %index of visible nodes in all branches

            goggleDebugTimingInfo(2, 'Found points in plane',toc,'s')

            %Now keep only branches that have these marker indexes
            leaves = obj.neuriteTrees{obj.currentTree}.findleaves;
            paths ={};
            n=1;
            fprintf('Found %d leaves\n',length(leaves))

            for ii=1:(length(leaves))
                thisPath =  obj.neuriteTrees{obj.currentTree}.findpath(leaves(ii),1);
          
                if ~isempty(mFind(thisPath,visibleNodeIdx))
                    paths{n}=thisPath;
                    n=n+1;
                end
            end

            if isempty(paths)
                goggleDebugTimingInfo(2, 'No neurite paths cross this plane',toc,'s')
                return
            end
            goggleDebugTimingInfo(2, 'Found neurite paths that cross this plane',toc,'s')



            % We now loop through and plot each branch
            hImgAx=obj.goggleViewer.hImgAx;
            prevhold=ishold(hImgAx);
            hold(hImgAx, 'on')

            goggleDebugTimingInfo(2, 'NeuriteTracer.drawMarkers: Beginning drawing',toc,'s')
            visibleNodes=nodes(visibleNodeIdx);
            for ii=1:length(paths)
                fprintf('Plotting path %d\n',ii)

                %fprintf('All indexes in path: '), disp(paths{ii})
            

                %node indexes from the *current* branch (path) that are visible in this z-plane
                %This is flipped backward (high to low) because we'll likely be operating near 
                %the tree's leaves not near the root
                pathIdxWithinViewOfThisPlane=mFind(paths{ii},visibleNodeIdx);


                %The the actual node values so we can index the nodes from the full list of all nodes
                visibleIndInPath=paths{ii}(pathIdxWithinViewOfThisPlane);
                fprintf('Found visible %d nodes in current branch\n',length(visibleIndInPath))


                %Extract the visible nodes from the list of all nodes
                nodesWithinViewOfThisPlane=nodes(visibleIndInPath);



                %embed into a nan vector to handle lines that leave and re-enter the plane
                %this approach replaces points not to be plotted with nans.
                markerInd = pathIdxWithinViewOfThisPlane-min(pathIdxWithinViewOfThisPlane)+1; %needed for when the root isn't visible
                plotVectorLength=range(markerInd);

                markerX=nan(1,plotVectorLength);
                markerY=markerX;
                markerZ=markerX;
                markerSz=markerX;

                markerX(markerInd)=[nodesWithinViewOfThisPlane.xVoxel];
                markerY(markerInd)=[nodesWithinViewOfThisPlane.yVoxel];
                markerZ(markerInd)=[nodesWithinViewOfThisPlane.zVoxel];                

                
                [markerX, markerY]=correctXY(obj, markerX, markerY, markerZ);
                markerRelZ=allMarkerZRelativeToCurrentPlaneVoxels(visibleIndInPath); 

                markerSz(markerInd)=(gbSetting('neuriteTracer.markerDiameter.xy')*(1-markerRelZ/zRadius)*obj.goggleViewer.mainDisplay.viewPixelSizeOriginalVoxels).^2;
                markerSz=max(markerSz, gbSetting('neuriteTracer.minimumSize')); 
                

                markerCol=nodesWithinViewOfThisPlane(1).color;
                

                %% Draw markers and lines 
                obj.hDisplayedLines=plot(hImgAx,markerX , markerY, '-','color',markerCol(1,:),...
                    'Tag', 'NeuriteTracer','HitTest', 'off');
                obj.hDisplayedMarkers=scatter(hImgAx, markerX , markerY, markerSz, markerCol,...
                    'filled', 'HitTest', 'off', 'Tag', 'NeuriteTracer');
      

                %If the node append highlight is on the current branch, we attempt to plot it
                if ~isempty(find(paths{ii}==obj.lastNode))
                    %The marker that indicates where we will append. 
                    highlightNode = obj.neuriteTrees{obj.currentTree}.Node{obj.lastNode};
                    %Find last node index so we can size it correctly
                    %also check the indexing (see above) as it looks overly complicated. 
                    lastNodeInd = pathIdxWithinViewOfThisPlane(find(visibleIndInPath==obj.lastNode));
                    if ~isempty(lastNodeInd)
                        obj.hHighlightedMarker = plot(hImgAx,highlightNode.xVoxel, highlightNode.yVoxel,...
                                                  'or', 'markersize',markerSz(lastNodeInd)/15,...
                                                  'linewidth',2,...
                                                  'Tag','LastNode','HitTest', 'off'); 
                    else
                        fprintf('Not plotting node append highlight for node %d.\n',obj.lastNode)
                    end
                end



                %% Draw highlights over points in the plane
                if ~any(markerRelZ==0)
                    continue
                end

                f=pathIdxWithinViewOfThisPlane(find(markerRelZ==0));

                %The following currently draws lines between points the shouldn't be joined
                %when stuff enters and leaves the z-plane
                %obj.hDisplayedLinesHighlight=plot(hImgAx,  markerX(f), markerY(f), '-',...
                %    'Color',obj.hDisplayedLines.Color,'LineWidth',2,'Tag', 'NeuriteTracer','HitTest', 'off');
                
                obj.hDisplayedMarkerHighlights=scatter(hImgAx, markerX(f), markerY(f), markerSz(f)/4, [1,1,1],...
                    'filled', 'HitTest', 'off', 'Tag', 'NeuriteTracerHighlights');

                %TODO: highlight the leaves and root node

            end


            goggleDebugTimingInfo(2, 'NeuriteTracer.drawMarkers: Drawing complete',toc,'s')
            %% Restore hold state
            if ~prevhold
                hold(hImgAx, 'off')
            end

        end %function drawMarkers(obj, ~, ~)
        



        
        function highlightMarker(obj)       
            delete(obj.hHighlightedMarker)
            idx = findMarkerNearestToCursor(obj);
            if isempty(idx)
                return
            else
                %Now we set the last node to be the highlighted node. This will allow simple branching. 
                obj.lastNode=idx;
            end

            if 0 %Temporary for debugging
                hImgAx=obj.goggleViewer.hImgAx;
                prevhold=ishold(hImgAx);
                hold(hImgAx, 'on')

                thisMarker = obj.neuriteTrees{obj.currentTree}.Node{idx};

                obj.hHighlightedMarker = plot(hImgAx,thisMarker.xVoxel, thisMarker.yVoxel,...
                  'or', 'markersize',10,'linewidth',2,'Tag','LastNode','HitTest', 'off');  %TODO: do not hard-code style here

                %% Restore hold state
                if ~prevhold
                    hold(hImgAx, 'off')
                end
            else
                drawMarkers(obj)
            end


        end

        function clearMarkers(obj)
            if ~isempty(obj.hDisplayedMarkers)
                delete(findobj(obj.goggleViewer.hImgAx, 'Tag', 'NeuriteTracer'))
            end
            if ~isempty(obj.hDisplayedMarkerHighlights)
                delete(findobj(obj.goggleViewer.hImgAx, 'Tag', 'NeuriteTracerHighlights'))
            end
            if  ~isempty(obj.hHighlightedMarker)
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







