function repoName=getRepoName(url)
    % masiv.pluginManager.getRepoName
    %
    % Get repo name from the GitHub URL
    %
    % Private method
    tok=regexp(url,'.*/(.+?)(?:\.git)?$', 'tokens');
    if isempty(tok)
        error('Failed to get repository name from url: %s', url)
    end

    repoName = tok{1}{1};

end
