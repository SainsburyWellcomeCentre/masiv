function API=URL2API(url)
    % masiv.pluginManager.URL2API
    %
    % Convert the WWW URL or the Git URL to the base URL of an API call
    %
    % Private method
    API = regexprep(url,'\.git$','');
    API = regexprep(API,'//github.com','//api.github.com/repos');
end
