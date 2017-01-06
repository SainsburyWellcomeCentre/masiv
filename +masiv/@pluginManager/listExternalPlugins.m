function varargout=listExternalPlugins(printToScreen)
    % Return a list of external plugins to screen or to an output variable
    %
    % masiv.pluginManager.listExternalPlugins
    %
    % varargout=listExternalPlugins(supressScreenPrint)
    %
    %
    % Purpose
    % Returns list of external plugins to screen (by default) or as an optional  
    % output variable. Print to screen can be supressed.
    %
    % 
    % Inputs
    % printToScreen - [optional] false by default
    %
    %
    %
    % Rob Campbell - Basel 2016   

    if nargin<1
        printToScreen = false;
    end

    masiv.utils.setupMaSIV_path
    mSettings=masivSetting;
    extPluginDir=mSettings.plugins.externalPluginsDirs;
    if ischar(extPluginDir)
        extPluginDir{1} = extPluginDir;
    end
    if ~iscell(extPluginDir)
        error('expluginDir should be a cell array of strings')
    end

    baseDir=fileparts(which('MaSIV'));

    pluginDirs={};
    for ii=1:length(extPluginDir)
        if exist(fullfile(baseDir,extPluginDir{ii}),'dir')
            thisExternalPluginDir=fullfile(baseDir,extPluginDir{ii});
        elseif exist(extPluginDir{ii},'dir')
            thisExternalPluginDir=extPluginDir{ii};
        else
            fprintf('Skipping directory %s -- can not find it!\n',extPluginDir{ii})
            continue
        end
        pluginDirs = [pluginDirs,masiv.pluginManager.getPluginDirs(thisExternalPluginDir)];
    end

    if nargout>0
        varargout{1}=pluginDirs';
    end

    if isempty(pluginDirs)
        fprintf('Found no external plugin directories\n')
        return
    end
    
    if printToScreen
        fprintf('\nExternal plugins:\n\n')

        for ii=1:length(pluginDirs)
            fprintf('(%d) %s\n', ii,pluginDirs{ii})

            if exist(fullfile(pluginDirs{ii},masiv.pluginManager.detailsFname))
                clear pluginDetails
                load(fullfile(pluginDirs{ii},masiv.pluginManager.detailsFname))
                fprintf('\tRepo name: %s\n',pluginDetails.repoName)
                fprintf('\tURL: %s\n',pluginDetails.repositoryURL)
                fprintf('\tAuthor: %s\n',pluginDetails.author.name)
            else
                fprintf('\t Not managed by masiv.pluginManager\n')
            end %if exist...

            fprintf('\n')
        end %for ii ...
    end %printToScreen
    
end
