function response = executeAPIcall(url)
    % masiv.pluginManager.executeAPIcall
    % Make an API call with simple error checking
    %
    % Private method
    if ~masiv.pluginManager.checkLimit
        return
    end
    %Query to get the URL of the last commit
    try
        response=urlread(url);
    catch
        fprintf(' pluginManager FAILED to read data from API call: %s\n', url)
        rethrow(lasterror)
    end
end
