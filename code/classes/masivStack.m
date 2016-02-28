classdef masivStack<handle
    % MASIVSTACK Represents a downscaled stack used by MaSIV
    %
    % This class handles the creation, use, and deletion of a particular
    % MaSIV Stack. Stacks are stored in the MaSIV directory (the same
    % directory as the meta file), and are pulled from disk if available,
    % or created as needed
    properties(Dependent, SetAccess=protected)
        name            % The name of this particular stack
        stackName       % The name of the MaSIV dataset, taken from the meta file (stackName)
        fileFullPath    % The full path to the tif file of the stack. Blank if not on disk.
    end
    
    properties(SetAccess=protected)
        MetaObject  % Reference to the masivMeta object used to create this stack
        channel     % The name of the channel on which this stack is generated
        idx         % The index of each stack slice, in the original dataset
        xyds        % The downsampling factor, in xy, for the stack
    end
    
    properties(Access=protected)
        I_internal      % Image matrix, used internally
        xInternal       % The x index (1-based) in the original data set of each pixel (used internally)
        yInternal       % The y index in the original data set of each pixel (used internally)
        zInternal       % The z index in the original data set of each pixel (used internally)
    end
    
    properties(Dependent, SetAccess=protected)
        I               % Downscaled image data
        
        imageInMemory   % Boolean flag for whether the data has been loaded in to memory
        fileOnDisk      % Boolean flag for whether the image has been saved to disk
        
        xCoordsVoxels   % The x index (1-based) in the original data set of each pixel
        yCoordsVoxels   % The y index (1-based) in the original data set of each pixel
        zCoordsVoxels   % The z index (1-based) in the original data set of each pixel
        
        xCoordsUnits    % Distance from the origin of each pixel in the x coordinate, in units. The first voxel has distance 0
        yCoordsUnits    % Distance from the origin of each pixel in the y coordinate, in units. The first voxel has distance 0
        zCoordsUnits    % Distance from the origin of each pixel in the z coordinate, in units. The first voxel has distance 0
        
        originalImageFilePaths % File path to original image files (relative to base directory)
    end
    
    methods
        %% Constructor
        function obj=masivStack(metaObject, varargin)
            % MaSIV Stacks can be created either interactively or by specifying channel and, optionally, index and downsampling
            %
            % 1. masivStack(metaObject)
            %       Will create a masivStack, prompting the user for the channel, indices, and downsampling
            % 2. masivStack(metaObject, channel, [idx], [xyds])
            %       Will create a MaSIV stack in the specified channel.
            %       Index should be an array, if specified, otherwise all images will be used
            %       xyds should be a scalar, if specified, otherwise it will be set to 1
            
            if nargin < 1
               return
            else
                if isa(metaObject, 'masivMeta')
                    obj.MetaObject=metaObject;
                    
                    if nargin > 1
                        if ischar(varargin{1}) && ismember(varargin{1}, obj.MetaObject.channelNames)
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
                            obj.idx=1:numel(obj.MetaObject.imageFilePaths.(obj.channel));
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
                    error('masivStack requires a masivMeta object to create')
                end
            end
            
        end
        
        %% Getters and Setters
        
        function nm=get.stackName(obj)
            nm=obj.MetaObject.stackName;
        end
        
        function nm=get.name(obj)
            nm=sprintf('%s_%s_Stack[%u-%u]_DS%u', obj.stackName, obj.channel, min(obj.idx), max(obj.idx), obj.xyds);
        end
        
        function fnm=get.fileFullPath(obj)
            fnm='';
            possibleMatchesForThisObject=dir(fullfile(obj.MetaObject.masivDirectory, [obj.name '*.tif']));
            for ii=1:numel(possibleMatchesForThisObject)
                fullFilePath=fullfile(obj.MetaObject.masivDirectory, possibleMatchesForThisObject(ii).name);

                masivImageDescription=masivStack.infoFromTifFile(fullFilePath);
                
                if ~isempty(masivImageDescription)
                    %% get parameters
                    [file_channel,file_idx,file_xyds]=masivStack.paramsFromText(masivImageDescription);
                    %% check they match. If so, set file name and break
                    if strcmp(file_channel, obj.channel) && ...
                            numel(file_idx)==numel(obj.idx) && ...
                            all(file_idx==obj.idx) && ...
                            file_xyds==obj.xyds
                        
                        fnm=fullFilePath;
                        break
                    end
                end
            end
        end
        
        function inMem=get.imageInMemory(obj)
            inMem=~isempty(obj.I_internal);
        end
        
        function onDisk=get.fileOnDisk(obj)
            onDisk=~isempty(obj.fileFullPath);
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
            x=(obj.xCoordsVoxels-1)*obj.MetaObject.VoxelSize.x;
         end 

        function y=get.yCoordsUnits(obj)
           y=(obj.yCoordsVoxels-1)*obj.MetaObject.VoxelSize.y;
        end

        function z=get.zCoordsUnits(obj)
            z=(obj.zCoordsVoxels-1)*obj.MetaObject.VoxelSize.z;
        end
        
        function ofn=get.originalImageFilePaths(obj)
            ofn=obj.MetaObject.imageFilePaths.(obj.channel);
        end
   
        %% Stack creation, writing, loading, deletion
        
        function generateStack(obj)
            % GENERATESTACK Creates the stack (in memory) from original image files
            if obj.imageInMemory
                error('Image already in memory')
            end
            obj.I_internal = createDownscaledStack(obj);
        end
               
        function writeStackToDisk(obj)
            %WRITESTACKTODISK Writes the stack to a MaSIV tif file. 
            % 
            % If the stack does not already exist in memory, it will be
            % generated
            %
            % Note that the file will first be written to your temp
            % directory, to prevent network transport errors
            if obj.fileOnDisk
                error('File already exists on disk')
            end
            %% Set up custom tag list
            tagList={'ImageDescription', obj.toText};
            %% Write file locally first to prevent network transport errors
            tempFileName=[tempname '.tif'];
            saveTiffStack(obj.I, tempFileName, 'g', tagList);
            thisStackFilePath=generateValidNewFileName(obj);
            swb=SuperWaitBar(1, strrep(sprintf('Moving file in to place (%s)', thisStackFilePath), '_', '\_'));
            movefile(tempFileName, thisStackFilePath)
            swb.progress();delete(swb);clear swb
        end
        
        function loadStackFromDisk(obj)
            % LOADSTACKFROMDISK Reads the stack from a MaSIV tif file
             if obj.imageInMemory
                error('Image already in memory')
             end
            obj.I_internal=loadTiffStack(obj.fileFullPath, [], 'g');
        end
        
        function stdout=deleteStackFromDisk(obj)
            % DELETESTACKFROMDISK Removes the MaSIV tif file for this stack
            if ~obj.fileOnDisk
                stdout=0;
                return
            end
            button=questdlg(sprintf('Are you sure you want to delete stack %s?\nThis CANNOT be undone!', obj.name), ...
                'Confirm Stack Deletion', 'OK', 'Cancel', 'Cancel');
            if strcmp(button, 'OK')
                delete(obj.fileFullPath)
                stdout=1;
            else
                stdout=0;
            end
        end
        
        %% Utils
        
        function t=toText(obj)
            % TOTEXT Returns a text representation of the spec used to create this stack.
            %
            % Used by writeStackToDisk to embed metadata in the tif file
            idxStr=getIdxStringRepresentation(obj);
            t=sprintf('MaSIV Stack generated from %s\nChannel: %s\nIndex: %s\nXYDS: %u', obj.stackName, obj.channel, idxStr, obj.xyds);
        end
        
    end
    
    methods(Static)
        function [channel, idx, xyds]=paramsFromText(txt)
           %PARAMSFROMTEXT Converts a text specification in to specs
           %
           % Used when reading in a MaSIV tif file, to create an object, or
           % check whether it matches a given object
           txt=strsplit(txt, '\n');
           
           channel = getKeyPair(txt{2}, 'Channel');
           idx     = getKeyPair(txt{3}, 'Index', @str2num);
           xyds    = getKeyPair(txt{4}, 'XYDS', @str2num);
           
        end
        function masivImageDescription=infoFromTifFile(fullPathToFile)
            % INFOFROMTEXTFILE Reads in the first ImageDescription tag of a tif file
            %
            % Used when interrogating tif files to determine if they are a
            % MaSIV tif file, and if so, what the spec was
            T=Tiff(fullPathToFile, 'r');
            try
                masivImageDescription=T.getTag('ImageDescription');
            catch
                % no such tag, so set to empty
                masivImageDescription='';
            end
            T.close;
        end
    end
    
    
