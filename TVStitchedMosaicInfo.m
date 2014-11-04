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
            obj=getMosaicMetaData(obj);
            obj.sampleName=obj.metaData.SampleID;
            
            obj=getStitchedImagePaths(obj);
            %% Get available downscaled stacks
        end
        function ds=get.downscaledStacks(obj)
            pathToDSObjsFile=fullfile(obj.baseDirectory, [obj.sampleName '_GBStacks'], [obj.sampleName '_GBStackInfo.mat']);
            if ~exist(pathToDSObjsFile, 'file')
                ds=[];
            else
                a=load(pathToDSObjsFile);
                ds=a.stacks;
            end
        end
        function dsl=get.downscaledStackList(obj)
            dsl=obj.downscaledStacks.list;
            dsl=dsl(:);
        end
        
    end
    
end

function obj=getMosaicMetaData(obj)

delimiterInTextFile='\r\n';

%% Get matching files
metaDataFileName=dir(fullfile(obj.baseDirectory,'Mosaic*.txt'));
if isempty(metaDataFileName)
    error('Mosaic metadata file not found')
elseif numel(metaDataFileName)>1
    error('Multiple metadata files found. There should only be one matching ''Mosaic*.txt''')
end

metaDataFullPath=fullfile(obj.baseDirectory, metaDataFileName.name);

%% Open
fh=fopen(metaDataFullPath);
%% Read
txtFileContents=textscan(fh, '%s', 'Delimiter', delimiterInTextFile);
txtFileContents=txtFileContents{1};
%% Parse
info=struct;
for ii=1:length(txtFileContents)
    spl=strsplit(txtFileContents{ii}, ':');
    
    if numel(spl)<2
        error('Invalid name/value pair: %s', txtFileContents{ii})
    elseif numel(spl)>2
        spl{2}=strjoin(spl(2:end), ':');
        spl=spl(1:2);
    end
    nm=strrep(spl{1}, ' ', '');
    val=spl{2};
    valNum=str2double(val);
    if ~isempty(valNum)&&~isnan(valNum)
        val=valNum;
    end
    
    info.(nm)=val;
    
end
%% Close
fclose(fh);
%% Assign
obj.metaData=info;
end

function obj=getStitchedImagePaths(obj)

delimiterInTextFile='\r\n';

searchPattern=[obj.sampleName, '_StitchedImagesPaths_'];

listFilePaths=dir(fullfile(obj.baseDirectory, [searchPattern '*.txt']));

obj.stitchedImagePaths=struct;

for ii=1:numel(listFilePaths)
  
    
    %% Open txt file
    fp=fullfile(obj.baseDirectory, listFilePaths(ii).name);
    fh=fopen(fp);
    %% Read in file paths
    channelFilePaths=textscan(fh, '%s', 'Delimiter', delimiterInTextFile);
    %% Close
    fclose(fh);
    
    %% strip out absolute path to get relative file paths
    channelFilePaths=strrep(channelFilePaths{1}, [fileparts(fileparts(channelFilePaths{1}{1})) '/'], '');
    %% Get channel name
    channelName=strrep(strrep(listFilePaths(ii).name, searchPattern, ''), '.txt', '');
    %% Assign
    obj.stitchedImagePaths.(channelName)=channelFilePaths;
end
end

