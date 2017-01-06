function [pluginDirs,installedFromGitHub]=getPluginDirs(pathToSearch)
    % Recursively search for all directories that contain at least one MaSIV plugin
    %
    % masiv.pluginManager.getPluginDirs
    %
    % function [pluginDirs,installedFromGitHub,dirsToAddToPath]=getPluginDirs(pathToSearch)
    %
    % Purpose
    % As a rule, each plugin (or tightly associated group of plugins) resides in its own directory. 
    % This function recursively searches sub-directories within "pathToSearch" for directories
    % containing MaSIV plugins. 
    %
    % 
    % Inputs
    % pathToSearch - [optional] An absolute or relative path specifying where the plugin
    %                to be updated is installed. If missing, we search from the current directory.
    %
    %
    % Outputs
    % pluginDirs          -  a cell array of paths to plugins
    % installedFromGitHub -  a vector defining whether each path contains plugins that were installed
    %                        from GitHub and so can be updated by masiv.pluginManager. 
    %
    %
    % Rob Campbell - Basel 2016   

    if nargin<1
        pathToSearch = pwd;
    end

    if ispc
        splitStr=';';
    else
        splitStr=':';
    end
    P=strsplit(genpath(pathToSearch),splitStr); 
 
    %Loop through P and search for files that are valid MaSIV plugins. Valid plugins are
    %subclasses of masivPlugin
    CWD=pwd; %Because we will have to change to each directory as we search

    pluginDirs={};
    for ii=1:length(P)
        if isempty(P{ii})
            continue
        end

        mFiles=dir(fullfile(P{ii},'*.m'));

        %fprintf('Looking for plugins in %s\n',P{ii})
        cd(P{ii})

        for m=1:length(mFiles) %Loop through all M files in this directory
            thisFile = fullfile(P{ii}, mFiles(m).name);
            if masiv.pluginManager.isPlugin(thisFile)
                pluginDirs{length(pluginDirs)+1}=P{ii};

                if exist(fullfile(P{ii},masiv.pluginManager.detailsFname),'file')
                    installedFromGitHub(length(pluginDirs))=1;
                else
                    installedFromGitHub(length(pluginDirs))=0;
                end

                break
            end
        end
     
    end
    cd(CWD)

end