end

function [channel, idx, xyds]=getStackSpec(metaObject)
    %GETSTACKSPEC Gets user-specified parameters to create a masivStack
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
            {'1', '1', num2str(numel(metaObject.imageFilePaths.(channel)))});
        
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
            startIdx>=1 && endIdx<=numel(metaObject.imageFilePaths.(channel)) && ...
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
    %CREATEDOWNSAMPLEDSTACK Generates the stack from original image files
    %
    % Uses parallel toolbox to perform generation in a reasonable time
    if nargin < 1 || isempty(obj) || ~isa(obj, 'masivStack')
       error('Requires a valid masivStack object')
    end
    
    %% Start default parallel pool if not already
    gcp;
    
    %% Generate full file path
    pths=fullfile(obj.MetaObject.imageBaseDirectory, obj.MetaObject.imageFilePaths.(obj.channel)(obj.idx));
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
            fName=fullfile(obj.MetaObject.imageBaseDirectory, obj.MetaObject.imageFilePaths.(obj.channel){obj.idx(ii)}); %#ok<PFBNS>
            I(:,:,ii)=openTiff(fName, [1 1 minWidth minHeight], obj.xyds);
            fprintf('Generating downscaledStack: processing image %u of %u', numel(idx), ii)
        end        
    else
        swb=SuperWaitBar(numel(obj.idx), 'Generating stack...');
        parfor ii=1:numel(obj.idx)
            fName=fullfile(obj.MetaObject.imageBaseDirectory,obj.MetaObject.imageFilePaths.(obj.channel){obj.idx(ii)}); %#ok<PFBNS>
            I(:,:,ii)=openTiff(fName, [1 1 minWidth minHeight], obj.xyds); 
            swb.progress(); %#ok<PFBNS>
        end
        delete(swb);
        clear swb
    end
