function changeBranch(pathToPluginDir,newBranchName)
    % Replace an existing plugin with a version from a different Git branch
    %
    % masiv.pluginManager.changeBranch
    %
    % function changeBranch(pathToPluginDir,newBranchName)
    %
    % Purpose: 
    % Replace an existing plugin with a version from a different Git branch.
    %
    % 
    % Inputs
    % pathToPluginDir - An absolute or relative path specifying where the plugin
    %                   to be updated is installed.
    % newBranchName   - A string defining the name of the branch to which we will switch.
    %
    % Examples
    %   masiv.pluginManager.changeBranch('/path/to/plugin/','devel')
    %            
    %
    % Rob Campbell - Basel 2016

    if nargin==0
        help('masiv.pluginManager.changeBranch')
        return
    end

    detailsFname = masiv.pluginManager.getDetailsFname(pathToPluginDir);
    if isempty(detailsFname)
        return
    else
        load(detailsFname)
    end

    %Bail out if this branch does not exist on the server            
    if ~masiv.pluginManager.doesBranchExistOnGitHub(pluginDetails.repositoryURL,newBranchName)
        fprintf('There is no branch named "%s" at %s\n', newBranchName, pluginDetails.repositoryURL)
        return
    end

    %Bail out if the plugin is already using this branch
    if strcmp(pluginDetails.branchName,newBranchName)
        fprintf('Plugin "%s" is already from branch "%s"\n',....
            pluginDetails.repoName, pluginDetails.branchName)
        return
    end

    %get the zip file for this plugin and this branch using values previously stored in the plugin folder
    unzippedDir = masiv.pluginManager.getZip(pluginDetails.repositoryURL,newBranchName);
    if isempty(unzippedDir)
        return
    end            

    %Get the details for this commit from the desired branch
    pluginDetails = masiv.pluginManager.getLastCommitDetails(pluginDetails.repositoryURL,newBranchName);


    %Save the new commit details to the unzipped folder
    save(fullfile(unzippedDir,masiv.pluginManager.detailsFname),'pluginDetails')

    %it should now be safe to replace the existing plugin directory
    rmdir(pathToPluginDir,'s')
    movefile(unzippedDir,pathToPluginDir)

    fprintf('Plugin "%s" is switched to branch "%s"\n', pluginDetails.repoName,newBranchName)

end
 