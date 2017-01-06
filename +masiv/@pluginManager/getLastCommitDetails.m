function out=getLastCommitDetails(url,branchName)
    % masiv.pluginManager.getLastCommitDetails
    % out=getLastCommitDetails(url,branchName)
    %
    % Purpose: Return all the details on the last commit. e.g. who made the commit, when it was made, the commit sha, etc.
    %
    % Private method
    if nargin<1
        fprintf('Please supply a GitHub URL\n')
        return
    end
    if nargin<2
        branchName = masiv.pluginManager.defaultBranchName;
    end

    lastCommit = masiv.pluginManager.getLastCommitLocation(url,branchName);
    response = masiv.pluginManager.executeAPIcall(lastCommit.object.url);
    out = masiv.pluginManager.apiResponse2Struct(response);

    %Process the data to make it easier to handle
    %Extract the date and time
    tok=regexp(out.committer.date,'(.*?)T(.*?)Z','tokens');
    if isempty(tok)
        error('Unable to get last date and time from commiter.date')
    end
    out.lastCommit.date = tok{1}{1};
    out.lastCommit.time = tok{1}{2};
    out.lastCommit.dateNum = datenum([tok{1}{1},' ',tok{1}{2}]); %The last commit in MATLAB serial date format

    %Store the URL of the repository (not the git URL)
    url = regexprep(url,'\.git$',''); 
    out.repositoryURL = url;

    out.branchName = branchName; %Store the branch we asked for
    out.repoName = masiv.pluginManager.getRepoName(url);

end
