function valOut=masivSetting(prefName, val)
% Get or set preferences in MaSIV YAML file 
%
% function valOut=masivSetting(prefName, val) %#ok<INUSD>
%
% Purpose
% Gets or sets settings (preferences) for MaSIV from a YAML prefs file.
% masivSetting also stores the default preferences and creates the YAML prefs 
% file if it's missing. 
%
% Inputs
% prefName - string of preference name to access 
% val - the value that this preference should be set to.
%       To reset to default value, pass an empty cell array {}
%
% Examples
% >> masivSetting('debug.logging')
% ans = 1
% >> masivSetting('debug.logging',0);
% >> masivSetting('debug.logging')
% ans = 0
%
%


persistent r fName fileInfo


if isempty(r)
    [r, fName, fileInfo]=doInitialReadOfSettingsFile;
end
    
    if nargin<2
        %% Read preference from file or from default list (missing preferences are added)
        [r, fileInfo]=checkFileTimestampAndReloadIfChanged(r, fileInfo, fName);

        if nargin<1||isempty(prefName) % return all
            valOut=r;
        else
            valOut = getThisSetting(r,prefName);
            %Check if requested preference is missing from the settings YML but present in the defaults
            if isempty(valOut) %setting not found in YML
                valOut=tryToSetToDefaultValue(prefName);
            end %if isinf(valOut)
        end %nargin<1||isempty(prefName) % return all

    else
        %% Check for reset
        if isempty(val) && iscell(val)
            fprintf('Attempting to reset value for %s to default.\n', prefName)
            val=tryToSetToDefaultValue(prefName);
            fprintf('Successful. Value set to:\n'), disp(val)
        else
            %% Write preference
            [r, fileInfo]=checkFileTimestampAndReloadIfChanged(r, fileInfo, fName);
            
            eval(sprintf('r.%s=val;', prefName));

            %% write first to a new (temporary) file, then rename. Should prevent corruption.
            tmpFname=[tempname,'.yml'];
            writeSimpleYAML(r, tmpFname);
            movefile(tmpFname, fName);
        end
    end
    
    
end %function valOut=masivSetting(prefName, val)


%----------------------------------------------------------
function [r, fName, fileInfo]=doInitialReadOfSettingsFile
    fName=getPrefsFilePath;
    r=readSimpleYAML(fName);
    fileInfo=dir(fName);
end


function fName=getPrefsFilePath
    fName=which('masivPrefs.yml');
    if isempty(fName)
        createDefaultPrefsFile
        fName=which('masivPrefs.yml');
    end
end

function thisSetting = getThisSetting(thisStruct,settingName)
    %Read setting defined by string settingName from from structure thisStruct
    %e.g. settingName has the form 'defaultDirectory' or 'font.size'
    %NOTE: If the setting is missing, getThisSetting returns empty

    for settingField=strsplit(settingName,'.')
        settingField = settingField{1};
        if isfield(thisStruct,settingField)
            thisStruct=thisStruct.(settingField); %descend down the tree
        else
            %bail out: we can't find the setting
            thisSetting=[];
            return
        end
    end

    thisSetting = thisStruct; %we have descended all the way to the variable

end


function s=returnDefaultSettings
    %% Returns a structure containing the default settings

    %% Global settings
    s.defaultDirectory='/';
    s.font.name='Helvetica';
    s.font.size=12;
    
    %% Default voxel sizes
    s.defaultVoxelSize=[1 1 5];

    %% Main Viewer colors
    s.viewer.panelBkgdColor=[0.1 0.1 0.1];
    s.viewer.mainBkgdColor=[0.2 0.2 0.2];
    s.viewer.textMainColor=[0.8 0.8 0.8];
    s.viewer.mainFigurePosition=[0 0 1600 900];
        
    %% Main viewer navigation settings
    s.navigation.panIncrement=[10 120]; % shift and non shift; fraction to move view by
    s.navigation.scrollIncrement=[10 1]; %shift and non shift; number of images to move view by
    s.navigation.zoomRate=1.5;
    s.navigation.panModeInvert=0;
    s.navigation.scrollZoomInvert=0;
    s.navigation.scrollLayerInvert=0;
    s.navigation.keyboardUpdatePeriod=0.005; %5ms keyboard polling

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
    
    %Contrast slider
    s.contrastSlider.highThresh=0.5; %should go between zero and 1
    s.contrastSlider.doAutoContrast=1;

    %% Debug output
    s.debug.logging=1;
    s.debug.outputSpacing=12;
    
    %% Cell counter
    s.cellCounter.figurePosition = [100 100 400 550];
    s.cellCounter.markerDiameter.xy = 20;
    s.cellCounter.markerDiameter.z = 30;
    s.cellCounter.minimumSize = 20;
    s.cellCounter.maximumDistanceVoxelsForDeletion = 500;
    s.cellCounter.importExportDefault = s.defaultDirectory;


    %% Plugins directory
    s.plugins.hideTutorialPlugins=0; %is 1 we hide tutorial plugins
    s.plugins.bundledPluginsDirPath=fullfile('code','plugins');

    %TODO: following line assumes that "external_plugins" is located in the 
    %      repository root. Likely this will change and so code using this 
    %      setting will also need to change the .masiv_plugins is currently
    %      just there for testing.
    s.plugins.externalPluginsDirs={'external_plugins'}; 
end

function createDefaultPrefsFile
    %% Load the default settings and write these to disk to the MaSIV path
    baseDir=fileparts(which('MaSIV'));
    writeSimpleYAML(returnDefaultSettings, fullfile(baseDir, 'masivPrefs.yml')); 
end

function valOut=tryToSetToDefaultValue(prefName)
    defaultSettings = returnDefaultSettings;
    thisDefaultSetting = getThisSetting(defaultSettings,prefName); %is this a missing setting?
    if isempty(thisDefaultSetting) %setting not found in default list
        error('Can not find setting %s',prefName) %TODO: do we want this to generate an error?
    else
        %add new default preference to file
        fprintf('Adding default value for %s to the settings YML file\n', prefName)
        masivSetting(prefName,thisDefaultSetting); %add the setting by writing to the preferences file
        valOut=masivSetting(prefName); %read the setting
    end %if isinf(thisDefaultSetting)
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