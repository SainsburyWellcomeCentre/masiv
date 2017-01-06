classdef (Abstract) pluginManager
    % masiv.pluginManager
    %
    % This abstract class handles the installation and updating of MaSIV plugins from GitHub. 
    %
    % Rob Campbell - Basel 2016


    properties (Constant)
       defaultBranchName='master' %default branch from which to download plugin
       detailsFname='last_updated_details.mat' %name of file that contains the commit details associated with the plugin
    end % properties



    methods (Static)
        % These are the public (user-facing) methods provided by this abstract class
        isplugin = isPlugin(fileName)
        changeBranch(pathToPluginDir,newBranchName)
        pluginDetails = info(pathToPluginDir)
        details = install(GitHubURL,branchName,targetDir)
        update(pathToPluginDir)  
        [pluginDirs,installedFromGitHub] = getPluginDirs(pathToSearch)
        removePlugin(pluginName,force)
        pluginDirs = listExternalPlugins(printToScreen)
    end % static methods




    methods (Access=protected, Static)
        % These are the private (invisible to the user) methods provided by this abstract class
        API = URL2API(url)                 % Convert the WWW URL or the Git URL to the base URL of an API call
        zipUrl = getZipURL(url,branchName) % Convert WWW URL or Git URL to the url of the zip file containing the archive of the latest master branch commit
        repoName = getRepoName(url)        % Get repo name from the GitHub URL
        unzippedDir = getZip(GitHubURL,branchName)      % Attempt to download the last commit as a ZIP file 
        detailsFname = getDetailsFname(pathToPluginDir)  % Get the path to a plugin's details file.
        exists = doesBranchExistOnGitHub(pluginURL,branchName) % As it says


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
        % API-related methods
        out = getLastCommitLocation(url,branchName) % Return the location details (url,sha,ref) of the last commit to the main branch 
        out = getLastCommitDetails(url,branchName)  % Return all the details on the last commit. e.g. who made the commit, when it was made, the commit sha, etc.
        limits = checkGitHubLimit % Query how many GitHub API requests remain from our IP address. 
        response = executeAPIcall(url) % Make an API call with simple error checking
        out = checkLimit % Returns false and prints a message to the screen if you can't make any more API calls.
        str = unixTime2str(unixTime) %C onverts a unix time to a human-readable string
        out = apiResponse2Struct(response,verbose) % converts a string containing an API response to a structure
        [subsectionName,data] = processResponseSubsection(response) % Extract data from an API response 
    end % protected static methods



end % classdef
