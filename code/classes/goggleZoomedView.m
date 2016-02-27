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
        positionAdjustment
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
        function obj=goggleZoomedView(filePath, regionSpec, downSampling, z, parent, varargin)
            if nargin>0
                %% Output that we've started
                goggleDebugTimingInfo(3, 'GZV Constructor: starting', toc,'s')
                %% Input parsing
                obj.parentZoomedViewManager=parent;
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
                addParameter(p, 'completedFcn', [], @(x) isempty(x)||isa(x, 'function_handle')||iscell(x));
                addParameter(p, 'positionAdjustment', [0 0], @(x) isnumeric(x)&&numel(x)==2&&all(round(x)==x))
                p.parse(varargin{:});
                
                obj.processingFcns=p.Results.processingFcns;
                obj.completedFcn=p.Results.completedFcn;
                obj.positionAdjustment=p.Results.positionAdjustment;
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
            
            goggleDebugTimingInfo(3, 'GZV.backgroundLoad starting', toc,'s')
            %% Adjust spec if using precise xy adjustments
            rSpec=adjustRegionSpecUsingOffset(obj.regionSpec, obj.positionAdjustment);
            %% Check for crop and set up appropriate load
            
            info=imfinfo(obj.filePath);
            
            if ~isfield(info, 'XPosition') % No crop so just load the whole thing
                goggleDebugTimingInfo(3, 'GZV.backgroundLoad: Uncropped image. Performing standard load', toc,'s')
                f=parfeval(p, @openTiff, 1,obj.filePath, rSpec, obj.downSampling);
            else
                goggleDebugTimingInfo(3, 'GZV.backgroundLoad: Cropped image. Checking status of requested region', toc,'s')
                [xoffset, yoffset]=checkTiffFileForOffset(info);
                rSpecAdjustedForCrop=rSpec-[xoffset yoffset 0 0];

                switch checkRSpecImageStatus(info, rSpecAdjustedForCrop)
                    case 0 % requested region is not on disk
                        goggleDebugTimingInfo(3, 'GZV.backgroundLoad: Region not on disk; upscaling DSS', toc,'s')
                        f=parfeval(p, @upsampleDSSToRegionSpec, 1, currentDownscaleFactor, obj.filePath, rSpec);
                    case 1 % requested region is partly on disk
                        goggleDebugTimingInfo(3, 'GZV.backgroundLoad: Region partially on disk; performing partial load', toc,'s')
                        f=setUpAsyncPartialLoad(obj, info, rSpec, rSpecAdjustedForCrop);
                    case 2 % requested region is fully on disk
                        goggleDebugTimingInfo(3, 'GZV.backgroundLoad: Region fully on disk; loading', toc,'s')
                        f=parfeval(p, @openTiff, 1, obj.filePath, rSpecAdjustedForCrop, obj.downSampling);
                end
            end
            
            goggleDebugTimingInfo(3, 'GZV.backgroundLoad: parfeval started', toc,'s')

            obj.checkForLoadedImageTimer=timer('BusyMode', 'queue', 'ExecutionMode', 'fixedSpacing', 'Period', .01, 'TimerFcn', {@checkForLoadedImage, obj, f}, 'Name', 'zoomedView');
            goggleDebugTimingInfo(3, 'GZV.backgroundLoad: Timer created', toc,'s')
            
            addLineToReadQueueFile
            if timerAutoStart
                start(obj.checkForLoadedImageTimer)
                goggleDebugTimingInfo(3, 'GZV.backgroundLoad: Timer started', toc,'s')
            end
        end

        
        %% Callback function
        function executeCompletedFcn(obj)
            % The completedFcn can be either a function handle, or a cell
            % array containing the function handle and any number of
            % inputs. These inputs are then fed in to the function at
            % run-time. To specify the created goggleZoomedView object
            % itself, use 'obj' as a parameter
            %
            % e.g. ...'completedFcn', {@foo, 'obj'}
            %
              if ~isempty(obj.completedFcn)
                  goggleDebugTimingInfo(3, 'GZV.checkForLoadedImage: Running load completion callback', toc,'s')
                  if iscell(obj.completedFcn)
                      fun=obj.completedFcn{1};
                      if numel(obj.completedFcn)>1
                          extraArgs=obj.completedFcn(2:end);
                          extraArgs{strcmp(extraArgs, 'newObj')}=obj;
                          fun(extraArgs{:})
                      else
                          fun(); %execute with no extra arguments
                      end
                  else 
                      fun=obj.completedFcn;
                      fun(); %execute with no extra arguments
                  end
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
        if isa(f{ii}, 'function_handle')
            % It's a plain function 
            I=f{ii}(I, obj);
        else
            % It's an imageProcessing module object (probably)
            I=f{ii}.processImage(I, obj);
        end
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

function regionSpec=adjustRegionSpecUsingOffset(regionSpec, offset)
    regionSpec(1)=regionSpec(1)-offset(2);
    regionSpec(2)=regionSpec(2)-offset(1);
end

