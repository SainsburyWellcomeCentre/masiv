function isplugin=isPlugin(fileName)
    % Does a class inherit masivPlugin?
    %
    % masiv.pluginManager.isPlugin
    %
    % function isplugin=isPlugin(fileName)
    %
    % Purpose: Return true if an m file is a valid MaSIV plugin.
    %          Valid plugins are subclasses of masivPlugin.
    %          fileName must be in your path or in the current directory.
    %
    % Example:
    % masiv.pluginManager.isPlugin('myPluginFile.m')
    %
    % 
    % Alex Brown - 2016

    if nargin==0
        help('masiv.pluginManager.isPlugin')
        return
    end

    [~,className]=fileparts(fileName);
    m=meta.class.fromName(className);
    if length(m)==0
        isplugin=false;
        return
    end

    if ismember('masivPlugin', {m.SuperclassList.Name})
        isplugin=true;
    else
        isplugin=false;
    end

end
