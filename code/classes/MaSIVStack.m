classdef MaSIVStack<handle
    properties(Dependent, SetAccess=protected)
        name
        imageName
        fileName
    end
    
    properties(SetAccess=protected)
        meta
        channel
        idx
        xyds
    end
    
    properties(Access=protected)
        I_internal
        xInternal
        yInternal
        zInternal
    end
    
    properties(Dependent, SetAccess=protected)
        I
        
        imageInMemory
        fileOnDisk
        
        xCoordsVoxels
        yCoordsVoxels
        zCoordsVoxels
        
        xCoordsUnits
        yCoordsUnits
        zCoordsUnits
    end
    
    methods
        function obj=MaSIVStack(metaObject, varargin)
            % There are two ways of creating a MaSIVStack
            %
            % 1. MaSIVStack(metaObject) 
            %       Will create a MaSIVStack, prompting the user for the channel, indices, and downsampling
            % 2. MaSIVStack(metaObject, channel, [idx], [xyds])
            %       Will create a MaSIV stack in the specified channel.
            %       Index should be an array, if specified, otherwise all images will be used
            %       xyds should be a scalar, if specified, otherwise it will be set to 1

            if nargin < 1
                error('Requires at least one input argument')
            else
                if isa(metaObject, 'MaSIVMeta')
                    obj.meta=metaObject;
                    
                    if nargin > 1
                        if ischar(varargin{1}) && ismember(varargin{1}, obj.meta.channelNames)
                            obj.channel=varargin{1};
                        else
                            error('''%s'' is not a valid channel', varargin{1})
                        end
                        
                        if nargin > 2
                            if isvector(varargin{2}) && isnumeric(varargin{2})
                                obj.idx=varargin{2};
                            else
                                error('Index specification should be a numeric vector')
                            end
                        else
                            obj.idx=1:numel(obj.meta.imagePaths.(obj.channel));
                        end
                        
                        if nargin > 3
                            if isnumeric(varargin{3}) && isscalar(varargin{3}) && varargin{3} == round(varargin{3})
                                obj.xyds=varargin{3};
                            else
                                error('XY downscaling should be a scalar integer')
                            end
                        else
                            obj.xyds=1;
                        end
                        
                    else
                        [obj.channel, obj.idx, obj.xyds]=getStackSpec(metaObject);
                        if isempty(obj.channel)||isempty(obj.idx)||isempty(obj.xyds);
                            return
                        end
                    end
                else
                    error('MaSIVStack requires a MaSIVMeta object to create')
                end
            end
            
        end
    end
    
    %% Getters and Setters
    methods
        function nm=get.imageName(obj)
            nm=obj.meta.imageName;
        end
        
        function nm=get.name(obj)
            [~, f]=fileparts(obj.fileName);
            nm=matlab.lang.makeValidName(f);
            nm=strrep(nm, '__', '_');
        end
        
        function fnm=get.fileName(obj)
            imgName=sprintf('%s_%s_Stack[%u-%u]_DS%u.tif', obj.imageName, obj.channel, min(obj.idx), max(obj.idx), obj.xyds);
            fnm=fullfile(obj.meta.masivDirectory, imgName);
        end
        
        function inMem=get.imageInMemory(obj)
            inMem=~isempty(obj.I_internal);
        end
        
        function onDisk=get.fileOnDisk(obj)
            onDisk=exist(obj.fileName, 'file')~=0;
        end
        
        function x=get.xCoordsVoxels(obj)
            if isempty(obj.xInternal)
                if isempty(obj.I_internal)
                    error('Image not loaded in to memory. Can not return x dimension')
                else
                    obj.xInternal=1:obj.xyds:size(obj.I_internal, 2)*obj.xyds;
                end
            end
            x=obj.xInternal;
        end
        
        function y=get.yCoordsVoxels(obj)
           if isempty(obj.yInternal)
                if isempty(obj.I_internal)
                    error('Image not loaded in to memory. Can not return y dimension')
                else
                    obj.yInternal=1:obj.xyds:size(obj.I_internal, 1)*obj.xyds;
                end
            end
            y=obj.yInternal;
        end

        function z=get.zCoordsVoxels(obj)
            if isempty(obj.zInternal)
                obj.zInternal=obj.idx;
            end
           z=obj.zInternal;
        end
        
        function x=get.xCoordsUnits(obj)
            x=(obj.xCoordsVoxels-1)*obj.metadata.VoxelSize.x;
         end 

        function y=get.yCoordsUnits(obj)
           y=(obj.yCoordsVoxels-1)*obj.metadata.VoxelSize.y;
        end

        function z=get.zCoordsUnits(obj)
            z=(obj.zCoordsVoxels-1)*obj.metadata.VoxelSize.z;
        end
    end
    
    %% Serialisation / Deserialisation
    methods
        function save(obj)
            targetYMLFile={};
            for ii=1:numel(obj)
                targetYMLFile{end+1}=obj(ii).meta.masivStackYMLFilePath; %#ok<AGROW>
            end
            if numel(unique(targetYMLFile))>1
                error('MaSIVStack array appears to come from different images. Can''t save.')
            else
                targetYMLFile=unique(targetYMLFile);
            end
            s=toStruct(obj);
            writeSimpleYAML(s, targetYMLFile{:})
        end
    end
    
    
end

function t=toStruct(obj)
    s=struct('channel', {obj.channel}, 'idx', {obj.idx}, 'xyds', {obj.xyds});
    t.data=s;
end

function [channel, idx, xyds]=getStackSpec(metaObject)
    %% Channel
    availableChannels=metaObject.channelNames;
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
            {'1', '1', num2str(numel(metaObject.imagePaths.(channel)))});
        
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
            startIdx>=1 && endIdx<=numel(metaObject.imagePaths.(channel)) && ...
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

