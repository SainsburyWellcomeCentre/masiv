classdef goggleZoomedView<handle
    properties(SetAccess=protected)
        rawImageData
    end
    properties(SetAccess=protected)
        regionSpec
        downSampling
        filePath
        parentZoomedViewManager
        x
        y
        z
        completedFcn
    end
    properties(SetAccess=protected, Dependent)
        sizeMiB
        imageInMemory
        imageData
    end
    
    methods
        %% Constructor
        function obj=goggleZoomedView(filePath, regionSpec, downSampling, z, parentZoomedViewManager, completedFcn)
            if nargin>0
                goggleDebugTimingInfo(3, 'GZV Constructor: starting', toc,'s')
                obj.regionSpec=regionSpec;
                obj.downSampling=downSampling;
                obj.filePath=filePath;
                if iscell(obj.filePath)
                    obj.filePath=obj.filePath{1};
                end
                
                obj.x=obj.regionSpec(1):obj.downSampling:obj.regionSpec(1)+obj.regionSpec(3)-1;
                obj.y=obj.regionSpec(2):obj.downSampling:obj.regionSpec(2)+obj.regionSpec(4)-1;
                obj.z=z;
                
                obj.parentZoomedViewManager=parentZoomedViewManager;
                
                if nargin<6||isempty(completedFcn)
                    obj.completedFcn=[];
                else
                    if ~isa(completedFcn, 'function_handle')
                        error('Completed Callback function must be a handle')
                    end
                    obj.completedFcn=completedFcn;
                end
                
                goggleDebugTimingInfo(3, 'GZV Constructor: completed, calling loadViewImageInBackground...', toc,'s')
                loadViewImageInBackground(obj)
                
            else
                obj.z=-1;
            end
        end
        
        %% Callback function
        function executeCompletedFcn(obj)
              if ~isempty(obj.completedFcn)
                  fun=obj.completedFcn;
                  fun(); %execute with no extra arguments
              end     
        end
        %% Getters
        function szMiB=get.sizeMiB(obj)
            szBytes=numel(obj.rawImageData)*2; % 16 bit images
            szMiB=szBytes/(1024*1024);
        end
        function inmem=get.imageInMemory(obj)
            inmem=~isempty(obj.rawImageData);
        end
        function I=get.imageData(obj)
            I=obj.rawImageData;
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
        [idx, I]=fetchNext(f, 0.01);
    catch err
        for ii=1:numel(err.stack)
            disp(err.stack(ii))
        end
        idx=[];
        stop(t)
        delete(t)
        goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: TIMER ERROR', toc,'s')
        deleteLineFromQueueFile;
    end
    if ~isempty(idx)
        deleteLineFromQueueFile;
        goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: Image has been loaded. Processing', toc,'s')
        I=processImage(I, obj);
        goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: Image has been filtered', toc,'s')
        obj.rawImageData=I;
        goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: Image data read', toc,'s')
        stop(t)
        goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: Timer stopped', toc,'s')
        delete(t)
        goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: Timer deleted', toc,'s')
        goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: Calling ZVM updateView...', toc,'s')
      
        executeCompletedFcn(obj)
    end
end

function I=processImage(I, obj)
    p=obj.parentZoomedViewManager;   
    for ii=1:numel(p.imageProcessingPipeline)
        I=p.imageProcessingPipeline{ii}.processImage(I, obj);
    end
end

