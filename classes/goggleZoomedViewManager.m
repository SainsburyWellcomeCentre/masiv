classdef goggleZoomedViewManager<handle
    properties(SetAccess=protected)
        cacheSizeLimitMB=1*1024; %16GB by default
    end
    properties(Access=protected)
        parentViewerDisplay
        zoomedViewArray=goggleZoomedView
        hImg
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
                obj.createNewView;
            else
                goggleDebugTimingInfo(2, ['GZVM.updateView: Matching views found: ' sprintf('%u, ', v)],toc,'s')
                goggleDebugTimingInfo(2, sprintf('GZVM.updateView: View #%u will be used. Updating image...', v(1)),toc,'s')
                updateImage(obj, v(1))
            end
        end
        
        function createNewView(obj)
            parent=obj.parentViewerDisplay;
         
            stitchedFileFullPath=filePathToLoadRegionFrom(parent);
            regionSpec=getRegionSpecFromParent(parent);
            
            ds=parent.downSamplingForCurrentZoomLevel;
            z=parent.currentZPlaneOriginalFileNumber;
            
            goggleDebugTimingInfo(2, 'GZVM.createNewView: Zoomed view creation starting',toc,'s')
            obj.zoomedViewArray(end+1)=goggleZoomedView(stitchedFileFullPath, regionSpec, ds, z, obj);
            goggleDebugTimingInfo(2, 'GZVM.createNewView: Zoomed view created',toc,'s')
            
            obj.cleanUpCache();
        end
        
        function hide(obj)
            obj.hImg.Visible='off';
        end
    end
    
    methods(Access=protected)
        
        
        %% Memory management
        function cleanUpCache(obj)
            obj.clearInvalidPlanes();
            obj.reduceToCacheLimit();
        end
        
        function reduceToCacheLimit(obj)
            cumTotalSizeOfZoomedViewsMB=cumsum([obj.zoomedViewArray.sizeMB]);
            goggleDebugTimingInfo(2, 'GZVM.reduceToCacheLimit: Current Cache Size',round(cumTotalSizeOfZoomedViewsMB(end)), 'MB')
            if any(cumTotalSizeOfZoomedViewsMB>obj.cacheSizeLimitMB)
                firstIndexToCut=find(cumTotalSizeOfZoomedViewsMB>obj.cacheSizeLimitMB, 1);
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

function stitchedFileFullPath=filePathToLoadRegionFrom(parentViewerDisplay)
   stitchedFileNameList=parentViewerDisplay.overviewStack.originalStitchedFileNames;
   indexInFileNameList=parentViewerDisplay.currentZPlaneOriginalFileNumber;
   baseDir=parentViewerDisplay.overviewStack.baseDirectory;
   
   stitchedFileName=stitchedFileNameList{indexInFileNameList};
   stitchedFileFullPath=fullfile(baseDir, stitchedFileName);
   if ~exist(stitchedFileFullPath, 'file')
       error('ZoomedViewManager: The specified slice file (%s) could not be found.', stitchedFileFullPath)
   end
end









