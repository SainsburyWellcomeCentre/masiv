function str = unixTime2str(unixTime)
    % masiv.pluginManager.unixTime2str
    % Converts a unix time to a human-readable string
    %
    % Private method
    str=datestr(unixTime/86400 + datenum(1970,1,1));
end
