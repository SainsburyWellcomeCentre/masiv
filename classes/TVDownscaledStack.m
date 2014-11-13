classdef TVDownscaledStack<handle
    
    properties(Dependent, SetAccess=protected)
        name
    end
    
    properties
        baseDirectory
        experimentName
        sampleName
    end
    
    properties(SetAccess=protected)
        gbStackDirectory
        fileName
        
        channel
        idx
        xyds
        
    end
    
    properties(Access=protected)
        mosaicInfo
        I_internal
        xInternal
        yInternal
        zInternal
    end
    
    properties(Dependent, SetAccess=protected)
        I
                
        imageInMemory
        fileOnDisk
        
        xCoords
        yCoords
        zCoords
        
        originalStitchedFileNames
    end
    
    properties(Dependent, Access=protected)
       downscaledStackObjectCollectionPath
    end
    
    methods
        %% Constructor
        function obj=TVDownscaledStack(varargin)
            % There is currently one way to create a downscaledStack object:
            % 1. pass a stitchedMosaicInfo object, a channel, index and downscaling factor
            switch class(varargin{1})
                case 'TVStitchedMosaicInfo'
                    [obj.mosaicInfo, obj.channel, obj.idx]=varargin{1:3};
                    if nargin>3
                        obj.xyds=varargin{4};
                    else
                        obj.xyds=1;
                    end
                    %% Copy some metadata stright from the mosaicInfo object; archive it just in case it's needed
                   obj.updateFilePathMetaData(obj.mosaicInfo)

            end
        end
        %% Methods
        function generateStack(obj)
            if obj.imageInMemory
                error('Image already in memory')
            end
            obj.I_internal = createDownscaledStack(obj.mosaicInfo, obj.channel, obj.idx, obj.xyds);         
        end
        function loadStackFromDisk(obj)
             if obj.imageInMemory
                error('Image already in memory')
             end
            obj.I_internal=loadTiffStack(obj.fileName);
        end
        function writeStackToDisk(obj)
            if obj.fileOnDisk
                error('File already exists on disk')
            end
            %% Write file locally first to prevent network transport errors
            fprintf('Writing file locally...\n')
            saveTiffStack(obj.I, 'tmp.tif');
            fprintf('Moving file in to place (%s)...', obj.gbStackDirectory)
            movefile('tmp.tif', obj.fileName)
            fprintf('Done. File saved to %s\n', obj.fileName)
            writeObjToMetadataFile(obj)
        end
        function l=list(obj)
            l=cell(size(obj));
            for ii=1:numel(obj)
                l{ii}=obj(ii).name;
            end
        end
        
        function updateFilePathMetaData(obj, TVMosaicInfoObj)
            obj.experimentName=TVMosaicInfoObj.experimentName;
            obj.sampleName=TVMosaicInfoObj.sampleName;
            obj.baseDirectory=TVMosaicInfoObj.baseDirectory;
            %% Get base directory for stacks and fileName for this stack
            obj.gbStackDirectory=getGBStackPath(TVMosaicInfoObj);
            obj.fileName=createGBStackFileNameForOutput(obj);
        end

        %% Getters 
        function g=get.downscaledStackObjectCollectionPath(obj)
             g=fullfile(obj.gbStackDirectory, [obj.sampleName '_GBStackInfo.mat']);
        end
        function nm=get.name(obj)
            [~, f]=fileparts(obj.fileName);
            nm=matlab.lang.makeValidName(f);
        end
        function I=get.I(obj)
            if ~obj.imageInMemory
                if ~obj.fileOnDisk
                    fprintf('Image not in memory or on disk. Generating (this may take some time...)\n')
                    obj.generateStack
                else
                    fprintf('Image not in memory; file found on disk. Loading...\n')
                    obj.loadStackFromDisk;
                end
            end    
            I=obj.I_internal;
        end
        function inMem=get.imageInMemory(obj)
            inMem=~isempty(obj.I_internal);
        end
        function onDisk=get.fileOnDisk(obj)
            onDisk=exist(obj.fileName, 'file')~=0;
        end
        
        function x=get.xCoords(obj)
            if isempty(obj.xInternal)
                if isempty(obj.I_internal)
                    error('Image not loaded in to memory. Can not return x dimension')
                else
                    obj.xInternal=1:size(obj.I_internal, 2)*obj.xyds;
                end
            end
            x=obj.xInternal;
        end
        function y=get.yCoords(obj)
           if isempty(obj.yInternal)
                if isempty(obj.I_internal)
                    error('Image not loaded in to memory. Can not return y dimension')
                else
                    obj.yInternal=1:size(obj.I_internal, 1)*obj.xyds;
                end
            end
            y=obj.yInternal;
        end
        function z=get.zCoords(obj)
            if isempty(obj.zInternal)
                obj.zInternal=(obj.idx-1)*obj.mosaicInfo.metaData.zres*2;
            end
           z=obj.zInternal;
        end
        
        function osfp=get.originalStitchedFileNames(obj)
           osfp= obj.mosaicInfo.stitchedImagePaths.(obj.channel);
        end
    end
