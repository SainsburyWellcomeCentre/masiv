function zipUrl=getZipURL(url,branchName)
    % masiv.pluginManager.getZipURL
    %
    % Convert the WWW URL or the Git URL to the url of the zip file containing the archive of the latest master branch commit
    %
    % Private method
    if nargin<2
        branchName = masiv.pluginManager.defaultBranchName;
    end
    zipUrl = regexprep(url,'\.git$', '');
    zipUrl = [zipUrl,'/archive/',branchName,'.zip'];
end
