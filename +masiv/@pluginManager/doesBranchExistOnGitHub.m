function exists=doesBranchExistOnGitHub(pluginURL,branchName)
    % masiv.pluginManager.doesBranchExistOnGitHub
    %
    % function exists=doesBranchExistOnGitHub(pluginURL,branchName)
    %
    % Purpose: return true if branch "branchName" exists at repository "pluginURL"
    %
    %
    % Private method
    url = regexprep(pluginURL,'\.git$','');
    url = [url,'/commits/',branchName];

    try
        reponse=urlread(url);
        exists=true;
    catch
        exists=false;
    end

end
