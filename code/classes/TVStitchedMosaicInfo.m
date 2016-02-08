classdef TVStitchedMosaicInfo
    %TVSTITCHEDDATASETINFO Provides metadata on a particular, stitched TV
    %experiment
    
    properties(SetAccess=protected)
        baseDirectory
        experimentName
        sampleName
        stitchedImagePaths
        metaData
    end
    properties(Dependent, SetAccess=protected)
        downscaledStacks
        downscaledStackList
    end
    
    methods
        function obj=TVStitchedMosaicInfo(baseDirectory)
            
            %% Error checking
            if nargin<1
                error('No path specified')
            elseif ~exist(baseDirectory, 'dir')
                error('Specified path does not exist')
            end

            %% Get file parts
            [~, obj.experimentName]=fileparts(baseDirectory);
            obj.baseDirectory=baseDirectory;

            %% Get metadata
            obj=getMetaData(obj);            
            obj=getStitchedImagePaths(obj);
        end

        function ds=get.downscaledStacks(obj)
            masivDir=getMasivDirPath(obj);
            pathToDSObjsFile=fullfile(masivDir, [obj.sampleName '_MaSIVStacks.mat']);
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

        function obj=changeImagePaths(obj, strToReplace, newStr)
                % Allows batch editing of the image paths. This can be
                % needed if the base directory is changed
                
                s=fieldnames(obj.stitchedImagePaths);
                for ii=1:numel(s)
                    obj.stitchedImagePaths.(s{ii})=strrep(obj.stitchedImagePaths.(s{ii}), strToReplace, newStr);
                end
            
        end
    end
    
end


function obj=getStitchedImagePaths(obj)
    %Get paths to stitched (full-resolution) images from text files
    delimiterInTextFile='\r\n';
    searchPattern=[obj.sampleName, '_ImageList_'];
    baseDir=getMasivDirPath(obj);
    listFilePaths=dir(fullfile(baseDir, [searchPattern '*.txt']));
    
    if isempty(listFilePaths)
        fprintf('\n\n\t*****\n\tCan not find text files listing the relative paths to the full resolution images.\n\tYou need to create these text files. Please see the documentation on the web.\n\tQUITING.\n\t*****\n\n\n')
        error('No %s*.txt files found.\n',searchPattern)
    end

    obj.stitchedImagePaths=struct;

    for ii=1:numel(listFilePaths)
        
        fh=fopen(fullfile(baseDir, listFilePaths(ii).name));
            channelFilePaths=textscan(fh, '%s', 'Delimiter', delimiterInTextFile);
        fclose(fh);
        checkForAbsolutePaths(channelFilePaths{:})
        channelName=strrep(strrep(listFilePaths(ii).name, searchPattern, ''), '.txt', '');
        obj.stitchedImagePaths.(channelName)=channelFilePaths{:};
    end
end %function obj=getStitchedImagePaths(obj)

function checkForAbsolutePaths(strList)
    for ii = 1:numel(strList)
        s=strList{ii};
        if s(1)=='/' || ~isempty(regexp(s, '[A-Z]:/', 'ONCE'))
            error('File List appears to be absolute. ImageList files must contain relative paths, to prevent data loss')
        end
    end
end

function obj=getMetaData(obj)
    d = getMasivDirPath(obj);
    ymlFile=dir(fullfile(d, '*Meta.yml'));
    if isempty(ymlFile)
        error('No metadata file found')
    elseif numel(ymlFile)>1
        error('Multiple possible metadata files found. Ensure that there is only one file matching the pattern ''*Meta.yml'' in the MaSIV directory for this dataset')
    end
    ymlFileFullPath=fullfile(d, ymlFile.name);
    obj.metaData=readSimpleYAML(ymlFileFullPath);
    obj.sampleName=obj.metaData.sampleName;
end