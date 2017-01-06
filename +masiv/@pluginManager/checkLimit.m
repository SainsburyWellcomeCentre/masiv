function out=checkLimit
    % masiv.pluginManager.checkLimit
    %
    % Returns false and prints a message to the screen if you can't make any more API calls.
    % Returns true otherwise
    %
    % Private method
    limits = masiv.pluginManager.checkGitHubLimit;
    if limits.remaining==0
        fprintf('GitHub has temporarily blocked API requests from your IP address. Resting at UTC %s\n',limits.reset_str)
        out=false;
    else
        out=true;
    end
end
