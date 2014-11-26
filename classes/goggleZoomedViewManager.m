classdef goggleZoomedViewManager<handle
    properties(SetAccess=protected)
        currentImageFilePath
    end
    properties(Access=protected)
        parentViewerDisplay
        zoomedViewArray=goggleZoomedView
        hImg
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
        cacheInfoPanel
    end
    methods
        %% Constructor
        function obj=goggleZoomedViewManager(parentViewerDisplay)
            obj.parentViewerDisplay=parentViewerDisplay;
        end
        
        %% View updates
        function updateView(obj)
            v=findMatchingView(obj);
            if isempty(v)
                goggleDebugTimingInfo(2, 'GZVM.updateView: Creating new view...', toc,'s')
                try
                    stdout=obj.createNewView;
                    if stdout==0
                        obj.hide
                    end
                catch err
                    if strcmp(err.identifier, 'ZVM:couldNotFindFile')
                        goggleDebugTimingInfo(0, strrep(err.message,  'ZoomedViewManager: ', 'WARNING IN GZVM.updateView: '), toc,'s')
                        obj.hImg.Visible='off';
                    else
                        rethrow(err)
                    end
                end
            else
                goggleDebugTimingInfo(2, ['GZVM.updateView: Matching views found: ' sprintf('%u, ', v)],toc,'s')
                goggleDebugTimingInfo(2, sprintf('GZVM.updateView: View #%u will be used. Updating image...', v(1)),toc,'s')
                updateImage(obj, v(1))
            end
            obj.updateCacheInfoPanel();

        end
        
        function stdout=createNewView(obj)
            if obj.currentSliceFileExistsOnDisk
                
                parent=obj.parentViewerDisplay;
                
                fp=obj.currentSliceFileFullPath;
                regionSpec=getRegionSpecFromParent(parent);
                ds=parent.downSamplingForCurrentZoomLevel;
                z=parent.currentZPlaneOriginalFileNumber;
                
                goggleDebugTimingInfo(2, 'GZVM.createNewView: Zoomed view creation starting',toc,'s')
                obj.zoomedViewArray(end+1)=goggleZoomedView(fp, regionSpec, ds, z, obj);
                goggleDebugTimingInfo(2, 'GZVM.createNewView: Zoomed view created',toc,'s')
                
                obj.cleanUpCache();
                stdout=1;
            else
                stdout=0;
            end
        end
        
        function hide(obj)
            obj.hImg.Visible='off';
        end
        
        function cleanUpCache(obj)
            obj.clearInvalidPlanes();
            obj.reduceToCacheLimit();
            obj.updateCacheInfoPanel();
        end
        %% Getters
        function csfn=get.currentSliceFileName(obj)
            stitchedFileNameList=obj.parentViewerDisplay.overviewStack.originalStitchedFileNames;
            indexInFileNameList=obj.parentViewerDisplay.currentZPlaneOriginalFileNumber;
            csfn=stitchedFileNameList{indexInFileNameList};
        end
        function csfp=get.currentSliceFileFullPath(obj)
            baseDir=obj.parentViewerDisplay.overviewStack.baseDirectory;
            csfn=obj.currentSliceFileName;
            
            csfp=fullfile(baseDir, csfn);
        end
        function fileOnDisk=get.currentSliceFileExistsOnDisk(obj)
            fileOnDisk=exist(obj.currentSliceFileFullPath, 'file');
        end
        function imgVis=get.imageVisible(obj)
            imgVis=~isempty(obj.hImg)&&strcmp(obj.hImg.Visible, 'on');
        end
        function cData=get.currentImageViewData(obj)
            cData=obj.hImg.CData;
        end
        function cmem=get.cacheMemoryUsed(obj)
            cmem=sum([obj.zoomedViewArray.sizeMiB]);
        end
    end
    
    methods(Access=protected)
        
        
        %% Memory management
        
        
        function reduceToCacheLimit(obj)
            cumTotalSizeOfZoomedViewsMB=cumsum([obj.zoomedViewArray.sizeMiB]);
            goggleDebugTimingInfo(2, 'GZVM.reduceToCacheLimit: Current Cache Size',round(cumTotalSizeOfZoomedViewsMB(end)), 'MB')
            if any(cumTotalSizeOfZoomedViewsMB>gbSetting('cache.sizeLimitMiB'))
                firstIndexToCut=find(cumTotalSizeOfZoomedViewsMB>gbSetting('cache.sizeLimitMiB'), 1);
                obj.zoomedViewArray=obj.zoomedViewArray(1:firstIndexToCut-1);
            end
        end
        
        function clearInvalidPlanes(obj)
            goggleDebugTimingInfo(2, 'GZVM.clearInvalidPlanes: Checking for invalid planes...', toc,'s')
            invalidIdx=[obj.zoomedViewArray.z]<0;
            obj.zoomedViewArray=obj.zoomedViewArray(~invalidIdx);
            goggleDebugTimingInfo(2, sprintf('GZVM.clearInvalidPlanes: %u invalid planes found and cleared.',sum(invalidIdx)), toc,'s')
        end
        
        function moveZVToTopOfCacheStack(obj, idx)
            obj.zoomedViewArray=obj.zoomedViewArray([idx 1:idx-1 idx+1:end]);
        end
        
        function updateCacheInfoPanel(obj)
            for ii=1:numel(obj.cacheInfoPanel)
                obj.cacheInfoPanel(ii).updateCacheStatusDisplay;
            end
        end
    end
