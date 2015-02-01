classdef gogglePreLoader<handle
    properties
        parent
        position
        
        nBefore
        nAfter
        hMainPanel
        
        hEnabledCheckBox
        
        hViewChangedListener
        hKeyboardListener
    end
    
    methods
        function obj=gogglePreLoader(parent, position)
            obj.parent=parent;
            obj.position=position;
            %% Settings
            try
                gbSetting('preLoader');
            catch
                gbSetting('preLoader.nBefore', 10)
                gbSetting('preLoader.nAfter', 10)
                gbSetting('preLoader.position', [1000 500 200 200]);
            end
            obj.hMainPanel=uipanel(...
                'Units', 'normalized', ...
                'Position',obj.position , ...
                'BackgroundColor', gbSetting('viewer.panelBkgdColor'), ...
                'HitTest', 'off');
                
             uicontrol(...
                'Parent', obj.hMainPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.02 0.8 0.96 0.15], ...
                'FontSize',gbSetting('font.size'), ...
                'FontName', gbSetting('font.name'), ...
                'FontWeight', 'bold', ...
                'String', 'Z-PreCaching', ...
                'HorizontalAlignment', 'center', ...
                'BackgroundColor', gbSetting('viewer.panelBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'), ...
                'HitTest', 'off');
            
           setUpSettingBox('Before:', 'preLoader.nBefore', 0.35, obj, 'nBefore')
           setUpSettingBox('After:', 'preLoader.nAfter', 0.05, obj, 'nAfter')
           
           
           obj.hEnabledCheckBox=uicontrol(...
               'Style', 'checkbox', ...
               'Parent', obj.hMainPanel, ...
               'Units', 'normalized', ...
               'Position', [0.05 0.4 0.45 0.15], ...
               'HorizontalAlignment', 'center', ...
               'FontName', gbSetting('font.name'), ...
               'FontSize', gbSetting('font.size')+1, ...
               'BackgroundColor', gbSetting('viewer.panelBkgdColor'), ...
               'ForegroundColor', gbSetting('viewer.textMainColor'), ...
               'String', 'Enable (p)', ...
               'Value', 0, ...
               'Callback', {@enabledCheckboxValueChange, obj});

           obj.hViewChangedListener=event.listener(obj.parent, 'ViewChanged', @obj.viewChangedListenerCallback);
           obj.hKeyboardListener=event.listener(obj.parent, 'KeyPress', @obj.handleMainWindowKeyPress);
           
           obj.viewChangedListenerCallback;
        end
        
        function doPreLoading(obj)
            if obj.hEnabledCheckBox.Value
                
                goggleDebugTimingInfo(1, 'PreLoader: starting', toc, 's')
                
                currentView_spec=getCurrentView(obj);                                                 
                newViewsToCreate_spec=createNewViewSpecs(obj, currentView_spec);
                newViewsToCreate_spec=excludeViewSpecsMatchingAlreadyLoadedGZV(obj, newViewsToCreate_spec);    
                 goggleDebugTimingInfo(1, 'PreLoader: Views to create calculated', toc, 's')
                 
                
               
                
                if ~isempty(newViewsToCreate_spec)
                    newViewsToCreate_spec=sortByDistanceFromCurrentPlace(newViewsToCreate_spec, currentView_spec);
                    % Initialise
                    newViews(numel(newViewsToCreate_spec))=goggleZoomedView;
                    
                    for ii=1:numel(newViewsToCreate_spec)
                        newViews(ii)=createGZV(obj, newViewsToCreate_spec(ii));
                        startLoading(newViews(ii));
                        prepareTimer(newViews(ii), 1);
                    end
                    
                    goggleDebugTimingInfo(1, 'PreLoader: Views created', toc, 's')
                    addNewViewsToZVMArray(obj, newViews)
                    
                    for ii=1:numel(newViews)
                        start(newViews(ii).checkForLoadedImageTimer);
                    end
                    goggleDebugTimingInfo(1, 'PreLoader: All timers started', toc, 's')
                else
                    goggleDebugTimingInfo(1, 'PreLoader: All views in memory', toc, 's')
                end
                
            end
        end
        %% Destructor
        function delete(obj)
            delete(obj.hMainPanel)
        end
    end
    
    %% Listener Callbacks
    methods(Access=protected)
        function viewChangedListenerCallback(obj, ~,~)
            if obj.parent.mainDisplay.zoomedViewNeeded
                obj.doPreLoading
            end
        end
        function handleMainWindowKeyPress(obj, ~,ev)
            keyPress([], ev.KeyPressData, obj)
        end
        
    end
