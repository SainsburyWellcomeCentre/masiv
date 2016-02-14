classdef MaSIVMeta < handle
    %MASIV Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(Dependent, SetAccess=protected)
        imageName
    end
    
    properties(Dependent, SetAccess=protected)
        channelNames
        masivStacks % to do
        masivStackList % to do
    end
    
    properties(Dependent, SetAccess=protected)
        imageBaseDirectory
    end
    
    properties(SetAccess=protected)
        imageFilePaths
    end
    
    properties(SetAccess=protected)
        masivDirectory
        metaFileName
        metadata
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
        
        function val=get.imageName(obj)
            if isfield(obj.metadata, 'imageName') && ~isempty(obj.metadata.imageName)
                val=obj.metadata.imageName;
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


function obj=getimageFilePaths(obj)
    %Get paths to full-resolution images from text files
    delimiterInTextFile='\r\n';
    searchPattern=[obj.imageName, '_ImageList_'];
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
        obj.imageFilePaths.(channelName)=channelFilePaths{:};
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

function stacks=getMasivStacks(obj)

    stacks=[];

    files=dir(fullfile(obj.masivDirectory, '*.tif'));
    for ii=1:numel(files)
        filePath=fullfile(obj.masivDirectory, files(ii).name);
        msvInfo=MaSIVStack.infoFromTifFile(filePath);
        if ~isempty(msvInfo)
            [c, idx, xyds]=MaSIVStack.paramsFromText(msvInfo);
            newStack=MaSIVStack(obj, c, idx, xyds);            
            if isempty(stacks)
                stacks=newStack;
            else
                stacks=[stacks newStack];
            end
        end
        
    end
end