end

function gbStackDirPath=getGBStackPath(obj)
gbStackDirPath=fullfile(obj.baseDirectory, [obj.sampleName '_GBStacks']);
if ~exist(gbStackDirPath, 'dir')
    mkdir(gbStackDirPath)
end
end

function fName=createGBStackFileNameForOutput(obj)
fName=fullfile(obj.gbStackDirectory, sprintf('%s_%s_Stack[%u-%u]_DS%u.tif', obj.sampleName, obj.channel, min(obj.idx), max(obj.idx), obj.xyds));
end

function writeObjToMetadataFile(obj)
if ~isempty(obj.I)
        obj.I_internal=[];
end
if ~exist(obj.downscaledStackObjectCollectionPath, 'file')
    stacks=obj; %#ok<NASGU>
    save(obj.downscaledStackObjectCollectionPath, 'stacks')
else
    a=load(obj.downscaledStackObjectCollectionPath);
    stacks=a.stacks;
    stacks(end+1)=obj; %#ok<NASGU>
    save(obj.downscaledStackObjectCollectionPath, 'stacks');
end
fprintf('Done\n')
end

function I = createDownscaledStack( mosaicInfo, channel, idx, varargin )
%CREATEDOWNSCALEDSTACK 

%% Input parsing
p=inputParser;

addRequired(p, 'mosaicInfo', @(x) isa(x, 'TVStitchedMosaicInfo'));
addRequired(p, 'channel', @isstr);
addRequired(p, 'idx', @isvector)
addOptional(p, 'downSample', 1, @(x) isscalar(x));

parse(p, mosaicInfo, channel, idx, varargin{:})
q=p.Results;
if ~isfield(q.mosaicInfo.stitchedImagePaths, channel)
    error('Unknown channel identifier: %s', channel)
end

%% Start default parallel pool if not already
gcp;

%% Generate full file path
pths=fullfile(mosaicInfo.baseDirectory, mosaicInfo.stitchedImagePaths.(channel)(idx));
%% Get file information to determine crop
info=cell(numel(idx), 1);

fprintf('Getting file information...')
parfor ii=1:numel(idx)
    info{ii}=imfinfo(pths{ii});
end

fprintf('Done\n')
%%
minWidth=min(cellfun(@(x) x.Width, info));
minHeight=min(cellfun(@(x) x.Height, info));

outputImageWidth=ceil(minWidth/q.downSample);
outputImageHeight=ceil(minHeight/q.downSample);


fprintf('Preinitialising...')
I=zeros(outputImageHeight, outputImageWidth, numel(idx), 'uint16');
fprintf('Done\n')


fprintf('Loading stack...\n')


parfor ii=1:numel(idx)
    fName=fullfile(mosaicInfo.baseDirectory, mosaicInfo.stitchedImagePaths.(channel){idx(ii)});
    I(:,:,ii)=openTiff(fName, [1 1 minWidth minHeight], q.downSample);
    fprintf('\tSlice %u loaded\n', idx(ii))
end


fprintf('\tDone\n')
end

