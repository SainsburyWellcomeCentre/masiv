classdef masivZoomedViewManager<handle
    %TODO: document what this does

    properties(SetAccess=protected)
        currentImageFilePath

        zoomedViewArray
        planesInMemX
        planesInMemY
        planesInMemZ
        planesInMemDS
    end
    properties(SetAccess=protected)
        parentViewerDisplay
        hImg
        currentSliceFileExistsOnDiskCache
    end
    properties(SetAccess=protected, Dependent)
        cacheMemoryUsed
        currentSliceFileName
        currentSliceFileFullPath
        currentSliceFileExistsOnDisk
        imageVisible
        currentImageViewData
    end
    properties 
        imageProcessingPipeline
        xyPositionAdjustProfile=[];
    end


    methods
        %% Constructor
        function obj=masivZoomedViewManager(parentViewerDisplay)
            obj.parentViewerDisplay=parentViewerDisplay;
        end

        %% View updates
        function updateView(obj)
            obj.currentSliceFileExistsOnDiskCache=[];
            v=findMatchingView(obj);
            if isempty(v)
                masivDebugTimingInfo(2, 'mZVM.updateView: Creating new view...', toc,'s')
                try
                    stdout=obj.createNewViewForCurrentView;
                    if stdout==0
                        obj.hide
                    end
                catch err
                    if strcmp(err.identifier, 'ZVM:couldNotFindFile')
                        masivDebugTimingInfo(0, strrep(err.message,  'ZoomedViewManager: ', 'WARNING IN mZVM.updateView: '), toc,'s')
                        obj.hImg.Visible='off';
                    else
                        rethrow(err)
                    end
                end
            else
                masivDebugTimingInfo(2, ['mZVM.updateView: Matching views found: ' sprintf('%u, ', v)],toc,'s')
                masivDebugTimingInfo(2, sprintf('mZVM.updateView: View #%u will be used. Updating image...', v(1)),toc,'s')
                updateImage(obj, v(1))
            end
        end

        function v=createNewView(obj, regionSpec, z, ds, loadedCallback)
            % Constructs the file path from spec and creates a GZV object
            if nargin<5
                loadedCallback=[];
            end

                masivDebugTimingInfo(2, 'mZVM.createNewView: Zoomed view creation starting',toc,'s')
            basedir=obj.parentViewerDisplay.overviewStack.MetaObject.imageBaseDirectory;
            f=obj.parentViewerDisplay.overviewStack.originalImageFilePaths{z};            
            fp=fullfile(basedir, f);  

            if ~isempty(obj.xyPositionAdjustProfile)
                offset=(obj.xyPositionAdjustProfile(z, :));
            else
                offset=[0 0];
            end

            v=masivZoomedView(fp, regionSpec, ds, z, obj, ...
                                'completedFcn', loadedCallback,...
                                'processingFcns', obj.imageProcessingPipeline, ...
                                'positionAdjustment', offset);
                masivDebugTimingInfo(2, 'mZVM.createNewView: Zoomed view created',toc,'s')
        end

        function stdout=createNewViewForCurrentView(obj)
             if obj.currentSliceFileExistsOnDisk

                parent=obj.parentViewerDisplay;

                regionSpec=getRegionSpecFromParent(parent);
                ds=parent.downSamplingForCurrentZoomLevel;
                z=parent.currentZPlaneOriginalVoxels;

                loadedCallback=@() obj.updateView();

                v=obj.createNewView(regionSpec,z, ds, loadedCallback);  
                if ~isempty(v)
                    stdout=1;
                    obj.addViewsToArray(v)
                    v.backgroundLoad;
                else
                    stdout=0;
                end
                obj.cleanUpCache();
             else
                 stdout=0;
             end
        end

        function addViewsToArray(obj, v)
            obj.reduceToCacheLimit()
            if ~isempty(obj.zoomedViewArray)
                obj.zoomedViewArray=[v obj.zoomedViewArray];
            else
                obj.zoomedViewArray=v;
            end
        end

        function hide(obj)
            obj.hImg.Visible='off';
        end

        %% Cache functions
        function cleanUpCache(obj)
            obj.reduceToCacheLimit();
        end

        function clearCache(obj)
            obj.zoomedViewArray=masivZoomedView;
            obj.updateView();
        end

        %% Getters
        function csfn=get.currentSliceFileName(obj)
            stitchedFileNameList=obj.parentViewerDisplay.overviewStack.originalImageFilePaths;
            indexInFileNameList=obj.parentViewerDisplay.currentZPlaneOriginalVoxels;
            csfn=stitchedFileNameList{indexInFileNameList};
        end
        function csfp=get.currentSliceFileFullPath(obj)
            baseDir=obj.parentViewerDisplay.overviewStack.MetaObject.imageBaseDirectory;
            csfn=obj.currentSliceFileName;

            csfp=fullfile(baseDir, csfn);
        end
        function fileOnDisk=get.currentSliceFileExistsOnDisk(obj)
            if isempty(obj.currentSliceFileExistsOnDiskCache)
                obj.currentSliceFileExistsOnDiskCache=exist(obj.currentSliceFileFullPath, 'file');
            end
            fileOnDisk=obj.currentSliceFileExistsOnDiskCache;
        end
        function imgVis=get.imageVisible(obj)
            imgVis=~isempty(obj.hImg)&&strcmp(obj.hImg.Visible, 'on');
        end
        function cData=get.currentImageViewData(obj)
            cData=obj.hImg.CData;
        end
        function cmem=get.cacheMemoryUsed(obj)
            if ~isempty(obj.zoomedViewArray)
                cmem=sum([obj.zoomedViewArray.sizeMiB]);
            else
                cmem=0;
            end
        end

        %% Setters
        function set.zoomedViewArray(obj, zv)
            obj.zoomedViewArray=zv;
            obj.planesInMemX={obj.zoomedViewArray.x}; %#ok<MCSUP>
            obj.planesInMemY={obj.zoomedViewArray.y};   %#ok<MCSUP>
            obj.planesInMemZ=[obj.zoomedViewArray.z];   %#ok<MCSUP>
            obj.planesInMemDS=[obj.zoomedViewArray.downSampling]; %#ok<MCSUP>
            notify(obj.parentViewerDisplay.parentViewer, 'CacheChanged') %#ok<MCSUP>
        end
    end

    methods(Access=protected)


        %% Memory management


        function reduceToCacheLimit(obj)
            if ~isempty(obj.zoomedViewArray)
                cumTotalSizeOfZoomedViewsMB=cumsum([obj.zoomedViewArray.sizeMiB]);
                masivDebugTimingInfo(2, 'mZVM.reduceToCacheLimit: Current Cache Size',round(cumTotalSizeOfZoomedViewsMB(end)), 'MB')
                if any(cumTotalSizeOfZoomedViewsMB>masivSetting('cache.sizeLimitMiB'))
                    firstIndexToCut=find(cumTotalSizeOfZoomedViewsMB>masivSetting('cache.sizeLimitMiB'), 1);
                    obj.zoomedViewArray=obj.zoomedViewArray(1:firstIndexToCut-1);
                end
            end
        end

        function moveZVToTopOfCacheStack(obj, idx)
            masivDebugTimingInfo(2, sprintf('mZVM.moveZVToTopOfCacheStack: Moving GV to stack top (stack size %u)', numel(obj.zoomedViewArray)),toc,'s')
            obj.zoomedViewArray=obj.zoomedViewArray([idx 1:idx-1 idx+1:end]);
            masivDebugTimingInfo(2, 'mZVM.moveZVToTopOfCacheStack: Move completed',toc,'s')
        end

    end

    methods
        function lims=currentViewStretchLim(obj, pctile)
            lims=stretchlim(obj.hImg.CData, pctile);
        end
    end