function status=checkRSpecImageStatus(info, rSpec)
% Returns whether the specified region spec is fully (2), partially (1) or
% not at all (0) present in the image file
    if rSpec(1)>info.Width || rSpec(2) > info.Height ||...
        (rSpec(1)+rSpec(3)-1) < 1 || (rSpec(1)+rSpec(3)-1) < 1
        status = 0;
    elseif rSpec(1)<1 || rSpec(2) < 1 ||...
        (rSpec(1)+rSpec(3) > info.Width) || (rSpec(2)+rSpec(4) > info.Height)        
        status=1;
    else
        status=2;
    end
end

function I=upsampleDSSToRegionSpec(DSS, currentDownscaleFactor, filePath, rSpec)
    %% Work out which slice in the DSS to use
    [~, requestedSliceFileName, ~]=fileparts(filePath);
    sliceFileIdx=~cellfun(@isempty, strfind(DSS.originalImageFilePaths, requestedSliceFileName));
    %% Work out the limits of the requested region spec
    idx_x1=find(DSS.xCoordsVoxels<rSpec(1), 1, 'last');
    idx_y1=find(DSS.yCoordsVoxels<rSpec(2), 1, 'last');
    idx_xEnd=find(DSS.xCoordsVoxels>(rSpec(1)+rSpec(3)-1), 1, 'first');
    idx_yEnd=find(DSS.yCoordsVoxels>(rSpec(2)+rSpec(4)-1), 1, 'first');
    
    x=idx_x1:idx_xEnd;
    y=idx_y1:idx_yEnd;
    z=DSS.zCoordsVoxels==find(sliceFileIdx);
    %% Copy the right chunk of DS image
    dsImg=DSS.I(y, x, z);
    
    %% Upsample the image and the x and y
    
    scaleFac=DSS.xyds/currentDownscaleFactor;
    
    usImg=imresize(dsImg, scaleFac, 'bilinear');
    xUs=DSS.xCoordsVoxels(idx_x1):scaleFac:DSS.xCoordsVoxels(idx_xEnd);
    yUs=DSS.yCoordsVoxels(idx_y1):scaleFac:DSS.yCoordsVoxels(idx_yEnd);

    [~, idx_x1_us]=min(abs(xUs-rSpec(1)));
    [~, idx_y1_us]=min(abs(yUs-rSpec(2)));
    
    I=usImg(idx_y1_us:idx_y1_us+ceil(rSpec(4)/currentDownscaleFactor)-1, idx_x1_us:idx_x1_us+ceil(rSpec(3)/currentDownscaleFactor)-1);
end

function f=setUpAsyncPartialLoad(obj, info, rSpec, rSpecAdjustedForCrop)
    
    DSS=obj.parentZoomedViewManager.parentViewerDisplay.overviewStack;
    currentDSFactor=obj.parentZoomedViewManager.parentViewerDisplay.downSamplingForCurrentZoomLevel;
    
    I=upsampleDSSToRegionSpec(DSS, currentDSFactor, obj.filePath, rSpec);
    rSpecThatCanBeLoaded=getRSpecPortionThatIsOnDisk(rSpecAdjustedForCrop, info);
    
    f=parfeval(@openTiff, 1, obj.filePath, rSpecThatCanBeLoaded, obj.downSampling);
    
    insertImageFcn=@(IDetail, obj) insertDetailIntoImage(I, IDetail, rSpecAdjustedForCrop, rSpecThatCanBeLoaded, currentDSFactor);
    
    if isempty(obj.processingFcns)
        obj.processingFcns={insertImageFcn};
    elseif iscell(obj.processingFcns)
        obj.processingFcns=[{insertImageFcn}, obj.processingFcns];
    else
        error('Can''t parse processingFcns list')
    end
    
end

function rSpec=getRSpecPortionThatIsOnDisk(rSpec, info)

    if rSpec(1)<1
        shiftRight=1-rSpec(1);
    else
        shiftRight=0;
    end
    if rSpec(2)<1
        shiftDown=1-rSpec(2);
    else
        shiftDown=0;
    end
    
    rSpec=rSpec+[shiftRight shiftDown -shiftRight -shiftDown];
    
    if (rSpec(1)+rSpec(3)-1)>info.Width
        widthReduction=(rSpec(1)+rSpec(3)-1)-info.Width;
    else
        widthReduction=0;
    end
    
    if (rSpec(2)+rSpec(4)-1)>info.Height
        heightReduction=(rSpec(2)+rSpec(4)-1)-info.Height;
    else
        heightReduction=0;
    end
    
    rSpec=rSpec-[0 0 widthReduction heightReduction];


end

function I=insertDetailIntoImage(I, IDetail, rSpecAdjustedForCrop, rSpecThatCanBeLoaded, currentDownscaleFactor)
xStart=round((rSpecThatCanBeLoaded(1)-rSpecAdjustedForCrop(1))/currentDownscaleFactor)+1;
yStart=round((rSpecThatCanBeLoaded(2)-rSpecAdjustedForCrop(2))/currentDownscaleFactor)+1;
xEnd=xStart+size(IDetail, 2)-1;
yEnd=yStart+size(IDetail, 1)-1;

I(yStart:yEnd, xStart:xEnd)=IDetail; % Slip the loaded data in to the upscaled downsampled stack

end

