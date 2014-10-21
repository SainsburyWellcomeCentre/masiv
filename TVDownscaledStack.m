classdef TVDownscaledStack<handle

    properties(Dependent, SetAccess=protected)
        name
    end
    
    properties(SetAccess=protected)
        baseDirectory
        experimentName
        sampleName
        
        gbStackDirectory
        fileName
        
        channel
        idx
        xyds
    end
    
    properties(Access=protected)
        mosaicInfo
        I_internal
        
    end
    
    properties(Dependent, SetAccess=protected)
        I
                
        imageInMemory
        fileOnDisk
    end
    
    properties(Dependent, Access=protected)
       gbStackInfoPath
    end
    
    methods
        %% Constructor
        function obj=TVDownscaledStack(varargin)
            % There are two ways to create a downscaledStack object:
            % 1. pass a stitchedMosaicInfo object, a channel, index and downscaling factor
            % 2. pass a YAML filename, to extract available downscaled
            % stacks
            switch class(varargin{1})
                case 'TVStitchedMosaicInfo'
                    [obj.mosaicInfo, obj.channel, obj.idx]=varargin{1:3};
                    if nargin>3
                        obj.xyds=varargin{4};
                    else
                        obj.xyds=1;
                    end
                    %% Copy some metadata stright from the mosaicInfo object; archive it just in case it's needed
                    obj.experimentName=obj.mosaicInfo.experimentName;
                    obj.sampleName=obj.mosaicInfo.sampleName;
                    obj.baseDirectory=obj.mosaicInfo.baseDirectory;

                    %% Get base directory for stacks and fileName for this stacks
                    obj.gbStackDirectory=getGBStackPath(obj.mosaicInfo);
                    obj.fileName=createGBStackFileNameForOutput(obj);
            end
        end
        %% Methods
        function generateStack(obj)
            if obj.imageInMemory
                error('Image already in memory')
            end
            obj.I_internal = createDownscaledStack( obj.mosaicInfo, obj.channel, obj.idx, obj.xyds);
        end
        function writeStackToDisk(obj)
            if obj.fileOnDisk
                error('File already exists on disk')
            end
            %% Write file locally
            fprintf('Writing file locally...\n')
            saveTiffStack(obj.I, 'tmp.tif');
            fprintf('Moving file in to place (%s)...', obj.gbStackDirectory)
            movefile('tmp.tif', obj.fileName)
            fprintf('Done. File saved to %s\n', obj.fileName)
            writeObjToMetadataFile(obj)
        end
        
        %% Getters 
        function g=get.gbStackInfoPath(obj)
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
                    obj.I_internal=loadTiffStack(obj.fileName);
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
        
        %% List
        function l=list(obj)
            l=cell(size(obj));
            for ii=1:numel(obj)
                l{ii}=obj(ii).name;
            end
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
if ~exist(obj.gbStackInfoPath, 'file')
    stacks=obj; %#ok<NASGU>
    save(obj.gbStackInfoPath, 'stacks')
else
    a=load(obj.gbStackInfoPath);
    stacks=a.stacks;
    stacks(end+1)=obj; %#ok<NASGU>
    save(obj.gbStackInfoPath, 'stacks');
end
fprintf('Done\n')
end