end

%% Other callbacks
function enabledCheckboxValueChange(chckbx, ~, parentObj)
    if chckbx.Value
        parentObj.doPreLoading;
    end
end

function keyPress(~, eventdata, obj)
    key=eventdata.Key;
    ctrlMod=ismember('control', eventdata.Modifier);
    
    if strcmp(key, 'p') && ~ctrlMod
        obj.hEnabledCheckBox.Value=~obj.hEnabledCheckBox.Value;
        enabledCheckboxValueChange(obj.hEnabledCheckBox, [], obj)
    end
end

%% Settings changes
function setUpSettingBox(displayName, settingName, yPosition, parentObject, objectFieldName)
    fn=gbSetting('font.name');
    fs=gbSetting('font.size');
    
    hEdit=uicontrol(...
        'Style', 'edit', ...
        'Parent', parentObject.hMainPanel, ...
        'Units', 'normalized', ...
        'Position', [0.76 yPosition 0.2 0.24], ...
        'FontName', fn, ...
        'FontSize', fs, ...
        'BackgroundColor', gbSetting('viewer.panelBkgdColor'), ...
        'ForegroundColor', gbSetting('viewer.textMainColor'), ...
        'UserData', settingName);
    
    hEdit.String=num2str(gbSetting(settingName));
    if nargin>4 && ~isempty(objectFieldName)
        hEdit.Callback={@checkAndUpdateNewNumericSetting, parentObject, objectFieldName};
        parentObject.(objectFieldName)=gbSetting(settingName);
    else
         hEdit.Callback=@checkAndUpdateNewNumericSetting;
    end
    
    uicontrol(...
        'Style', 'text', ...
        'Parent', parentObject.hMainPanel, ...
        'Units', 'normalized', ...
        'Position', [0.5 yPosition+0.04 0.24 0.14], ...
        'HorizontalAlignment', 'right', ...
        'FontName', fn, ...
        'FontSize', fs-1, ...
        'BackgroundColor', gbSetting('viewer.panelBkgdColor'), ...
        'ForegroundColor', gbSetting('viewer.textMainColor'), ...
        'String', displayName);

end

function checkAndUpdateNewNumericSetting(obj,ev, parentObject, fieldName)
    numEquiv=(str2num(ev.Source.String)); %#ok<ST2NM>
    if ~isempty(numEquiv)
        gbSetting(obj.UserData, numEquiv)
        if nargin>3&&~isempty(fieldName)
            parentObject.(fieldName)=numEquiv;
        end
    else
        obj.String=num2str(gbSetting(obj.UserData));
    end
end

%% View spec calculations

function v=getCurrentView(obj)
    gDisplay=obj.parent.mainDisplay;
    
    v.X=xlim(gDisplay.axes);
    v.Y=ylim(gDisplay.axes);
    v.Z=gDisplay.currentZPlaneOriginalVoxels;
    v.DS=gDisplay.downSamplingForCurrentZoomLevel;   
    
end

function newViews_spec=createNewViewSpecs(obj, currentViewSpec)
     
    % Work out which Z voxels will be needed
    sliceZ=calculateZVoxels_ofSlicesToLoad(obj, currentViewSpec.Z);
    % Pre-initialise
    newViews_spec=repmat(currentViewSpec, numel(sliceZ), 1);
    
    for ii=1:numel(sliceZ)
         %% Set up new spec: same as old spec, but with a different Z.
         newViews_spec(ii).Z=sliceZ(ii);
         newViews_spec(ii).region=[floor(newViews_spec(ii).X(1)) floor(newViews_spec(ii).Y(1))...
                                    ceil(range(newViews_spec(ii).X)) ceil(range(newViews_spec(ii).Y))];
     end
     
end

function z=calculateZVoxels_ofSlicesToLoad(obj, currentViewZ)
    % Converts number of slices before and after in to original voxel
    % address in Z, so it's easy to find the right file
    currentViewZIdx=find(obj.parent.overviewDSS.idx==currentViewZ);
    idx=currentViewZIdx+[-obj.nBefore:-1 1:obj.nAfter];
    idx(idx<1 | idx>obj.parent.overviewDSS.idx(end))=[]; %remove index values that aren't real
    z=obj.parent.overviewDSS.idx(idx);
