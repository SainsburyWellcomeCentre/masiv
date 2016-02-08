classdef MaSIVMeta
    %MASIV Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=protected)
        metadata
        masivDirectory
        metaFileName
        stitchedImagePaths
    end
    
    properties(Dependent, SetAccess=protected)
        baseDirectory
        imageName
        downscaledStacks
        downscaledStackList
    end
    
    methods
        %% Constructor
        function obj=MaSIVMeta(filePath)
            if nargin<1 || isempty(filePath)
                filePath=obj.getMetaFile();
            end
                        
            if isempty(filePath) || ~exist(filePath, 'file')
                return
            end
            %% Set MaSIV Directory and file name
            [obj.masivDirectory, obj.metaFileName]=obj.splitPathFile(filePath); 
            %% Set Metadata, including base directory and image name
            obj.metadata=obj.getMeta(filePath);
            %% Get image paths
            obj=getImagePaths(obj);
        end
        %% Getters & Setters
        function val=get.baseDirectory(obj)
            if isrelpath(obj.metadata.baseDirectory)
                val=fullfile(obj.masivDirectory, obj.metadata.baseDirectory);
            else
                val=obj.metadata.baseDirectory;
            end
        end
        
        function val=get.imageName(obj)
            if isfield(obj.metadata, 'imageName') && ~isempty(obj.metadata.imageName)
                val=obj.metadata.imageName;
            else
                val=obj.baseDirectory;
            end
        end
        
        function ds=get.downscaledStacks(obj)
            pathToDSObjsFile=fullfile(obj.masivDirectory, [obj.imageName '_MaSIVStacks.mat']);
            if ~exist(pathToDSObjsFile, 'file')
                ds=[];
                fprintf('\n\n\t=====>  Directory %s contains no down-scaled image stacks  <=====\n',obj.baseDirectory)
                fprintf('\n\n\t\tINSTRUCTIONS')
                fprintf('\n\n\tYou will need to generate down-scaled image stacks in order to proceed.')
                fprintf('\n\tClick "New", then the channel you want to build, then the section range.')
                fprintf('\n\tSee documention on the web for more information.\n\n\n')
            else
                a=load(pathToDSObjsFile);
                ds=a.stacks;
                for ii=1:numel(ds)
                    ds(ii).updateFilePathMetaData(obj)
                end
            end
        end
        
        function dsl=get.downscaledStackList(obj)
            ds=obj.downscaledStacks;
            if ~isempty(ds)
                dsl=ds.list;
            else
                dsl=[];
            end
            dsl=dsl(:);
        end
    end
    
    methods(Static)      
        
        function yml=getMeta(filePath)
            yml=readSimpleYAML(filePath);
        end
        
        function metaFilePath=getMetaFile()
            [f,p]=uigetfile({'*Meta.yml', 'MaSIV Meta File(*Meta.txt)'}, 'Please select the MaSIV Meta File', gbSetting('defaultDirectory'));
            if isnumeric(f)
                metaFilePath='';
            else
                metaFilePath=fullfile(p,f);
            end
        end
        
        function [p,fe]=splitPathFile(filePath)
            [p,f,e]=fileparts(filePath);
            fe=[f e];
        end
                
    end
    
end


function obj=getImagePaths(obj)
    %Get paths to stitched (full-resolution) images from text files
    delimiterInTextFile='\r\n';
    searchPattern=[obj.imageName, '_ImageList_'];
    listFilePaths=dir(fullfile(obj.masivDirectory, [searchPattern '*.txt']));
    
    if isempty(listFilePaths)
        fprintf('\n\n\t*****\n\tCan not find text files listing the relative paths to the full resolution images.\n\tYou need to create these text files. Please see the documentation on the web.\n\tQUITING.\n\t*****\n\n\n')
        error('No %s*.txt files found.\n',searchPattern)
    end

    obj.stitchedImagePaths=struct;

    for ii=1:numel(listFilePaths)
        
        fh=fopen(fullfile(obj.masivDirectory, listFilePaths(ii).name));
            channelFilePaths=textscan(fh, '%s', 'Delimiter', delimiterInTextFile);
        fclose(fh);
        checkForAbsolutePaths(channelFilePaths{:})
        channelName=strrep(strrep(listFilePaths(ii).name, searchPattern, ''), '.txt', '');
        obj.stitchedImagePaths.(channelName)=channelFilePaths{:};
    end
end 

function checkForAbsolutePaths(strList)
    for ii = 1:numel(strList)
        s=strList{ii};
        if s(1)=='/' || ~isempty(regexp(s, '[A-Z]:/', 'ONCE'))
            error('File List appears to be absolute. ImageList files must contain relative paths, to prevent data loss')
        end
    end
end

function a=isrelpath(p)
    if p(1) == '/' || ~isempty(regexp(p, '[A-Z]:', 'ONCE'))
        a=false;
    else
        a=true;
    end
end
