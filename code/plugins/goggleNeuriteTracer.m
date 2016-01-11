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
    % You may label the current node using the GUI panel (e.g. see the 
    % "neurite type" and "termination" panels)
    %
    % Note that mouse wheel changes layers and ctrl+wheel zooms.
    %
    % Keyboard shortcuts:
    % ctrl+a - switch to add mode
    % ctrl+d - switch to delete mode
    % r      - go to layer that contains the root node
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

        %Tree selector handles
        hMarkerButtonGroup
        hTreeSelection
        hTreeChangeNameButtons
        hColorIndicatorPanel
        hTreeCheckBox
        hCountIndicatorAx
        hCountIndicatorText

        hModeButtonGroup
        hModeAdd
        hModeDelete

        hNeuriteButtonGroup
        hAxon
        hDendrite

        hIsTerminatedGroup
        hIsTerminated

        cursorX
        cursorY

        maxNeuriteTrees %maximum number of trees that can be drawn
        markerTypes
        neuriteTrees %Stores the neurite traces in a tree structure
        currentTree %The current neuron
        lastNode % index of the last node in tree. Can be re-set to add branches, etc. vector same length as neuriteTrees

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

    properties(Dependent, SetAccess=protected) %access with get methods
        currentType
        selectedTreeIdx 
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
                'Title', 'Neurite Trees', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize);
            %Set up empty tree structure and associated variables
            obj.maxNeuriteTrees=6; 
            obj.neuriteTrees = cell(1,obj.maxNeuriteTrees);
            obj.lastNode=zeros(1,obj.maxNeuriteTrees);
            obj.markerTypes=defaultMarkerTypes(obj.maxNeuriteTrees); %Set this to the number of neurons
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
                'Callback', {@neuriteTypeCallback,obj}, ...
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
                'Callback', {@neuriteTypeCallback,obj}, ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'Value', 0, ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'));


            %% Premature termination checkbox
            obj.hIsTerminatedGroup=uibuttongroup(...
                'Parent', obj.hFig, ...
                'Units', 'normalized', ...
                'Position', [0.64 0.61 0.34 0.12], ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'), ...
                'Title', 'Termination', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize);
            obj.hIsTerminated=uicontrol(...
                'Parent', obj.hIsTerminatedGroup, ...
                'Style', 'checkbox', ...
                'Callback', {@prematureCallback,obj}, ...
                'Units', 'normalized', ...
                'Position', [0.05 0.45 0.96 0.47], ...
                'String', 'Premature', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'Value', 0, ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'));


            %% Settings panel
            hSettingPanel=uipanel(...
                'Parent', obj.hFig, ...
                'Units', 'normalized', ...
                'Position', [0.64 0.17 0.34 0.43], ...
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
            obj.scrolledListener=event.listener(obj.goggleViewer, 'Scrolled', @obj.drawAllTrees);
            obj.zoomedListener=event.listener(obj.goggleViewer, 'Zoomed', @obj.drawAllTrees);
            obj.pannedListener=event.listener(obj.goggleViewer, 'Panned', @obj.drawAllTrees);
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

            obj.toggleNodeModifers('off')
        end % Constructor

        %% Set up markers
        function updateMarkerTypeUISelections(obj)
            %% Clear controls, if appropriate
            if ~isempty(obj.hTreeSelection)
                prevSelection=find(obj.hTreeSelection==obj.hMarkerButtonGroup.SelectedObject);
                delete(obj.hTreeSelection)
                delete(obj.hTreeChangeNameButtons)
                delete(obj.hCountIndicatorAx)
            else
                prevSelection=1;
            end

            %% Set up radio buttons
            ii=1;

            obj.hTreeSelection=uicontrol(...
                'Parent', obj.hMarkerButtonGroup, ...
                'Style', 'radiobutton', ...
                'Units', 'normalized', ...
                'Position', [0.18 0.98-(0.08*ii) 0.45 0.08], ...
                'String', obj.markerTypes(ii).name, ...
                'UserData', ii, ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'Callback', {@treeRadioSelectCallback,obj}, ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'));
            setNameChangeContextMenu(obj.hTreeSelection, obj)

            for ii=2:numel(obj.markerTypes)
                obj.hTreeSelection(ii)=uicontrol(...
                    'Parent', obj.hMarkerButtonGroup, ...
                    'Style', 'radiobutton', ...
                    'Units', 'normalized', ...
                    'Position', [0.18 0.98-(0.08*ii) 0.45 0.08], ...
                    'String', obj.markerTypes(ii).name, ...
                    'UserData', ii, ...
                    'FontName', obj.fontName, ...
                    'FontSize', obj.fontSize, ...
                    'Callback', {@treeRadioSelectCallback,obj}, ...
                    'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                    'ForegroundColor', gbSetting('viewer.textMainColor'));
                setNameChangeContextMenu(obj.hTreeSelection(ii), obj)

            end
            obj.hTreeSelection(1).Value=1; 
            %% Set up color indicator
            ii=1;
            colIndSize = [0.06 0.06];
            obj.hColorIndicatorPanel=uipanel(...
                'Parent', obj.hMarkerButtonGroup, ...
                'Units', 'normalized', ...
                'Position', [0.02, 0.98-(0.08*ii)+0.01, colIndSize], ...
                'UserData', ii, ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize-1, ...
                'BackgroundColor', obj.markerTypes(ii).color);
            setColorChangeContextMenu(obj.hColorIndicatorPanel, obj);
            for ii=2:numel(obj.markerTypes)
                obj.hColorIndicatorPanel(ii)=uipanel(...
                    'Parent', obj.hMarkerButtonGroup, ...
                    'Units', 'normalized', ...
                    'Position', [0.02, 0.98-(0.08*ii)+0.01, colIndSize], ...
                    'UserData', ii, ...
                    'FontName', obj.fontName, ...
                    'FontSize', obj.fontSize-1, ...
                    'BackgroundColor', obj.markerTypes(ii).color);
                setColorChangeContextMenu(obj.hColorIndicatorPanel(ii), obj);
            end


            %set up check box
            ii=1;
            obj.hTreeCheckBox = uicontrol(...
                'Parent', obj.hMarkerButtonGroup, ...
                'Units', 'normalized', ...
                'Style','checkbox',...
                'String','',...
                'Value',1,...
                'Position',[0.02 0.98-(0.08*ii)+0.01, 0.06, 0.06],...
                'FontName', obj.fontName,...
                'FontSize', obj.fontSize-1,...
                'Callback', {@treeCheckBoxCallback,obj}, ...
                'BackgroundColor', obj.markerTypes(ii).color);
            for ii=2:numel(obj.markerTypes)
                obj.hTreeCheckBox(ii) = uicontrol(...
                'Parent', obj.hMarkerButtonGroup, ...
                'Units', 'normalized', ...
                'Style','checkbox',...
                'String','',...
                'Value',0,...
                'Position',[0.02 0.98-(0.08*ii)+0.01, 0.06, 0.06],...
                'FontName', obj.fontName,...
                'FontSize', obj.fontSize-1,...
                'Callback', {@treeCheckBoxCallback,obj}, ...
                'BackgroundColor', obj.markerTypes(ii).color);
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

            obj.hTreeSelection(ii).Value=1;
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
                obj.hTreeSelection(ii).Value=1;
                obj.updateMarkerCount(obj.currentType);

            end

            %% Reset Selection
            obj.hTreeSelection(prevSelection).Value=1;

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
        %------------------------------------------------------------------------------------------
        %%  FUNCTIONS



        %------------------------------------------------------------------------------------------
        %Marker addition and deletion
        function UIaddMarker(obj) %Adds a marker to the currently selected tree
            goggleDebugTimingInfo(2, 'NeuriteTracer.UIaddMarker: Beginning',toc,'s')
            newMarker=goggleTreeNode(obj.currentType, obj.deCorrectedCursorX, obj.deCorrectedCursorY, obj.cursorZVoxels);

            goggleDebugTimingInfo(2, 'NeuriteTracer.UIaddMarker: New marker created',toc,'s')

            thisT = obj.selectedTreeIdx;

            if isempty(obj.neuriteTrees{thisT})
                newMarker.branchType='soma';

                obj.neuriteTrees{thisT} = tree(newMarker); %Add first point to tree root
                obj.lastNode(thisT)=1;
            else
                %Append a point 
                [obj.neuriteTrees{thisT},obj.lastNode(obj.selectedTreeIdx)] = ...
                    obj.neuriteTrees{thisT}.addnode(obj.lastNode(obj.selectedTreeIdx),newMarker); 
            end


            goggleDebugTimingInfo(2, 'NeuriteTracer.UIaddMarker: Marker added to collection',toc,'s')
            drawAllTrees(obj)
            goggleDebugTimingInfo(2, 'NeuriteTracer.UIaddMarker: Markers Drawn',toc,'s')

            %% Update count
            obj.incrementMarkerCount(obj.currentType); 

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
            nodes=[obj.neuriteTrees{obj.selectedTreeIdx}.Node{:}];

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
            thisT = obj.selectedTreeIdx;

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

            obj.lastNode(thisT) = obj.neuriteTrees{thisT}.Parent(obj.lastNode(thisT)); %TODO: is this right?
            obj.neuriteTrees{thisT} = obj.neuriteTrees{thisT}.removenode(idx);

            obj.drawAllTrees;

            %% Update count
            obj.decrementMarkerCount(obj.currentType);

            %% Set change flag
            obj.changeFlag=1;
            goggleDebugTimingInfo(2, 'Leaving UIdeleteMarker',toc,'s')
        end


        %------------------------------------------------------------------------------------------
        % Drawing functions

        function drawAllTrees(obj,~,~)
            %Loop through all visible neurite trees that contain data and plot them

            if isempty(obj.neuriteTrees) %If no neurite trees exist we do not attempt to draw
                return
            end

            obj.clearMarkers; %Clear markers from any previous draws
            goggleDebugTimingInfo(2, 'NeuriteTracer.drawTree: Markers cleared',toc,'s')

            hMainImgAx=obj.goggleViewer.hMainImgAx;

            prevhold=ishold(hMainImgAx);
            hold(hMainImgAx, 'on')

            %Set focus to main axes whenever a draw event happens.
            axes(obj.goggleViewer.hMainImgAx); 

            %Loop through all trees and plot
            for thisTreeIdx=1:length(obj.neuriteTrees)
                if ~obj.hTreeCheckBox(thisTreeIdx).Value | isempty(obj.neuriteTrees{thisTreeIdx})
                    continue %skip trees where the checkbox is not ticked or tree is absent
                end

                goggleDebugTimingInfo(2, sprintf(' ***> NeuriteTracer.drawAllTrees: Beginning tree %d',thisTreeIdx),toc,'s')
                obj.currentTree=thisTreeIdx; %This is the tree we are currently plotting, not the user's selected tree

                obj.drawTree
                goggleDebugTimingInfo(2, sprintf(' ***> NeuriteTracer.drawAllTrees: Done with tree %d',thisTreeIdx),toc,'s')
            end

            %% Restore hold state
            if ~prevhold
                hold(hMainImgAx, 'off')
            end

        end

        function drawTree(obj, ~, ~)
        %The main marker-drawing function 

            %% Calculate position and size of nodes
            nodes=[obj.neuriteTrees{obj.currentTree}.Node{:}]; %Get all nodes from the current tree (current neuron)
            allMarkerZVoxel=[nodes.zVoxel]; %z depth of all points from this tree
            allMarkerZRelativeToCurrentPlaneVoxels=abs(allMarkerZVoxel-obj.cursorZVoxels); %Difference between current depth and marker depth


            %Check how many markers are visible from this depth. Remember that not in the current plane are likely 
            %also visible. This will depend on the Z marker diameter setting. 
            zRadius=(gbSetting('neuriteTracer.markerDiameter.z')/2); 
            idx=allMarkerZRelativeToCurrentPlaneVoxels<zRadius; %ones indicate visible and zeros not visible 


            msg=sprintf('Found %d markers within %d planes of this z-plane. %d are in this z-plane.',...
                            length(idx), zRadius, sum(allMarkerZRelativeToCurrentPlaneVoxels==0));
            goggleDebugTimingInfo(2, msg,toc,'s')


            %Search all branches of the tree for nodes that cross the plane. 
            visibleNodeIdx = find(idx); %index of visible nodes in all branches 
            n=1;
            leaves = obj.neuriteTrees{obj.currentTree}.findleaves; %all the leaves of the tree
            goggleDebugTimingInfo(2, sprintf('Found %d leaves',length(leaves)),toc,'s')

            pathToRoot=0; %If 1 we use the brute-force path to root. 
            paths ={};
            if pathToRoot
                for thisLeaf=1:length(leaves)
                    thisPath =  obj.neuriteTrees{obj.currentTree}.findpath(leaves(thisLeaf),1);

                    if any(ismember(thisPath,visibleNodeIdx)) %Does this branch contain indices that are in this z-plane?
                        paths{n}=thisPath; 
                        n=n+1;
                    end
                end

            else
                segments = obj.neuriteTrees{obj.currentTree}.getsegments;
                for ii=1:length(segments)
                    thisPath = segments{ii};
                    if any(ismember(thisPath,visibleNodeIdx)) %Does this branch contain indices that are in this z-plane?
                        paths{n}=thisPath; 
                        n=n+1;
                    end
                end
            end


            if pathToRoot
                %sort the paths by length
                [~,ind]=sort(cellfun(@length,paths),'descend');
                paths=paths(ind)
            end

            %remove points from shorter paths that intersect with the longest path
            %and points outside of the frame. 

            showRemovalDetails=0;
            nRemoved=0;
            for thisPath=length(paths):-1:1

                if pathToRoot
                    initialSize=length(paths{thisPath});
                    if thisPath>1
                        [~,pathInd]=intersect(paths{thisPath},paths{1});

                        %Do not remove if it's the root node only. This would
                        %indicate a branch off the root node and it won't be
                        %joined to the root node if remove it
                        if length(pathInd)==1 & paths{thisPath}(pathInd)==1
                            pathInd=[];
                        end

                        if length(pathInd)>1
                            pathInd(end)=[];
                        end

                        paths{thisPath}(pathInd)=[]; %trim
                    end
                end

                %remove branches or segments that are not in view
                x=[nodes(paths{thisPath}).xVoxel];
                y=[nodes(paths{thisPath}).yVoxel];

                if all(~pointsInView(obj,x,y))
                    paths{thisPath}=[]; %remove branch if none of its nodes are visible
                    nRemoved=nRemoved+1;
                    if ~pathToRoot & showRemovalDetails
                        goggleDebugTimingInfo(2, sprintf('Removed segment %d - out of x/y range',...
                                            thisPath),toc,'s')
                    end
                end

                if pathToRoot
                    if showRemovalDetails
                        goggleDebugTimingInfo(2, sprintf('Trimmed path %d from %d to %d points',...
                            thisPath,initialSize,length(paths{thisPath})),toc,'s')
                    end
                    if isempty(paths{thisPath})
                        paths(thisPath)=[];
                    end
                end

            end % for ii=length(paths):-1:1
            if ~showRemovalDetails & ~pathToRoot
                goggleDebugTimingInfo(2, sprintf('Removed %d segments out of x/y range paths',nRemoved),toc,'s')
            end

            %If no markers are visible from the current z-plane AND in the current view we will not attempt to draw.
            %TODO: This is because we want to draw "shadows" of points not in view if NO points are in the current z-plane.
            if ~any(idx) 
                goggleDebugTimingInfo(2, 'No visible neurites',toc,'s')
                return
            end

            %Paths contains the indices of all nodes in each branch that crosses this plane.
            %Some nodes from a given branch may be out of plane and so not all should be plotted.
            if isempty(paths)
                goggleDebugTimingInfo(2, 'No neurite paths cross this plane',toc,'s')
                return
            end
            goggleDebugTimingInfo(2, 'Found neurite paths that cross this plane',toc,'s')



            % The following loop goes through each candidate branch and finds and plots the points 
            % visible to the current z-plane. 
            hMainImgAx=obj.goggleViewer.hMainImgAx;


            goggleDebugTimingInfo(2, 'NeuriteTracer.drawTree: Beginning drawing',toc,'s')

            %Extract some constants here that we don't need to recalculate each time time in the loop
            markerDimXY=gbSetting('neuriteTracer.markerDiameter.xy');
            markerMinSize=gbSetting('neuriteTracer.minimumSize');
            markerCol=nodes(1).color; %Get the tree's colour from the root node.

            for ii=1:length(paths) %Main drawing loop

                %node indices from the *current* branch (path) that are visible in this z-plane
                %Note: any jumps in the indexing of visiblePathIdx indicate nodes that are not visible from the current plane.
                visiblePathIdx=find(ismember(paths{ii},visibleNodeIdx));
                if isempty(visiblePathIdx)
                    continue %Do not proceed if no nodes are visible from this path
                end

                goggleDebugTimingInfo(2, sprintf('===> Plotting path %d',ii),toc,'s')


                visibleNodesInPathIdx=paths{ii}(visiblePathIdx); %Index values of nodes in the full tree which are also visible nodes

                %Now we can extract the visible nodes and their corresponding relative z positions
                visibleNodesInPath=nodes(visibleNodesInPathIdx); %Extract the visible nodes from the list of all nodes


                goggleDebugTimingInfo(2, sprintf('     Found visible %d nodes in current branch',length(visibleNodesInPathIdx)), toc, 's')


                %embed into a nan vector to handle lines that leave and re-enter the plane
                %this approach replaces points not to be plotted with nans.
                markerX = nan(1,length(paths{ii}));
                markerY = nan(1,length(paths{ii}));
                markerZ = nan(1,length(paths{ii}));
                markerSz = nan(1,length(paths{ii}));
                markerNodeIdx = nan(1,length(paths{ii})); %So we know which node each marker is


                %Make a vector that includes all numbers in the range of visiblePathIdx. e.g. if visiblePathIdx
                %is [2,3,9,10] then markerInd will be [1,2,8,9] so that the middle 5 values remain as NaNs. 
                markerInd = visiblePathIdx-min(visiblePathIdx)+1 ;

                %Populate points that are visible with the correct values
                markerX(markerInd) = [nodes(visibleNodesInPathIdx).xVoxel];
                markerY(markerInd) = [nodes(visibleNodesInPathIdx).yVoxel];
                markerZ(markerInd) = [nodes(visibleNodesInPathIdx).zVoxel];
                markerNodeIdx(markerInd) = visibleNodesInPathIdx;

                [markerX, markerY]=correctXY(obj, markerX, markerY, markerZ); %Shift coords in the event of a section being translation corrected

                visibleNodesInPathRelZ=abs(markerZ-obj.cursorZVoxels);%relative z position of each node
                markerSz=(markerDimXY*(1-visibleNodesInPathRelZ/zRadius)*obj.goggleViewer.mainDisplay.viewPixelSizeOriginalVoxels).^2;
                markerSz=max(markerSz, markerMinSize);

                %% Draw basic markers and lines 
                obj.neuriteTraceHandles(obj.currentTree).hDisplayedLines = ...
                     plot(hMainImgAx, markerX , markerY, '-','color',markerCol,...
                    'Tag', 'NeuriteTracer','HitTest', 'off');
                %goggleDebugTimingInfo(2, '     Plotted trace', toc, 's')

                obj.neuriteTraceHandles(obj.currentTree).hDisplayedMarkers =  ...
                    scatter(hMainImgAx, markerX , markerY, markerSz, markerCol,...
                    'filled', 'HitTest', 'off', 'Tag', 'NeuriteTracer');

                goggleDebugTimingInfo(2, '     Plotted points and lines', toc, 's')


                %Points that are not the root or leaves should all have at least one parent and child. 
                %These may not be be drawn, however, if a parent or child is very far away from the current
                %Z-plane. It would be helpful for the user to know where these out of plane connections are 
                %and to indicate if they are above or below. 

                %Let's start by appending an extra line to all terminal nodes in the current layer that are not leaves
                if isempty(find(leaves==visibleNodesInPathIdx(end)))
                    termNode=visibleNodesInPathIdx(end);
                    x=nodes(termNode).xVoxel;
                    y=nodes(termNode).yVoxel;
                    z=nodes(termNode).zVoxel;
                    childNodes=obj.neuriteTrees{obj.currentTree}.getchildren(termNode);
                    for c=1:length(childNodes)
                        x(2)=nodes(childNodes(c)).xVoxel;
                        y(2)=nodes(childNodes(c)).yVoxel;
                        cZ=nodes(childNodes(c)).zVoxel;

                        if z>cZ
                            lineType='--';
                        elseif z<cZ
                            lineType=':';
                        elseif z==cZ %Just in case there is a point outside of the plot area and on the same layer
                            lineType='-';
                        end
                        plot(hMainImgAx, x,y,lineType,'Tag', 'NeuriteTracer','HitTest', 'off','Color',markerCol); %note, these are cleared by virtue of the tag. No handle is needed.

                        %Only plot text if the child node is out of plane and within the view area
                        if ~strcmp(lineType,'-') & pointsInView(obj,x(2),y(2))
                            text(x(2),y(2),['Z:',num2str(nodes(childNodes(c)).zVoxel)],...
                            'Color',markerCol,'tag','NeuriteTracer','HitTest', 'off') %TODO: target to axes?
                        end
                    end
                end

                %Now we do the corresponding thing for points that are drawn without parents and are not the root node
                %The following fails if a dips out of the plane then comes back in. 
                %Only the first node has the dotted or dashed line. The middle one gets nothing.
                firstNodes=diff(isnan(markerX));
                firstNodes(end+1)=~isnan(markerX(end));
                firstNodes=find(firstNodes>0); %These are the visible nodes on the branch with no plotted parents

                for fN = firstNodes

                    x=markerX(fN);
                    y=markerY(fN);
                    z=markerZ(fN);
                    L=markerNodeIdx(fN);

                    parentNode=obj.neuriteTrees{obj.currentTree}.getparent(L);
                    if parentNode==0 %this is the root node. 
                        continue
                    end
                    pZ=nodes(parentNode).zVoxel;

                    %firstInd is the correct index in markerX/Y but we should only draw the line if
                    %the parent point is in a different depth or out of the field. The reason we need
                    %this test here and didn't for non-leaf terminal nodes because we've trimmed the 
                    %early part of some branches. 


                    if abs(pZ - obj.cursorZVoxels)>zRadius
                        x(2)=nodes(parentNode).xVoxel;
                        y(2)=nodes(parentNode).yVoxel;

                        if z>pZ
                            lineType='--';
                        elseif z<pZ
                            lineType=':';
                        elseif z==pZ
                            lineType='-';
                        end
                        mSize=10;
                        plot(hMainImgAx, x, y, lineType,'Color',markerCol,...
                                'HitTest', 'off','Tag','NeuriteTracer')                        
                        %Only plot text if the child node is out of plane and within the view area
                        if ~strcmp(lineType,'-') & pointsInView(obj,x(2),y(2))
                            text(x(2),y(2),['Z:',num2str(nodes(parentNode).zVoxel)],'Color',markerCol,'tag','NeuriteTracer','HitTest', 'off') %TODO: target to axes?
                        end
                    end
                end %fN = 1:length(firstNode)                   


                %Make leaves have a triangle
                if ~isempty(find(leaves==visibleNodesInPathIdx(end)))
                    mSize = markerSz(1)/10;
                    if mSize<5 %TODO: do not hard-code this. 
                        mSize=5;
                    end
                    if mSize>10 %TODO: hard-coded horribleness
                        lWidth=2;
                    else
                        lWidth=1;
                    end 
                    leafNode = obj.neuriteTrees{obj.currentTree}.Node{visibleNodesInPathIdx(end)};

                    plot(hMainImgAx, leafNode.xVoxel, leafNode.yVoxel,'^w','markerfacecolor',...
                        markerCol,'linewidth',lWidth,'HitTest', 'off','Tag','NeuriteTracer','MarkerSize',mSize) 
                end


                %Overlay a larger, different, symbol over the root node if it's visible
                rootNode = obj.neuriteTrees{obj.currentTree}.Node{1}; %Store the root node somewhere easy to access
                if ~isempty(find(visibleNodesInPathIdx==1))

                    rootNodeInd = find(visibleNodesInPathIdx==1);

                    mSize = markerSz(rootNodeInd)/5;
                    if mSize<5 %TODO: do not hard-code this. 
                        mSize=5;
                    end

                    obj.neuriteTraceHandles(obj.currentTree).hRootNode = plot(hMainImgAx, rootNode.xVoxel, rootNode.yVoxel, 'd',...
                        'MarkerSize', mSize, 'color', 'w', 'MarkerFaceColor',rootNode.color,...
                        'Tag', 'NeuriteTracer','HitTest', 'off', 'LineWidth', median(markerSz)/75);

                end


                %% Draw highlights over points in the plane
                if any(visibleNodesInPathRelZ==0)
                    f=find(visibleNodesInPathRelZ==0);

                    obj.neuriteTraceHandles(obj.currentTree).hDisplayedMarkerHighlights = ...
                            scatter(hMainImgAx, markerX(f), markerY(f), markerSz(f)/4, [1,1,1],...
                            'filled', 'HitTest', 'off', 'Tag', 'NeuriteTracerHighlights');

                end


                %If the node append highlight is on the current branch of the user's selected tree, we attempt to plot it
                if obj.currentTree ~= obj.selectedTreeIdx, continue, end %nothing more to do unless this is the user's current tree

                if ~isempty(find(visibleNodesInPathIdx==obj.lastNode(obj.selectedTreeIdx)))
                    goggleDebugTimingInfo(2, sprintf('Plotting node highlighter on path %d',ii), toc, 's')

                    highlightNode = obj.neuriteTrees{obj.currentTree}.Node{obj.lastNode(obj.selectedTreeIdx)}; %The highlighted node

                    %Get the size of the node 
                    lastNodeInd = find(visibleNodesInPathIdx==obj.lastNode(obj.selectedTreeIdx));

                    %Calculate marker size. 
                    %TODO: use the markerNodeIdx vector to neaten the size calculation 
                    lastNodeRelZ=abs(highlightNode.zVoxel-obj.cursorZVoxels);
                    mSize=(markerDimXY*(1-lastNodeRelZ/zRadius)*obj.goggleViewer.mainDisplay.viewPixelSizeOriginalVoxels).^2;
                    mSize = mSize/10;
                    if mSize<5
                        mSize=7;
                    end

                    obj.neuriteTraceHandles(obj.selectedTreeIdx).hHighlightedMarker = ...
                        plot(hMainImgAx, highlightNode.xVoxel, highlightNode.yVoxel,...
                        'or', 'markersize', mSize, 'LineWidth', 2,...
                        'Tag','LastNode','HitTest', 'off'); 

                    % If possible, enable the meta-data boxes so the user can edit the properties of the selected tree node
                    if isa(rootNode,'goggleTreeNode') & obj.lastNode(obj.selectedTreeIdx)>1
                        obj.toggleNodeModifers('on')
                    else
                        obj.toggleNodeModifers('off')
                    end

                end



            end %close paths{ii} loop

        end %function drawTree(obj, ~, ~)

        function highlightMarker(obj)       
            tic

            idx = findMarkerNearestToCursor(obj);
            if isempty(idx)
                return
            else
                %Now we set the last node to be the highlighted node. Allows for branching.
                obj.lastNode(obj.selectedTreeIdx)=idx;
            end


            lastNodeObj = findobj(obj.goggleViewer.hMainImgAx, 'Tag', 'LastNode') ;
            verbose=1;
            if ~isempty(lastNodeObj) %The tree has not been changed and the marker only moved
                thisMarker = obj.neuriteTrees{obj.selectedTreeIdx}.Node{idx};
                set(obj.neuriteTraceHandles(obj.selectedTreeIdx).hHighlightedMarker,...
                 'XData', thisMarker.xVoxel,...
                 'YData', thisMarker.yVoxel);
                if verbose, goggleDebugTimingInfo(2, sprintf('Moved lastnode marker to node %d',idx),toc,'s'), end

                % If possible, enable the meta-data boxes so the user can edit the properties of the selected tree node
                if isa(obj.neuriteTrees{obj.selectedTreeIdx}.Node{1},'goggleTreeNode') & idx>1
                    obj.toggleNodeModifers('on')
                else
                    obj.toggleNodeModifers('off')
                end

            else %The tree has been changed so we re-draw it
                drawAllTrees(obj)
            end

            %If the class of the node is appropriate and it's a not a root node, we should update the UI
            %to reflect the node properties
            if isa(obj.neuriteTrees{obj.selectedTreeIdx}.Node{1},'goggleTreeNode') & idx>1
                set(obj.hIsTerminated,'Value', obj.neuriteTrees{obj.selectedTreeIdx}.Node{idx}.isPrematureTermination);
                bT=obj.neuriteTrees{obj.selectedTreeIdx}.Node{idx}.branchType;
                if strcmp(bT,'axon')
                    set(obj.hAxon,'Value',1)
                elseif strcmp(bT,'dendrite')
                    set(obj.hDendrite,'Value',1)
                end
            end


        end


        function clearMarkers(obj)
            %clear all trees and markers if any tree is present
            if isempty(obj.neuriteTraceHandles)
                return
            end

            if any(~isempty([obj.neuriteTraceHandles.hDisplayedMarkers]))
                delete(findobj(obj.goggleViewer.hMainImgAx, 'Tag', 'NeuriteTracer'))
            end
            if any(~isempty([obj.neuriteTraceHandles.hDisplayedMarkerHighlights]))
                delete(findobj(obj.goggleViewer.hMainImgAx, 'Tag', 'NeuriteTracerHighlights'))
            end
            if  any(~isempty([obj.neuriteTraceHandles.hHighlightedMarker]))
                 delete(findobj(obj.goggleViewer.hMainImgAx, 'Tag', 'LastNode'))
            end
        end


        %Returns the index of the tree which the user has selected with the radio buttons
        function treeIdx = userSelectedTreeIdx(obj)
            cType = obj.currentType;
            treeIdx = strmatch(cType.name, {obj.markerTypes(:).name});
        end


        %------------------------------------------------------------------------------------------
        % Navigation functions
        function goToCurrentRootNode(obj,~,~)
            %Go to the layer that contains the root node of the currently selected tree
            %see also: obj.keyPress
            selectedIDX = obj.userSelectedTreeIdx;

            deltaZ=obj.neuriteTrees{selectedIDX}.Node{1}.zVoxel-obj.goggleViewer.mainDisplay.currentIndex;

            %Seek to this z-depth TODO: is this the best way?
            stdout=obj.goggleViewer.mainDisplay.seekZ(deltaZ); 
            if stdout
                obj.goggleViewer.mainDisplay.updateZoomedView;
            end

            obj.goggleViewer.centreViewOnCoordinate(obj.neuriteTrees{selectedIDX}.Node{1}.xVoxel, obj.neuriteTrees{selectedIDX}.Node{1}.yVoxel);

        end


        %------------------------------------------------------------------------------------------
        %Marker count functions
        function updateMarkerCount(obj, markerTypeToUpdate)
            %Count the total number of nodes for marker type markerTypeToUpdate

            if all(cellfun(@isempty, obj.neuriteTrees)) %there are no marker trees loaded
                return
            end

            num=[];
            for ii=1:length(obj.neuriteTrees)
                thisTree=obj.neuriteTrees{ii};
                if isempty(thisTree), continue, end
                thisType = thisTree.Node{1}.type;

                if thisType == markerTypeToUpdate
                    num = length(thisTree.Node);           
                end

            end

            if isempty(num)
                return
            end

            idx=find(obj.markerTypes==markerTypeToUpdate);

            if isempty(idx)
                fprintf('Failed to find marker type to update counter')
                return
            end

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


        %------------------------------------------------------------------------------------------
        %UI control functions
        function toggleNodeModifers(obj,enable)
            %whether to enable or disable the node modifer UI elements. 
            %they should only be enabled if we've selected a node that has meta-data that can be set.
            %i.e. that it's a goggleTreeNode and not a root node

            if ~isstr(enable)
                error('enable should be a string')
            end

            if ~strcmpi('off',enable) & ~strcmpi('on',enable) 
                error('enable should be the strings on or off')
            end

            set(obj.hIsTerminated,'enable',enable)
            set(obj.hDendrite,'enable',enable)
            set(obj.hAxon,'enable',enable)
        end


        %--------------------------------------------------------------------------------------
        %% Getters
        function mType=get.currentType(obj)
            mType=obj.markerTypes(obj.hMarkerButtonGroup.SelectedObject.UserData);
        end

        function idx=get.selectedTreeIdx(obj) %The index of the currently selected tree
            idx=obj.hMarkerButtonGroup.SelectedObject.UserData;
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

    updateMarkerTypeUISelections(obj); %Confirm that we need this. 

    obj.neuriteTrees=m;
    for ii=1:length(obj.neuriteTrees)
        if ~isempty(obj.neuriteTrees{ii}) %if neurite tree is present
            obj.lastNode(ii)=length(obj.neuriteTrees{ii}.Node); %set highlight (append) node to last point in tree
            obj.lastNode(ii)=1;

            obj.hTreeCheckBox(ii).Value=1; %enable check box 
            obj.updateMarkerCount(obj.neuriteTrees{ii}.Node{1}.type)  %Set marker count
        else
            obj.hTreeCheckBox(ii).Value=0;
        end
    end

    if length(obj.neuriteTrees)<obj.maxNeuriteTrees
        obj.neuriteTrees{obj.maxNeuriteTrees}=[];
    elseif length(obj.neuriteTrees)>obj.maxNeuriteTrees
        obj.maxNeuriteTrees=length(obj.neuriteTrees); 
    end

    %Go to cell body of first available trace
    presentTraces=find(~cellfun(@isempty,obj.neuriteTrees));
    if isempty(presentTraces)
        fprintf('NO DATA PRESENT. Quitting import function!\n')
        return
    end
    ind = presentTraces(1);
    obj.hTreeSelection(ind).Value=1; %Set radio button to match what is selected
    obj.goToCurrentRootNode; %This will perform an obj.drawAllTrees

end

function treeRadioSelectCallback(~, ~, obj)
    tic
    obj.hTreeCheckBox(obj.userSelectedTreeIdx).Value=1;%enable tree when user selects it
    obj.drawAllTrees
end

function treeCheckBoxCallback(~, ~, obj)
    tic
    obj.drawAllTrees
end

function prematureCallback(~,~,obj)
    % Set this node as being a premature termination 
    % The checkbox is disabled if the tree is not composed of goggleTreeNodes 
    % or if the selected node is the root node
    selectedNode = obj.lastNode(obj.selectedTreeIdx);
    obj.neuriteTrees{obj.selectedTreeIdx}.Node{selectedNode}.isPrematureTermination = get(obj.hIsTerminated,'Value');
end


function neuriteTypeCallback(~,~,obj)
    % Set all nodes on this branch (to the root and to all leaves) to the radio-button choice
    if get(obj.hAxon,'Value')
        neuriteName='axon';
    elseif get(obj.hDendrite,'Value')
        neuriteName='dendrite';
    else
        neuriteName='';
    end

    tic
    selectedNode = obj.lastNode(obj.selectedTreeIdx);
    leavesOnThisBranch = obj.neuriteTrees{obj.selectedTreeIdx}.findleaves(selectedNode);

    for ii=1:length(leavesOnThisBranch)
        p=obj.neuriteTrees{obj.selectedTreeIdx}.pathtoroot(leavesOnThisBranch(ii));
        p(end)=[];%remove the root node
        for n=1:length(p)
            obj.neuriteTrees{obj.selectedTreeIdx}.Node{p(n)}.branchType=neuriteName;
        end
    end
    goggleDebugTimingInfo(2, ['Setting neurite type to ',neuriteName], toc, 's')


end


%% Utilities
function ms=defaultMarkerTypes(nTypes)
    ms(nTypes)=goggleMarkerType;
    cols=lines(nTypes);
    for ii=1:nTypes
        ms(ii).name=sprintf('Tree%u', ii);
        ms(ii).color=cols(ii, :);
    end
end

%which points are in the x/y view (may still be in a different z plane)
function varargout = pointsInView(obj,xPoints,yPoints)
    %Inputs
    %obj - the goggleViewer object
    %xPoints and yPoints are scalars or vectors of points to be tested WRT to the first 2 args
    %Outputs
    %If two outputs: inViewX and inViewY vectors 
    %If 0 or 1 arguments, we return which points are in view in both dims

    xView=obj.goggleViewer.mainDisplay.viewXLimOriginalCoords;
    yView=obj.goggleViewer.mainDisplay.viewYLimOriginalCoords;

    inViewX = xPoints>=xView(1) & xPoints<=xView(2);
    inViewY = yPoints>=yView(1) & yPoints<=yView(2);

    if nargout<=1
        varargout{1} = (inViewX & inViewY);
    end
    if nargout==2
        varargout{1} = inViewX;
        varargout{2} = inViewY;
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
    %executes defined callbacks when the user presses particular buttons. n
    key=eventdata.Key;
    key=strrep(key, 'numpad', '');

    ctrlMod=ismember('control', eventdata.Modifier);

    switch key
        case {'1' '2' '3' '4' '5' '6' '7' '8' '9'}
            obj.hTreeSelection(str2double(key)).Value=1;
        case {'0'}
            obj.hTreeSelection(10).Value=1;
        case 'a' %add mode
            if ctrlMod
                obj.hModeAdd.Value=1;
            end
        case 'd' %delete mode
            if ctrlMod
                obj.hModeDelete.Value=1;
            end
        case 'r' %go to root node of currently selected tree
            obj.goToCurrentRootNode
    end %switch key

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
    parentObj.drawAllTrees;
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
    parentObject.drawAllTrees();
end
