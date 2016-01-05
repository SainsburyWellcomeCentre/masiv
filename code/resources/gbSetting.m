function valOut=gbSetting(nm, val) %#ok<INUSD>
%GBSETTING Gets or sets settings from a YAML prefs file
persistent r fName fileInfo

if isempty(r)
    [r, fName, fileInfo]=doInitialReadOfSettingsFile();
end
    
    if nargin<2
        %% Read mode
       
        [r, fileInfo]=checkFileTimestampAndReloadIfChanged(r, fileInfo, fName);

        if nargin<1||isempty(nm) % return all
            valOut=r;
        else
            valOut=eval(sprintf('r.%s', nm));
        end
    else
        %% Write mode
        
        [r, fileInfo]=checkFileTimestampAndReloadIfChanged(r, fileInfo, fName);
        
        eval(sprintf('r.%s=val;', nm));
        %% write first to a new file, then rename. Should prevent corruption. 
        tmpFname=strrep(fName, '.yml', 'tmp.yml');
        writeSimpleYAML(r, tmpFname);
        movefile(tmpFname, fName);
       
    end
    
    
end

function [r, fName, fileInfo]=doInitialReadOfSettingsFile()
    fName=getPrefsFilePath();
    r=readSimpleYAML(fName);
    fileInfo=dir(fName);
end

function fName=getPrefsFilePath()
    fName=which('gogglePrefs.yml');
    if isempty(fName)
        createDefaultPrefsFile()
        fName=which('gogglePrefs.yml');
    end
end

function createDefaultPrefsFile()
    %% Global settings
    s.defaultDirectory='/';
    
    s.font.name='Helvetica';
    s.font.size=12;
    
    %% Default voxel sizes
    s.defaultVoxelSize=[1 1 5];
    %% Main Viewer
    s.viewer.panelBkgdColor=[0.1 0.1 0.1];
    s.viewer.mainBkgdColor=[0.2 0.2 0.2];
    s.viewer.textMainColor=[0.8 0.8 0.8];
    s.viewer.mainFigurePosition=[0 0 1600 900];
        
    s.navigation.panIncrement=[10 120]; % shift and non shift; fraction to move view by
    s.navigation.scrollIncrement=[10 1]; %shift and non shift; number of images to move view by
    s.navigation.zoomRate=1.5;
    s.navigation.panModeInvert=0;
    s.navigation.keyboardUpdatePeriod=0.02; %20ms keyboard polling
    %% GVD Settings
    s.viewerDisplay.nPixelsWidthForZoomedView=2000;
    s.viewerDisplay.minZoomLevelForDetailedLoad=1.5;

    %% Cache Settings
    s.cache.sizeLimitMiB=1024; %1GiB by default
    
    %% ViewInfoPanel Settings
    s.viewInfoPanel.fileNotOnDiskTextColor=[0.8 0.24 0];
    s.viewInfoPanel.fileOnDiskTextColor=[0 0.8 0.32];
    
    %% ReadQueueInfoPanel Settings
    s.readQueueInfoPanel.max=50;
    
    %% Debug output
    s.debug.logging=1;
    s.debug.outputSpacing=12;
%%
    baseDir=fileparts(which('goggleViewer'));
    
    writeSimpleYAML(s, fullfile(baseDir, 'gogglePrefs.yml'));
    
end

function [r, fileInfo]=checkFileTimestampAndReloadIfChanged(r, fileInfo, fName)
 %% Check the file hasn't been modified
        newFileInfo=dir(fName);
        if (numel(newFileInfo.date)~=numel(fileInfo.date)) || any(newFileInfo.date~=fileInfo.date)
            %% And reload it if it has
            r=readSimpleYAML(fName);
            fileInfo=dir(fName);
        end
end