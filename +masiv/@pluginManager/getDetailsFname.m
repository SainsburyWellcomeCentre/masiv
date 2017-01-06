function detailsFname = getDetailsFname(pathToPluginDir)
    % masiv.pluginManager.detailsFname
    % 
    % Get the path to a plugin's details file. This file
    % contains information such as the name of the branch,
    % the commit sha, the last update time, etc
    %
    % Private method
    if ~exist(pathToPluginDir,'dir')
        fprintf('No directory found at %s\n',pathToPluginDir)
        detailsFname=[];
        return
    end

    detailsFname = fullfile(pathToPluginDir,masiv.pluginManager.detailsFname);

    if ~exist(detailsFname,'file')
        fprintf('\n Could not find a "%s" file in directory "%s".\n Please install plugin with "pluginManager.install"\n\n',...
            masiv.pluginManager.detailsFname,pathToPluginDir)
        detailsFname=[];
        return
    end

end
