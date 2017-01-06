function [pluginDisplayString, pluginStartCallback]=getPluginInfo(pluginFile)
    pluginDisplayString=eval(strrep(pluginFile.name, '.m', '.displayString;'));
    pluginStartCallback={eval(['@', strrep(pluginFile.name, '.m', '')])};
end
