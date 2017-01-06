function limits=checkGitHubLimit
    % masiv.pluginManager.checkGitHubLimit
    %
    % function limits=checkGitHubLimit
    % 
    % Purpose: Query how many GitHub API requests remain from our IP address. 
    %          Returns a structure containing the results
    %
    %  limits.limit - the maximum number of available requests
    %  limits.remaining - how many requests remain
    %  limits.reset_unixTime - the time at which the limit resets (unix time)
    %  limits.reset_str - the time at which the limit resets (human-readable string)
    %
    % For details see: https://developer.github.com/v3/#rate-limiting
    %
    % Private method
    U=urlread('https://api.github.com/rate_limit');
    tok=regexp(U,'"core".*?limit":(\d+).*?remaining":(\d+).*?reset":(\d+)','tokens'); 

    limits.limit=str2num(tok{1}{1});    
    limits.remaining=str2num(tok{1}{2});
    limits.reset_unixTime=str2num(tok{1}{3});   
    limits.reset_str = masiv.pluginManager.unixTime2str(limits.reset_unixTime);
end 
