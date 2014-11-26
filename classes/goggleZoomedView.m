classdef goggleZoomedView<handle
    properties(SetAccess=protected)
        imageData
    end
    properties(SetAccess=protected)
        regionSpec
        downSampling
        filePath
        parentZoomedViewManager
        x
        y
        z
    end
    properties(SetAccess=protected, Dependent)
        sizeMiB
        imageInMemory
    end
    
    methods
        %% Constructor
        function obj=goggleZoomedView(filePath, regionSpec, downSampling, z, parentZoomedViewManager)
            if nargin>0
                goggleDebugTimingInfo(3, 'GZV Constructor: starting', toc,'s')
                obj.regionSpec=regionSpec;
                obj.downSampling=downSampling;
                obj.filePath=filePath;
                
                obj.x=obj.regionSpec(1):obj.downSampling:obj.regionSpec(1)+obj.regionSpec(3)-1;
                obj.y=obj.regionSpec(2):obj.downSampling:obj.regionSpec(2)+obj.regionSpec(4)-1;
                obj.z=z;
                
                obj.parentZoomedViewManager=parentZoomedViewManager;
                
                goggleDebugTimingInfo(3, 'GZV Constructor: completed, calling loadViewImageInBackground...', toc,'s')
                loadViewImageInBackground(obj)
            else
                obj.z=-1;
            end
        end
        %% Getters
        function szMiB=get.sizeMiB(obj)
            szBytes=numel(obj.imageData)*2; % 16 bit images
            szMiB=szBytes/(1024*1024);
        end
        function inmem=get.imageInMemory(obj)
            inmem=~isempty(obj.imageData);
        end
       
    end
end

function loadViewImageInBackground(obj)
goggleDebugTimingInfo(3, 'GZV.loadViewImageInBackground starting', toc,'s')
p=gcp();

f=parfeval(p, @openTiff, 1, obj.filePath, obj.regionSpec, obj.downSampling);
goggleDebugTimingInfo(3, 'GZV.loadViewImageInBackground: parfeval started', toc,'s')
t=timer('BusyMode', 'queue', 'ExecutionMode', 'fixedSpacing', 'Period', 0.01, 'TimerFcn', {@checkForLoadedImage, obj, f}, 'Name', 'zoomedView');
goggleDebugTimingInfo(3, 'GZV.loadViewImageInBackground: Timer created', toc,'s')
addLineToReadQueueFile
start(t)
goggleDebugTimingInfo(3, 'GZV.loadViewImageInBackground: Timer started', toc,'s')



end

function checkForLoadedImage(t, ~, obj, f)
    try
        [idx, r]=fetchNext(f, 0.01);
    catch 
        idx=[];
        stop(t)
        delete(t)
        goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: TIMER ERROR', toc,'s')
        deleteLineFromQueueFile;
    end
    if ~isempty(idx)
        deleteLineFromQueueFile;
        goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: Image has been loaded', toc,'s')
        if mod(obj.downSampling, 2)
            r=deComb(r);
            goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: Image has been decombed', toc,'s')
        else
            goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: Image has not been decombed', toc,'s')
        end
        r=imfilter(r, fspecial('gaussian', 5, 0.6));
        goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: Image has been filtered', toc,'s')
        obj.imageData=r;
        goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: Image data read', toc,'s')
        stop(t)
        goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: Timer stopped', toc,'s')
        delete(t)
        goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: Timer deleted', toc,'s')
        goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: Calling ZVM updateView...', toc,'s')
        obj.parentZoomedViewManager.updateView();
    end
end

