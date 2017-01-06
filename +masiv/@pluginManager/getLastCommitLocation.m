function out=getLastCommitLocation(url,branchName)
    % masiv.pluginManager.getLastCommitLocation
    % out=getLastCommitLocation(url,branchName)
    %
    % Purpose: Return the location details (url,sha,ref) of the last commit to the main branch ('master' by default)
    %          of most interest is out.object.url, which is the API call that returns all the details of the
    %          last commit.
    %
    % Private method
    if nargin<2
        branchName = masiv.pluginManager.defaultBranchName;
    end

    api_call = [masiv.pluginManager.URL2API(url),'/git/refs/heads/',branchName];
    response = masiv.pluginManager.executeAPIcall(api_call);
    out = masiv.pluginManager.apiResponse2Struct(response);
end
