function varargout=install(GitHubURL,branchName,targetDir)
    % Install MaSIV plugin from GitHub to a given target directory
    %
    % masiv.pluginManager.install 
    %
    % function install(GitHubURL,branch,targetDir)
    %
    % Purpose: 
    % Install the plugin located at a given GitHub URL to either a user-defined directory
    % or, more usefully, the MaSIV external plugins directory. Since more than one of these
    % may be defined, the user is given a choice of which one to install into, should this
    % be necessary. 
    %
    %
    % Inputs
    % GitHubURL - The URL of a MaSIV plugin Git repository hosted on GitHub.
    %             This may be either the URL in the browser location bar or 
    %             the Git respository HTTPS URL on the reposotory's web page.
    % branchName - [optional] By default the function pulls in the plugin 
    %              from the branch named "master". Supply this input argument 
    %              to specify a different branch.
    % targetDir - [optional] An absolute or relative path specifying where the plugin is 
    %             to be installed. If empty or missing, the plugin is installed 
    %             in the MaSIV external plugins directory. An on-screen choice is 
    %             provided if there are multiple external plugin directories. This option
    %             is likely never needed in practice.
    %              
    % 
    %
    % Examples
    %   masiv.pluginManager.install('https://github.com/userName/repoName')
    %   masiv.pluginManager.install('https://github.com/userName/repoName.git')
    %   masiv.pluginManager.install('https://github.com/userName/repoName',devel',[])
    %   masiv.pluginManager.install('https://github.com/userName/repoName',[],'/path/to/stuff/')
    %            
    %
    % Rob Campbell - Basel 2016

    if nargin==0
        help('masiv.pluginManager.install')
        return
    end

    if nargin<2 | isempty(branchName)
        branchName=masiv.pluginManager.defaultBranchName;
    end

    %Extract the directory names to which we will install
    if nargin<3 | isempty(targetDir)
        masiv.utils.setupMaSIV_path
        mSettings=masivSetting;
        extPluginDir=mSettings.plugins.externalPluginsDirs;
        if ischar(extPluginDir)
            targetDir=extPluginDir;
        elseif iscell(extPluginDir)
            fprintf('\nWhere do you want to install the plugin?\n\n')
            for ii=1:length(extPluginDir)
                fprintf('(%d) %s\n',ii,extPluginDir{ii})
            end

            %do not proceed until user enters a valid answer
            while 1
                result = str2num(input('? ','s'));
                if ~isempty(result)
                    if result>0 && result<=length(extPluginDir)
                        break
                    end
                end
                fprintf('Please enter one of the above numbers and press return\n')
            end
        else
            error('external plugin directory is neither a string or a cell array')
        end

        targetDir = extPluginDir{result};
        if ~exist(targetDir,'dir')
            fprintf('Making directory %s\n',targetDir)
            mkdir(targetDir)
        end
    end

    %This is where we will attempt to the install the plugin. Do not proceed if the directory already exists
    repoName = masiv.pluginManager.getRepoName(GitHubURL);
    targetLocation = fullfile(targetDir,repoName);
    if exist(targetLocation,'dir')
        fprintf(['\n A plugin directory already exists at %s\n',...
            ' You should either:\n    a) Delete this and try again.\n  or\n    b) Use masiv.pluginManager.update to update it.\n\n'],targetLocation)
        return
    end

    unzippedDir = masiv.pluginManager.getZip(GitHubURL,branchName);
    if isempty(unzippedDir)
        return
    end

    %Now we query GitHub using the GitHub API in order to log the time this commit was made and the commit's SHA hash
    pluginDetails = masiv.pluginManager.getLastCommitDetails(GitHubURL,branchName);

    fprintf('Plugin last updated by %s at %s on %s\n', ...
        pluginDetails.author.name, pluginDetails.lastCommit.time, pluginDetails.lastCommit.date) 

    %Save this structure in the unpacked zip directory
    save(fullfile(unzippedDir,masiv.pluginManager.detailsFname),'pluginDetails')


    %Now we move the directory to the target directory and rename it to the repository name
    fprintf('Installing "%s" in directory "%s"\n', repoName, targetLocation)
    movefile(unzippedDir,targetLocation)

    if nargout>0
        varargout{1}=details;
    end

end
