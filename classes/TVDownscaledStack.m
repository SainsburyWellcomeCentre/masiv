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
        function obj=TVDownscaledStack(mosaicInfo, channel, idx, xyds)
            % There is currently one way to create a downscaledStack object:
            % 1. pass a stitchedMosaicInfo object, a channel, index and downscaling factor
            % 2. pass just the stitchedMosaicInfo object to generate a
            % pop-up dialog
            obj.mosaicInfo = mosaicInfo;
            if nargin>1
                obj.channel = channel;
                obj.idx = idx;
                if nargin>3
                    obj.xyds=xyds;
                else
                    obj.xyds=1;
                end
            else
                [obj.channel, obj.idx, obj.xyds]=getDSStackSpec(mosaicInfo);
                if isempty(obj.channel);
                    return
                end
            end
            %% Copy some metadata stright from the mosaicInfo object; archive it just in case it's needed
            obj.updateFilePathMetaData(obj.mosaicInfo)
            
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
            obj.I_internal=loadTiffStack(obj.fileName, [], 'g');
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

swb=SuperWaitBar(numel(idx), 'Getting image info...');
parfor ii=1:numel(idx)
    info{ii}=imfinfo(pths{ii});
    swb.progress(); %#ok<PFBNS>
end
delete(swb);
clear swb

%%
minWidth=min(cellfun(@(x) x.Width, info));
minHeight=min(cellfun(@(x) x.Height, info));

outputImageWidth=ceil(minWidth/q.downSample);
outputImageHeight=ceil(minHeight/q.downSample);


I=zeros(outputImageHeight, outputImageWidth, numel(idx), 'uint16');

swb=SuperWaitBar(numel(idx), 'Generating stack...');
parfor ii=1:numel(idx)
    fName=fullfile(mosaicInfo.baseDirectory, mosaicInfo.stitchedImagePaths.(channel){idx(ii)}); %#ok<PFBNS>
    I(:,:,ii)=openTiff(fName, [1 1 minWidth minHeight], q.downSample); %#ok<PFBNS>
    swb.progress(); %#ok<PFBNS>
end
delete(swb);
clear swb

end

function [channel, idx, xyds]=getDSStackSpec(mosaicInfo)

    %% Channel
    availableChannels=fieldnames(mosaicInfo.stitchedImagePaths);
    resp=menu('Select channel to create stack from:', availableChannels{:}, 'Cancel');
    if ~(resp>numel(availableChannels))
        channel=availableChannels{resp};
    else
        channel=[];
        idx=[];
        xyds=[];
        return
    end
    
    %% Index
    passFlag=0;
    
    while passFlag~=1
        
        idxStr=inputdlg({'Start', 'Increment', 'End'},'Use slices:', 1, ...
            {'1', '10', num2str(numel(mosaicInfo.stitchedImagePaths.(channel)))});
        
        if isempty(idxStr)
            channel=[];
            idx=[];
            xyds=[];
            return
        else
            startIdx=str2num(idxStr{1}); %#ok<ST2NM>
            increment=str2num(idxStr{2}); %#ok<ST2NM>
            endIdx=str2num(idxStr{3}); %#ok<ST2NM>
        end
        
        passFlag=isscalar(startIdx)&&isnumeric(startIdx)&&...
            isscalar(increment)&&isnumeric(increment) &&...
            isscalar(endIdx)&&isnumeric(endIdx) &&...
            endIdx>startIdx;
    end
    
    idx=startIdx:increment:endIdx;
    
    %% xyds
    passFlag=0;
    while passFlag~=1
        xydsStr=inputdlg('Scale factor to reduce image size in X and Y:','XY Downsampling Factor', 1,{'10'});
        if isempty(xydsStr)
            channel=[];
            idx=[];
            xyds=[];
            return
        else
            xyds=str2num(xydsStr{1}); %#ok<ST2NM>
        end
        
        passFlag=isscalar(xyds)&&isnumeric(xyds)&&round(xyds)==xyds;
    end
end



