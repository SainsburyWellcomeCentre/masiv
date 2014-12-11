classdef goggleSlicePreLoader<goggleBoxPlugin
    properties
        parent
        nBefore
        nAfter
        hFig
        
        hEnabledCheckBox
        
        hViewChangedListener
        hClosingListener
        hKeyboardListener
    end
    
    methods
        function obj=goggleSlicePreLoader(caller, ~)
            switch class(caller)
                case 'goggleViewer'
                    obj.parent=caller;
                otherwise
                    obj.parent=caller.UserData;
            end
            %% Settings
            try
                gbSetting('preLoader');
            catch
                gbSetting('preLoader.nBefore', 10)
                gbSetting('preLoader.nAfter', 10)
                gbSetting('preLoader.position', [1000 500 200 200]);
            end
            obj.hFig=figure(...
                'Position',gbSetting('preLoader.position') , ...
                'MenuBar', 'none', 'NumberTitle', 'off', ...
                'Color', gbSetting('viewer.mainBkgdColor'), ...
                'Resize', 'off', 'Name', 'PreLoader', ...
                'CloseRequestFcn', {@closeReqFcn, obj}, ...
                'KeyPressFcn', {@keyPress, obj});
                
            
           setUpSettingBox('Before:', 'preLoader.nBefore', 0.5, obj, 'nBefore')
           setUpSettingBox('After:', 'preLoader.nAfter', 0.35, obj, 'nAfter')
           
           uicontrol(...
               'Style', 'pushbutton', ...
               'Parent', obj.hFig, ...
               'Units', 'normalized', ...
               'Position', [0.5 0.05 0.45 0.15], ...
               'HorizontalAlignment', 'left', ...
               'FontName', gbSetting('font.name'), ...
               'FontSize', gbSetting('font.size'), ...
               'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
               'ForegroundColor', gbSetting('viewer.textMainColor'), ...
               'String', 'Close', ...
               'Callback', {@closeReqFcn, obj});
           
           obj.hEnabledCheckBox=uicontrol(...
               'Style', 'checkbox', ...
               'Parent', obj.hFig, ...
               'Units', 'normalized', ...
               'Position', [0.6 0.7 0.35 0.15], ...
               'HorizontalAlignment', 'center', ...
               'FontName', gbSetting('font.name'), ...
               'FontSize', gbSetting('font.size')+1, ...
               'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
               'ForegroundColor', gbSetting('viewer.textMainColor'), ...
               'String', 'Enable (p)', ...
               'Value', 1, ...
               'Callback', {@enabledCheckboxValueChange, obj});

           obj.hViewChangedListener=event.listener(obj.parent, 'ViewChanged', @obj.viewChangedListenerCallback);
           obj.hClosingListener=event.listener(obj.parent, 'ViewerClosing', @obj.viewerClosingListenerCallback);
           obj.hKeyboardListener=event.listener(obj.parent, 'KeyPress', @obj.handleMainWindowKeyPress);
           
           obj.viewChangedListenerCallback;
        end
        
        function doPreLoading(obj)
            if obj.hEnabledCheckBox.Value
                
                goggleDebugTimingInfo(1, 'PreLoader: starting', toc, 's')
                
                currentView_spec=getCurrentView(obj);                
                newViewsToCreate_spec=createNewViewSpecs(obj, currentView_spec);                
                newViewsToCreate_spec=excludeViewSpecsMatchingAlreadyLoadedGZV(obj, newViewsToCreate_spec);                
                newViewsToCreate_spec=sortByDistanceFromCurrentPlace(newViewsToCreate_spec, currentView_spec);
                
                goggleDebugTimingInfo(1, 'PreLoader: Views to create calculated', toc, 's')
                
                if ~isempty(newViewsToCreate_spec)
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

        function deleteObj(obj)
            gbSetting('preLoader.position', obj.hFig.Position)
            delete(obj.hFig)
            delete(obj)
        end
    end
    
    %% Listener Callbacks
    methods(Access=protected)
        function viewChangedListenerCallback(obj, ~,~)
            if obj.parent.mainDisplay.zoomedViewNeeded
                obj.doPreLoading
            end
        end
        function viewerClosingListenerCallback(obj, ~,~)
            obj.deleteObj();
        end
        function handleMainWindowKeyPress(obj, ~,ev)
            keyPress([], ev.KeyPressData, obj)
        end
        
    end
    
    %% Display String
    methods(Static)
        function d=displayString()
            d='PreLoader...';
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
    end
end

%% Settings changes
function setUpSettingBox(displayName, settingName, yPosition, parentObject, objectFieldName)
    fn=gbSetting('font.name');
    fs=gbSetting('font.size');
    
    hEdit=uicontrol(...
        'Style', 'edit', ...
        'Parent', parentObject.hFig, ...
        'Units', 'normalized', ...
        'Position', [0.5 yPosition 0.45 0.12], ...
        'FontName', fn, ...
        'FontSize', fs, ...
        'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
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
        'Parent', parentObject.hFig, ...
        'Units', 'normalized', ...
        'Position', [0.02 yPosition+0.02 0.46 0.07], ...
        'HorizontalAlignment', 'right', ...
        'FontName', fn, ...
        'FontSize', fs-1, ...
        'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
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
    z=obj.parent.overviewDSS.idx(currentViewZIdx+[-obj.nBefore:-1 1:obj.nAfter]);
end

function specsToCreate=excludeViewSpecsMatchingAlreadyLoadedGZV(obj,specsToCreate)    
    viewsInMemory_spec=getLoadedViewSpecs(obj);
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
    
    %% Create new view
    newView=obj.parent.mainDisplay.zoomedViewManager.createNewView(spec.region,spec.Z, spec.DS);
   
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

function v=checkForMatchingView(viewSpec, viewsInMemory)

    xMatch=(cellfun(@min, viewsInMemory.X)<=viewSpec.X(1))&(cellfun(@max, viewsInMemory.X)>=viewSpec.X(2));
    yMatch=(cellfun(@min, viewsInMemory.Y)<=viewSpec.Y(1))&(cellfun(@max, viewsInMemory.Y)>=viewSpec.Y(2));
    v= (xMatch & ...
        yMatch & ...
        viewSpec.Z==viewsInMemory.Z & ...
        viewSpec.DS==viewsInMemory.DS);
    
    v=~isempty(find(v, 1));
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

function closeReqFcn(~,~,obj)
    obj.deleteObj;
end