end

function v=findMatchingView(obj)
    masivDebugTimingInfo(2, 'mZVM.findMatchingView: Checking for matching planes...', toc,'s')
    if isempty(obj.zoomedViewArray)
        v=[];
        return
    else
        %% Get the current view limits
        parent=obj.parentViewerDisplay;

        viewX=xlim(parent.axes);
        viewY=ylim(parent.axes);
        viewZ=parent.currentZPlaneOriginalVoxels;
        viewDS=parent.downSamplingForCurrentZoomLevel;



        %% Allow a slightly smaller image (5xdownsampling) to be considered a match
        %    (Takes care of rounding errors)
        allowablePixelsSmallerThanView=5*viewDS;
        viewX=viewX+[1 -1]*allowablePixelsSmallerThanView;
        viewY=viewY+[1 -1]*allowablePixelsSmallerThanView;

        %% Do comparison
        xMatch=(cellfun(@min, obj.planesInMemX)<=viewX(1))&(cellfun(@max, obj.planesInMemX)>=viewX(2));
        yMatch=(cellfun(@min, obj.planesInMemY)<=viewY(1))&(cellfun(@max, obj.planesInMemY)>=viewY(2));
        v=find( xMatch & ...
            yMatch & ...
            viewZ==obj.planesInMemZ & ...
            viewDS==obj.planesInMemDS);

        masivDebugTimingInfo(2, 'mZVM.findMatchingView: Comparison complete.', toc,'s')
    end
end

function updateImage(obj, idx)
   zv=obj.zoomedViewArray(idx);
   masivDebugTimingInfo(2, 'mZVM.updateImage: beginning update',toc,'s')
   %% Create image object if it doesn't exist
   if ~ishandle(obj.hImg)
       obj.hImg=image('Parent', obj.parentViewerDisplay.axes, ...
           'Visible', 'off', ...
           'CDataMapping', 'Scaled', ...
           'Tag', 'zoomedView', ...
           'HitTest', 'off', 'AlphaData', obj.parentViewerDisplay.hImg.AlphaData);
   end
   %% Update Image
   obj.hImg.XData=zv.x;
   obj.hImg.YData=zv.y;
   masivDebugTimingInfo(2, 'mZVM.updateImage: beginning CData change',toc,'s')
   obj.hImg.CData=zv.imageData;
   masivDebugTimingInfo(2, 'mZVM.updateImage: CData change complete',toc,'s')
   obj.hImg.Visible='on';
   obj.moveZVToTopOfCacheStack(idx);
end

%% Boring utility functions

function regionSpec=getRegionSpecFromParent(parentViewerDisplay)
   xl=round(xlim(parentViewerDisplay.axes));
   yl=round(ylim(parentViewerDisplay.axes));
   regionSpec=[xl(1) yl(1) range(xl) range(yl)];
end










