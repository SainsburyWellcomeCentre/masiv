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
            
            obj.metadata=obj.getMeta(filePath);
            [obj.masivDirectory, obj.metaFileName]=obj.splitPathFile(filePath);
            
        end
        %% Getters & Setters
        function val=get.baseDirectory(obj)
            if isrelpath(obj.metadata.baseDirectory)
                val=fullfile(obj.masivDirectory, obj.metadata.baseDirectory);
            else
                val=obj.metadata.baseDirectory;
            end
        end
        
        function val=get.experimentName(obj)
            return '' %TODO: Set this!
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

function a=isrelpath(p)
    if p(1) == '/' || ~isempty(regexp(p, '[A-Z]:', 'ONCE'))
        a=false;
    else
        a=true;
    end
end
