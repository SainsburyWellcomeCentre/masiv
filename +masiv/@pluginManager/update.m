function update(pathToPluginDir)  
    % Check whether MaSIV plugin is up to date and update if not
    %
    % masiv.pluginManager.update
    %
    % function update(pathToPluginDir)
    %
    %
    % Purpose: 
    % Update an existing plugin located at pathToPluginDir.
    % 
    %
    % Inputs
    % pathToPluginDir - An absolute or relative path specifying where the plugin
    %                   to be updated is installed.
    % 
    %
    % Examples
    % % List external plugins to screen:
    % >> masiv.pluginManager.listExternalPlugins(1)
    %
    % External plugins:
    %
    % (1) ~/work/Anatomy/MaSIV_plugins_dev/neuriteTracer
    %        Not managed by masiv.pluginManager
    %
    % (2) ~/.masiv_plugins/masiv-cell-counter
    %       Repo name: masiv-cell-counter
    %       URL: https://github.com/alexanderbrown/masiv-cell-counter
    %       Author: Alex Brown
    %
    %
    % >> masiv.pluginManager.update('~/.masiv_plugins/masiv-cell-counter')
    %  Checking if plugin masiv-cell-counter is up to date on branch master
    %  Plugin "masiv-cell-counter" is up to date on branch "master".
    %          
    %
    % Rob Campbell - Basel 2016

    if nargin==0
        fprintf(['\n\n  ',repmat('*',1,70)])
        fprintf(['\n  ** You must supply the path to the plugin you wish to update. See:  **\n',...
            '  ** help masiv.pluginManager.update                                  **\n'])
        fprintf(['  ',repmat('*',1,70), '\n\n\n'])
        help masiv.pluginManager.update
        return
    end

    detailsFname = masiv.pluginManager.getDetailsFname(pathToPluginDir);
    if isempty(detailsFname)
        return
    else
        load(detailsFname)
    end

    %Read the Web page and find the sha of the last commit 
    response=urlread(pluginDetails.repositoryURL);
    tok=regexp(response,'<.*class="commit-tease.*src="(.+?)">','tokens');
    if isempty(tok)
        error('Failed to get commit SHA string from %s\n',pluginDetails.repositoryURL);
    end
    lastSHA = regexprep(tok{1}{1},'/.*/','');
    if strcmp(pluginDetails.sha,lastSHA)
        fprintf('Plugin "%s" is up to date.\n',pluginDetails.repoName)
        return
    end

    %If the commit does not match, then it's possible the repository was indeed updated, but
    %the last commit was to a different branch and is masking the update. We therefore need
    %to generate an API query to get the details of the last commit on the current branch.
    fprintf('Checking if plugin %s is up to date on branch %s\n', pluginDetails.repoName, pluginDetails.branchName)
    lastCommit = masiv.pluginManager.getLastCommitDetails(pluginDetails.repositoryURL,pluginDetails.branchName);
    if strcmp(lastCommit.sha,pluginDetails.sha)
        fprintf('Plugin "%s" is up to date on branch "%s".\n',pluginDetails.repoName,pluginDetails.branchName)
        return
    end

    %If we're here, the plugin is not up to date
    fprintf('Found an update for plugin "%s". New update is from %s at %s\n', ...
        pluginDetails.repoName,pluginDetails.lastCommit.date,pluginDetails.lastCommit.time)

    %get the zip file for this plugin and this branch using values previously stored in the plugin folder
    unzippedDir = masiv.pluginManager.getZip(pluginDetails.repositoryURL,pluginDetails.branchName);
    if isempty(unzippedDir)
        return
    end

    %Save the new commit details to this folder
    pluginDetails=lastCommit;
    save(fullfile(unzippedDir,masiv.pluginManager.detailsFname),'pluginDetails')

    %it should now be safe to replace the existing plugin directory
    warning('off','MATLAB:RMDIR:RemovedFromPath')
    rmdir(pathToPluginDir,'s')
    movefile(unzippedDir,pathToPluginDir)
    warning('off','MATLAB:RMDIR:RemovedFromPath')

    fprintf('Plugin "%s" updated\n', pluginDetails.repoName)

end