end

function specsToCreate=excludeViewSpecsMatchingAlreadyLoadedGZV(obj,specsToCreate) 
    goggleDebugTimingInfo(1, 'PreLoader: Checking for existing matching views', toc, 's')
    viewsInMemory_spec=getLoadedViewSpecs(obj);
    goggleDebugTimingInfo(1, 'PreLoader: existing matching viewspecs retrieved', toc, 's')
    specsThatAlreadyExist=[];
    
    for ii=1:numel(specsToCreate)
        if checkForMatchingView(clipRegionSpecBorder(specsToCreate(ii)), viewsInMemory_spec)
            specsThatAlreadyExist=[specsThatAlreadyExist ii]; %#ok<AGROW>
        end
    end
    specsToCreate(specsThatAlreadyExist)=[];
end

function newViewsToCreate_spec=sortByDistanceFromCurrentPlace(newViewsToCreate_spec, currentView_spec)
    [~, sortOrder]=sort(abs([newViewsToCreate_spec.Z]-currentView_spec.Z));
    newViewsToCreate_spec=newViewsToCreate_spec(sortOrder);
end

%% New view creation and loading
function newView=createGZV(obj, spec)
    
    updateFcn={@updateIfShowingThisZoomedView, obj, 'newObj'};
    
    %% Create new view
    newView=obj.parent.mainDisplay.zoomedViewManager.createNewView(spec.region,spec.Z, spec.DS, updateFcn);
   
end

function startLoading(gv)
     %% Load in background
    gv.backgroundLoad([], 0)
end

function prepareTimer(gv, timerDelay)
    gv.checkForLoadedImageTimer.StartDelay=timerDelay; %1 second lockout stops the fucker jamming
end

function addNewViewsToZVMArray(obj, newViews)
    zvm=obj.parent.mainDisplay.zoomedViewManager;
    zvm.addViewsToArray(newViews);
end

%% Region spec
function v=clipRegionSpecBorder(v)
%% Allow a slightly smaller image (5xdownsampling) to be considered a match
    %    (Takes care of rounding errors)
    allowablePixelsSmallerThanView=5*v.DS;
    v.X=v.X+[1 -1]*allowablePixelsSmallerThanView;
    v.Y=v.Y+[1 -1]*allowablePixelsSmallerThanView;
    
    v.X=round(v.X);
    v.Y=round(v.Y);
end

function v=getLoadedViewSpecs(obj)
    gDisplayManager=obj.parent.mainDisplay.zoomedViewManager;

    v.X=gDisplayManager.planesInMemX;
    v.Y=gDisplayManager.planesInMemY;
    v.Z=gDisplayManager.planesInMemZ;
    v.DS=gDisplayManager.planesInMemDS;

end

function vIdx=checkForMatchingView(viewSpec, viewsInMemory)
    zMatch=find(viewSpec.Z==viewsInMemory.Z);
    if any(zMatch)
        inMemX=viewsInMemory.X(zMatch);
        xzMatch=find(cellfun(@min, inMemX)<=viewSpec.X(1))&(cellfun(@max, inMemX)>=viewSpec.X(2));
        if any(xzMatch)
            inMemY=viewsInMemory.Y(zMatch);
            yxzMatch=find(cellfun(@min, inMemY)<=viewSpec.Y(1))&(cellfun(@max, inMemY)>=viewSpec.Y(2));
            if any(yxzMatch)
                dsyxzMatch=find(viewSpec.DS==viewsInMemory.DS(zMatch));
                if any(dsyxzMatch)
                    vIdx=zMatch(xzMatch(yxzMatch(dsyxzMatch(1))));
                else
                    vIdx=[];
                end
            else
                vIdx=[];
            end
        else
            vIdx=[];
        end
    else
        vIdx=[];
    end
end

%% Utility functions

function n=getNumericInput(prompt, title)
    n=inputdlg(prompt, title, 1, {'10'});
    if isempty(n)
        n=-1;
    else
        n=str2double(n);
        if isnan(n)
            n=getNumericInput(prompt, title);
        end
    end
end

%% Created view updater

function updateIfShowingThisZoomedView(obj, newlyCreatedGZV)
    zvm=obj.parent.mainDisplay.zoomedViewManager;
    mainDisplay=obj.parent.mainDisplay;
    
    if mainDisplay.currentZPlaneOriginalVoxels==newlyCreatedGZV.z
        zvm.updateView()
    end

end
