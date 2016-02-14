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
        %% Methods
        function generateStack(obj)
            if obj.imageInMemory
                error('Image already in memory')
            end
            obj.I_internal = createDownscaledStack(obj);
        end
        
        function loadStackFromDisk(obj)
            if obj.imageInMemory
                error('Image already in memory')
            end
            obj.I_internal=loadTiffStack(obj.fileName, [], 'g');
        end

        %% Getters and Setters
        
        function nm=get.imageName(obj)
            nm=obj.meta.imageName;
        end
        
        function nm=get.name(obj)
            nm=sprintf('%s_%s_Stack[%u-%u]_DS%u', obj.imageName, obj.channel, min(obj.idx), max(obj.idx), obj.xyds);
        end
        
        function fnm=get.fileName(obj)
            fnm='';
            possibleMatchesForThisObject=dir(fullfile(obj.meta.masivDirectory, [obj.name '*.tif']));
            for ii=1:numel(possibleMatchesForThisObject)
                fullFilePath=fullfile(obj.meta.masivDirectory, possibleMatchesForThisObject(ii).name);
                inf=imfinfo(fullFilePath);
                
                firstInf=inf(1); %only need the first
                
                if ~isfield(firstInf, 'ImageDescription') %no image description, so it can't be what we're looking for
                    break
                end
                
                [file_channel,file_idx,file_xyds]=MaSIVStack.paramsFromText(firstInf.ImageDescription);
                
                if strcmp(file_channel, obj.channel) && ...
                   numel(file_idx)==numel(obj.idx) && ...
                   all(file_idx==obj.idx) && ...
                   file_xyds==obj.xyds
               
                        fnm=fullFilePath;
                        break
                end
            end
        end
        
        function inMem=get.imageInMemory(obj)
            inMem=~isempty(obj.I_internal);
        end
        
        function onDisk=get.fileOnDisk(obj)
            onDisk=~isempty(obj.fileName);
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
            x=(obj.xCoordsVoxels-1)*obj.meta.VoxelSize.x;
         end 

        function y=get.yCoordsUnits(obj)
           y=(obj.yCoordsVoxels-1)*obj.meta.VoxelSize.y;
        end

        function z=get.zCoordsUnits(obj)
            z=(obj.zCoordsVoxels-1)*obj.meta.VoxelSize.z;
        end
   
        %% Serialisation / Deserialisation
               
        function writeStackToDisk(obj)
            if obj.fileOnDisk
                error('File already exists on disk')
            end
            %% Set up custom tag list
            tagList={'ImageDescription', obj.toText};
            %% Write file locally first to prevent network transport errors
            tempFileName=[tempname '.tif'];
            saveTiffStack(obj.I, tempFileName, 'g', tagList);
            swb=SuperWaitBar(1, strrep(sprintf('Moving file in to place (%s)', obj.fileName), '_', '\_'));
            movefile(tempFileName, obj.generateValidNewFileName)
            swb.progress();delete(swb);clear swb
        end
        
        function t=toText(obj)
            t=sprintf('MaSIV Stack generated from %s\nChannel: %s\nIndex: %s\nXYDS: %u', obj.imageName, obj.channel, mat2str(obj.idx), obj.xyds);
        end
        
        function fnm=generateValidNewFileName(obj)
            baseName=fullfile(obj.meta.masivDirectory, obj.name);
            filesThatMatch=dir([baseName, '*.tif']);
            if isempty(filesThatMatch)
                fnm=[baseName '.tif'];
            else
                suffix=getLastNumberSuffix({filesThatMatch.name}, obj.name);
                fnm=[baseName '_' suffix '.tif'];                
            end
        end
    end
    
    methods(Static)
        
        function [channel, idx, xyds]=paramsFromText(txt)
           txt=strsplit(txt, '\n');
           
           channel = getKeyPair(txt{2}, 'Channel');
           idx     = getKeyPair(txt{3}, 'Index', @str2num);
           xyds    = getKeyPair(txt{4}, 'XYDS', @str2num);
           
        end
    end
    
    
end

function t=getKeyPair(txt, expectedName, convertFun)
    keyval=strsplit(txt, ':');
    if ~strcmp(keyval{1}, expectedName)
        error('Bad text specification')
    else
        t=strtrim(keyval{2});
    end
    if nargin > 2
        t=convertFun(t);
    end
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

function I = createDownscaledStack(obj)
    if nargin < 1 || isempty(obj) || ~isa(obj, 'MaSIVStack')
       error('Requires a valid MaSIVStack object')
    end
    
    %% Start default parallel pool if not already
    gcp;
    
    %% Generate full file path
    pths=fullfile(obj.meta.baseDirectory, obj.meta.imagePaths.(obj.channel)(obj.idx));
    %% Get file information to determine crop
    info=cell(numel(obj.idx), 1);
    
    swb=SuperWaitBar(numel(obj.idx), 'Getting image info...');
    parfor ii=1:numel(obj.idx)
        info{ii}=imfinfo(pths{ii});
        swb.progress(); %#ok<PFBNS>
    end
    delete(swb);
    clear swb
    
    %%
    minWidth=min(cellfun(@(x) x.Width, info));
    minHeight=min(cellfun(@(x) x.Height, info));
    
    outputImageWidth=ceil(minWidth/obj.xyds);
    outputImageHeight=ceil(minHeight/obj.xyds);
    
    
    I=zeros(outputImageHeight, outputImageWidth, numel(obj.idx), 'uint16');
    if usejava('jvm')&&~feature('ShowFigureWindows') %Switch to console display if no graphics available
        parfor ii=1:numel(obj.idx)
            fName=fullfile(obj.meta.baseDirectory, obj.meta.imagePaths.(obj.channel){obj.idx(ii)}); %#ok<PFBNS>
            I(:,:,ii)=openTiff(fName, [1 1 minWidth minHeight], obj.xyds);
            fprintf('Generating downscaledStack: processing image %u of %u', numel(idx), ii)
        end        
    else
        swb=SuperWaitBar(numel(obj.idx), 'Generating stack...');
        parfor ii=1:numel(obj.idx)
            fName=fullfile(obj.meta.baseDirectory,obj.meta.imagePaths.(obj.channel){obj.idx(ii)}); %#ok<PFBNS>
            I(:,:,ii)=openTiff(fName, [1 1 minWidth minHeight], obj.xyds); 
            swb.progress(); %#ok<PFBNS>
        end
        delete(swb);
        clear swb
    end
end

function suffix=getLastNumberSuffix(listOfFileNames, pattern)
    if numel(listOfFileNames)==1;
        suffix='1';
    else
        for ii=1:numel(listOfFileNames)
            listOfFileNames{ii}=strrep(listOfFileNames{ii}, pattern, ''); % get rid of base name
            listOfFileNames{ii}=strrep(listOfFileNames{ii}, '.tif', '');  % get rid of extension
            listOfFileNames{ii}=strrep(listOfFileNames{ii}, '_', '');     % get rid of preceding underscore
        end
        listOfFileNames=listOfFileNames(~cellfun(@isempty, listOfFileNames)); %remove blank entry
        nums=cellfun(@str2num, listOfFileNames);
        
        nums=sort(nums);
        
        suffix=num2str(nums(end)+1);
    end
end