end

function v=findMatchingView(obj)
    goggleDebugTimingInfo(2, 'GZVM.findMatchingView: Checking for matching planes...', toc,'s')
    obj.clearInvalidPlanes
    parent=obj.parentViewerDisplay;
    
    viewX=xlim(parent.axes);
    viewY=ylim(parent.axes);
    viewZ=parent.currentZPlaneOriginalFileNumber;
    viewDS=parent.downSamplingForCurrentZoomLevel;
    
    planesInMemX={obj.zoomedViewArray.x};
    planesInMemY={obj.zoomedViewArray.y};
    planesInMemZ=[obj.zoomedViewArray.z];
    planesInMemDS=[obj.zoomedViewArray.downSampling];
    
    %% Allow a slightly smaller image (5xdownsampling) to be considered a match
    %    (Takes care of rounding errors)
    allowablePixelsSmallerThanView=5*viewDS;
    viewX=viewX+[1 -1]*allowablePixelsSmallerThanView;
    viewY=viewY+[1 -1]*allowablePixelsSmallerThanView;
    
    %%
    xMatch=(cellfun(@min, planesInMemX)<=viewX(1))&(cellfun(@max, planesInMemX)>=viewX(2));
    yMatch=(cellfun(@min, planesInMemY)<=viewY(1))&(cellfun(@max, planesInMemY)>=viewY(2));
    v=find( xMatch & ...
        yMatch & ...
        viewZ==planesInMemZ & ...
        viewDS==planesInMemDS);
    
    goggleDebugTimingInfo(2, 'GZVM.findMatchingView: Comparison complete.', toc,'s')

end

function updateImage(obj, idx)
   zv=obj.zoomedViewArray(idx);
   goggleDebugTimingInfo(2, 'GZVM.updateImage: beginning update',toc,'s')
   %% Create image object if it doesn't exist
   if ~ishandle(obj.hImg)
       obj.hImg=image('Parent', obj.parentViewerDisplay.axes, ...
           'Visible', 'off', ...
           'CDataMapping', 'Scaled', ...
           'Tag', 'zoomedView');
   end
   %% Update Image
   obj.hImg.XData=zv.x;
   obj.hImg.YData=zv.y;
   obj.hImg.CData=zv.imageData;
   obj.hImg.Visible='on';
   
   obj.moveZVToTopOfCacheStack(idx);
end

%% Boring utility functions

function regionSpec=getRegionSpecFromParent(parentViewerDisplay)
   xl=round(xlim(parentViewerDisplay.axes));
   yl=round(ylim(parentViewerDisplay.axes));
   regionSpec=[xl(1) yl(1) range(xl) range(yl)];
end










