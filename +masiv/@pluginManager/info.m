function varargout=info(pathToPluginDir)
    % Display info about plugin in a given directory
    %
    % masiv.pluginManager.info
    %
    % function info=info(pathToPluginDir)
    %
    % Purpose: 
    % Display information about a plugin to screen and optionally return as a structure.
    % 
    %
    % Inputs
    % pathToPluginDir - An absolute or relative path specifying where the plugin
    %                   to be updated is installed.
    %
    % Outputs
    % info - optional structure containing information about the plugin.
    %
    %
    % Examples
    %   masiv.pluginManager.info('/path/to/plugin/')
    %            
    %
    % Rob Campbell - Basel 2016

    if nargin==0
        help('masiv.pluginManager.info')
        return
    end

    detailsFname = masiv.pluginManager.getDetailsFname(pathToPluginDir);
    if isempty(detailsFname)
        return
    else
        load(detailsFname)
    end

    fprintf(['\nRepo name:\t%s\n',...
        'Branch name:\t%s\n',...
        'Repo URL:\t%s\n',...
        'Last commiter:\t%s\n',...
        'Last updated:\t%s at %s\n\n'],...
        pluginDetails.repoName,...
        pluginDetails.branchName,...
        pluginDetails.repositoryURL,...
        pluginDetails.committer.name,...
        pluginDetails.lastCommit.date,pluginDetails.lastCommit.time)

    if nargout>0
        varargout{1}=pluginDetails;
    end

end
