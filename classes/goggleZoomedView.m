classdef goggleZoomedView<handle
    properties(SetAccess=protected)
        rawImageData
    end
    properties(SetAccess=protected)
        regionSpec
        downSampling=-1
        filePath
        parentZoomedViewManager
        x=-1
        y=-1
        z=-1
        completedFcn
        processingFcns
    end
    properties(SetAccess=protected, Dependent)
        sizeMiB
        imageInMemory
        imageData
    end
    properties
        checkForLoadedImageTimer
    end
    
    methods
        %% Constructor
        function obj=goggleZoomedView(filePath, regionSpec, downSampling, z, varargin)
            if nargin>0
                %% Output that we've started
                goggleDebugTimingInfo(3, 'GZV Constructor: starting', toc,'s')
                %% Input parsing
                
                obj.regionSpec=regionSpec;
                obj.downSampling=downSampling;
                obj.filePath=filePath;
                if iscell(obj.filePath)
                    obj.filePath=obj.filePath{1};
                end
                
                obj.x=obj.regionSpec(1):obj.downSampling:obj.regionSpec(1)+obj.regionSpec(3)-1;
                obj.y=obj.regionSpec(2):obj.downSampling:obj.regionSpec(2)+obj.regionSpec(4)-1;
                obj.z=z;
                %% Optional input parsing (processing functions and callbacks)
                p=inputParser;
                p.FunctionName='goggleZoomedViewManager.constructor';
                addParameter(p, 'processingFcns', [], @checkValidPipeline);
                addParameter(p, 'completedFcn', [], @(x) isempty(x)||isa(x, 'function_handle'));
                p.parse(varargin{:});
                
                obj.processingFcns=p.Results.processingFcns;
                obj.completedFcn=p.Results.completedFcn;
                
                %% Display that creation is done
                goggleDebugTimingInfo(3, 'GZV Constructor: completed. Ready to load image.', toc,'s')
                
            else
                obj.z=-1;
            end
        end
        
        %% Load function
        function backgroundLoad(obj, p, timerAutoStart)
            % Sets up an asynchronous load using parfeval. Sets up a timer
            % to check for completion of the load task, and execute
            % post-loading processing
            %
            % obj:  a goggleZoomed view object
            %
            % p:    (optional) a Parallel worker pool. If not specified,
            % the current worker pool will be used (and created, if
            % necessary)
            %
            % timerAutoStart: (optional) if set to 0, the timer will be 
            %created but not started. It can then be started manually:
            % (start(obj.checkForLoadedImageTimer))
            
            if nargin<3||isempty(timerAutoStart)
                timerAutoStart=1;
            end
            
            if nargin<2||isempty(p)
                p=gcp;
            end
            
            goggleDebugTimingInfo(3, 'GZV.loadViewImageInBackground starting', toc,'s')
            
            f=parfeval(p, @openTiff, 1, obj.filePath, obj.regionSpec, obj.downSampling);
            goggleDebugTimingInfo(3, 'GZV.loadViewImageInBackground: parfeval started', toc,'s')
            
            obj.checkForLoadedImageTimer=timer('BusyMode', 'queue', 'ExecutionMode', 'fixedSpacing', 'Period', .01, 'TimerFcn', {@checkForLoadedImage, obj, f}, 'Name', 'zoomedView');
            goggleDebugTimingInfo(3, 'GZV.loadViewImageInBackground: Timer created', toc,'s')
            
            addLineToReadQueueFile
            if timerAutoStart
                start(obj.checkForLoadedImageTimer)
                goggleDebugTimingInfo(3, 'GZV.loadViewImageInBackground: Timer started', toc,'s')
            end
        end

        
        %% Callback function
        function executeCompletedFcn(obj)
              if ~isempty(obj.completedFcn)
                  goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: Running load completion callback', toc,'s')
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
      
        executeCompletedFcn(obj)
    end
end

function I=processImage(I, obj)
    f=obj.processingFcns;   
    for ii=1:numel(f)
        I=f{ii}.processImage(I, obj);
    end
end

function v=checkValidPipeline(p)
    v=1;
    if ~isempty(p)
        if ~iscell(p)
            p={p};
        end
        for ii=1:numel(p)
            v=v&&checkIndividualPipelineObject(p{ii});
        end
    end
end

function validProcessingStep=checkIndividualPipelineObject(objToCheck)
    validProcessingStep=isobject(objToCheck);
    if validProcessingStep
        objToCheckClassInfo=metaclass(objToCheck);
        superClassList=objToCheckClassInfo.SuperclassList;
        validProcessingStep=ismember('singleImage_DisplayProcessor', {superClassList.Name});
    end
end






























