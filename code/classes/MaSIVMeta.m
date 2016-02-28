classdef masivMeta < handle
    %MASIV Contains metadata about an stack for use with MaSIV
    
    properties(Dependent, SetAccess=protected)
        stackName % The name of the stack. Can be anything you like (doesn't have to correspond to file names)
    end
    
    properties(Dependent, SetAccess=protected)
        channelNames % Returns the available channels (as determined by which ImageList files are present)
        masivStacks  % Returns the masivStacks available on disk
        masivStackList % Returns a string summary of masivStacks
    end
    
    properties(Dependent, SetAccess=protected)
        imageBaseDirectory % The full path to the root of the image directory. Determined from the Meta file
    end
    
    properties(SetAccess=protected)
        imageFilePaths % Full file paths to individual slices of the MaSIV Stack
    end
    
    properties(SetAccess=protected)
        masivDirectory  % The directory in which the meta file and masiv tif stacks are stored
        metaFileName    % The file name of the masiv meta file 
        metadata        % Deserialised meta data
    end
    
    properties(Dependent, SetAccess=protected)
        VoxelSize       % Structure containing the x,y, and z size of the voxels
    end
    
    methods
        %% Constructor
        function obj=masivMeta(filePath)
            % MASIVMETA Constructor accepts a filepath to a YML file
            % containing metadata, or prompts the user for one. 
            if nargin<1 || isempty(filePath)
                filePath=obj.getMetaFile();
            end
                        
            if isempty(filePath) || ~exist(filePath, 'file')
                return
            end
            %% Set MaSIV Directory and file name
            [obj.masivDirectory, obj.metaFileName]=splitPathFile(filePath); 
            %% Set Metadata, including base directory and image name
            obj.metadata=obj.getMeta(filePath);
            %% Get image paths
            obj=getimageFilePaths(obj);
        end
        %% Getters & Setters
        function val=get.imageBaseDirectory(obj)
            if isrelpath(obj.metadata.baseDirectory)
                val=fullfile(obj.masivDirectory, obj.metadata.baseDirectory);
            else
                val=obj.metadata.baseDirectory;
            end
        end
        
        function val=get.stackName(obj)
            if isfield(obj.metadata, 'stackName') && ~isempty(obj.metadata.stackName)
                val=obj.metadata.stackName;
            else
                val=obj.imageBaseDirectory;
            end
        end
        
        function masivStacks=get.masivStacks(obj)
            masivStacks=getMasivStacks(obj);
            
            if isempty(masivStacks)
                masivStacks=[];
                fprintf('\n\n=====>  Directory %s contains no MaSIV down-scaled image stacks  <=====\n',obj.masivDirectory)
                fprintf('\n\n\tINSTRUCTIONS')
                fprintf('\n\n\tYou will need to generate down-scaled image stacks in order to proceed.')
                fprintf('\n\tClick "New", then the channel you want to build, then the section range.')
                fprintf('\n\tSee documention on the web for more information.\n\n\n')
            end
        end
        
        function dsl=get.masivStackList(obj)
            ms=obj.masivStacks;
            if ~isempty(ms)
                dsl={ms.name};
            else
                dsl=[];
            end
        end
        
        function c=get.channelNames(obj)
            c=fieldnames(obj.imageFilePaths);
        end
        
        function VS=get.VoxelSize(obj)
            VS=obj.metadata.VoxelSize;
        end
        
    end
    
    methods(Static)      
        
        function md=getMeta(filePath)
            % GETMETA Used to read the MaSIV metadata from a file 
            % (YML format in the current version)
            md=readSimpleYAML(filePath);
        end
        
        function metaFilePath=getMetaFile()
            % GETMETAFILE Used by the constructor to create a UI prompt to get a YML file 
            % from the user when none was provided
            
            [f,p]=uigetfile({'*Meta.yml', 'MaSIV Meta File(*Meta.yml)'}, 'Please select the MaSIV Meta File', gbSetting('defaultDirectory'));
            if isnumeric(f)
                metaFilePath='';
            else
                metaFilePath=fullfile(p,f);
                gbSetting('defaultDirectory', p);
            end
        end
        
        function createMetaFile()
            %% Get stack name
            t=inputdlg('Enter the stack name','MaSIV',  1, {'MyStack'});
            if isempty(t)
                warning('Meta file creation cancelled')
                return
            else
                s.stackName=t{1};
            end
            %% Get image dimensions
            t=inputdlg({'Voxel Size (x):', 'Voxel Size (y):', 'Voxel Size (z):'},s.stackName,  1, {'1', '1', '1'});
            if any(cellfun(@isempty, t)) || any(isnan(cellfun(@str2double, t)))
                warning('Invalid voxel size. Cancelling')
                return
            else
                s.VoxelSize.x=str2double(t{1}); 
                s.VoxelSize.y=str2double(t{2});
                s.VoxelSize.z=str2double(t{3});
            end
            %% Get base directory
            t=uigetdir([], 'Select the base directory where your images are located');
            
            if ischar(t) && exist(t, 'dir')
                s.baseDirectory=t;
            else
                warning('No base directory selected. Cancelling')
                return
            end
            %% Get masiv directory
            t=questdlg('Where do you want to create the MaSIV Directory?', s.stackName, 'Base Folder', 'Somewhere else...', 'Somewhere else...');
            
            switch t
                case 'Base Folder'
                    masivDir=fullfile(s.baseDirectory, [s.stackName, '_MaSIV']);
                    mkdir(masivDir);
                case 'Somewhere else...'
                    masivDir=uigetdir(s.baseDirectory, sprintf('Select directory for %s MaSIV Data', s.stackName));
                    if ~exist(masivDir, 'dir')
                        mkdir(masivDir)
                    end
                otherwise
                    warning('Operation cancelled')
            end
            %% Write YML file
            fileFullPath=fullfile(masivDir, [s.stackName '_Meta.yml']);
            writeSimpleYAML(s, fileFullPath);
            msgbox(sprintf('MaSIV Metadata file created at:\n\t%s\nYou now need to create ImageList files so that MaSIV can find your images. See the docs for details', fileFullPath))
            

            

        end
    end
    
    
end

function obj=getimageFilePaths(obj)
    %GETIMAGEFILEPATHS Returns paths to full-resolution images from ImageList files
    delimiterInTextFile='\r\n';
    searchPattern=[obj.stackName, '_ImageList_'];
    listFilePaths=dir(fullfile(obj.masivDirectory, [searchPattern '*.txt']));
    
    if isempty(listFilePaths)
        fprintf('\n\n\t*****\n\tCan not find text files listing the relative paths to the full resolution images.\n\tYou need to create these text files. Please see the documentation on the web.\n\tQUITING.\n\t*****\n\n\n')
        error('No %s*.txt files found.\n',searchPattern)
    end

    obj.imageFilePaths=struct;

    for ii=1:numel(listFilePaths)
        
        fh=fopen(fullfile(obj.masivDirectory, listFilePaths(ii).name));
            channelFilePaths=textscan(fh, '%s', 'Delimiter', delimiterInTextFile);
        fclose(fh);
        checkForAbsolutePaths(channelFilePaths{:})
        channelName=strrep(strrep(listFilePaths(ii).name, searchPattern, ''), '.txt', '');
        
        channelFilePaths=strtrim(channelFilePaths); % remove any trailing whitespace
        obj.imageFilePaths.(channelName)=channelFilePaths{:};
    end
end 

function stacks=getMasivStacks(obj)
    %GETMASIVSTACKS: gets all tif files in the masivDirectory of an object
    %that are valid masiv Stacks. Used by the masivStacks getter
    %
    % Note that no validation that these stacks are from the same stack are
    % performed. 

    stacks=[];

    files=dir(fullfile(obj.masivDirectory, '*.tif'));
    for ii=1:numel(files)
        filePath=fullfile(obj.masivDirectory, files(ii).name);
        msvInfo=masivStack.infoFromTifFile(filePath);
        if ~isempty(msvInfo)
            [c, idx, xyds]=masivStack.paramsFromText(msvInfo);
            newStack=masivStack(obj, c, idx, xyds);            
            if isempty(stacks)
                stacks=newStack;
            else
                stacks=[stacks newStack]; %#ok<AGROW>
            end
        end
        
    end
end

%%  File Path Utilities
function [p,fe]=splitPathFile(filePath)
    % SPLITPATHFILE: Splits a filepath in to the path and filename+extension
    [p,f,e]=fileparts(filePath);
    fe=[f e];
end

function checkForAbsolutePaths(strList)
    % CHECKFORABSOLUTEPATHS Runs a check on a cell array of strings,
    % checking each is a relative path. 
    %
    % Used when getting image file paths from the ImageList files 
    for ii = 1:numel(strList)
        s=strList{ii};
        if ~isrelpath(s)
            error('File List appears to be absolute. ImageList files must contain relative paths, to prevent data loss')
        end
    end
end

function a=isrelpath(p)
    % ISRELPATH: Checks whether a path is relative, by looking for an
    % initial '/' (for *nix) or a drive letter (for Windows)
    if p(1) == '/' || ~isempty(regexp(p, '[A-Z]:', 'ONCE'))
        a=false;
    else
        a=true;
    end
end

