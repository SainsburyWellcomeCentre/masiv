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
            drawnow()
            v=findMatchingView(obj);
            if isempty(v)
                fprintf('      GZVM.updateView: Creating new view...\n')
                obj.createNewView;
            else
                fprintf('      GZVM.updateView: Matching views found:')
                fprintf('%u, ', v)
                fprintf('\n Using #%u\n', v(1))
                updateImage(obj, v(1))
            end
        end
        
        function createNewView(obj)
            parent=obj.parentViewerDisplay;
         
            stitchedFileFullPath=filePathToLoadRegionFrom(parent);
            regionSpec=getRegionSpecFromParent(parent);
            
            ds=parent.downSamplingForCurrentZoomLevel;
            z=parent.currentZPlaneOriginalFileNumber;
            
            fprintf('      GZVM.createNewView: Zoomed view creation: \t\t%1.4fs\n', toc)
            obj.zoomedViewArray(end+1)=goggleZoomedView(stitchedFileFullPath, regionSpec, ds, z, obj);
            fprintf('      GZVM.createNewView: Zoomed view created: \t\t\t%1.4fs\n', toc)
            
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
            fprintf('      GZVM.reduceToCacheLimit: Current Cache Size: \t\t\t%uMB\n', round(cumTotalSizeOfZoomedViewsMB(end)))
            if any(cumTotalSizeOfZoomedViewsMB>obj.cacheSizeLimitMB)
                firstIndexToCut=find(cumTotalSizeOfZoomedViewsMB>obj.cacheSizeLimitMB, 1);
                obj.zoomedViewArray=obj.zoomedViewArray(1:firstIndexToCut-1);
            end
        end
        
        function clearInvalidPlanes(obj)
            invalidIdx=[obj.zoomedViewArray.z]<0;
            obj.zoomedViewArray=obj.zoomedViewArray(~invalidIdx);
        end
        
        function moveZVToTopOfCacheStack(obj, idx)
            obj.zoomedViewArray=obj.zoomedViewArray([idx 1:idx-1 idx+1:end]);
        end
    end
end

function v=findMatchingView(obj)
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
   
end

function updateImage(obj, idx)
   zv=obj.zoomedViewArray(idx);
   fprintf('      GZVM.updateImage: beginning update: A\t\t\t%1.4fs\n', toc)
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
   drawnow()
   
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
end