end

%% File name specification

function fnm=generateValidNewFileName(obj)
    % GENERATEVALIDNEWFILENAME Returns a unique name appropriate for this stack
    %
    % This will be the object name, with a unique number if more than one
    % MaSIV stack would exist with the same name e.g. from the same
    % channel, same downsampling, and with identical first and last indices
    baseName=fullfile(obj.MetaObject.masivDirectory, obj.name);
    filesThatMatch=dir([baseName, '*.tif']);
    if isempty(filesThatMatch)
        fnm=[baseName '.tif'];
    else
        suffix=getLastNumberSuffix({filesThatMatch.name}, obj.name);
        fnm=[baseName '_' suffix '.tif'];
    end
end

function suffix=getLastNumberSuffix(listOfFileNames, pattern)
    % GETLASTNUMBERSUFFIX Scans a list of files to determine what the next unique suffix should be
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

%% Utils

function t=getKeyPair(txt, expectedName, convertFun)
    % GETKEYPAIR Gets the value of a name-value pair with known name from a string of the form 'key: value'.
    %
    % Used in reading spec from MaSIV Stack ImageDescription tag
    keyval=strsplit(txt, ':');
    if numel(keyval) > 2 && strcmp(expectedName, 'Index')
        keyval{2}=strjoin(keyval(2:end), ':');
        keyval=keyval(1:2);
    end
    if ~strcmp(keyval{1}, expectedName)
        error('Bad text specification')
    else
        t=strtrim(keyval{2});
    end
    if nargin > 2
        t=convertFun(t);
    end
end

function idxStr=getIdxStringRepresentation(obj)

    if numel(obj.idx)==1;
        idxStr=num2str(obj.idx);
    elseif numel(obj.idx)==2
        idxStr=mat2str(obj.idx);
    else
        d=unique(diff(obj.idx));
        if numel(d)==1
            idxStr=sprintf('[%u:%u:%u]', obj.idx(1), d, obj.idx(end));
        else
            idxStr=mat2str(obj.idx);
        end
    end
end
