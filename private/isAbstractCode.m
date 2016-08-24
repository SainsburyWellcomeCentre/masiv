function abstractPluginFlag=isAbstractCode(codeStr)
    abstractPluginFlag=strfind(lower(codeStr), 'abstract');
    if isempty(abstractPluginFlag)
        abstractPluginFlag=0;
    else
        abstractPluginFlag=1;
    end
end