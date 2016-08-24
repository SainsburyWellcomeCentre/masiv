function isGBPlugin=isValidMasivPlugin(pluginsDir, pluginsFile)
    fName=fullfile(pluginsDir, pluginsFile);
    if isdir(fName)
        isGBPlugin=0;
    else
        f=fopen(fullfile(pluginsDir, pluginsFile));
        codeStr=fread(f, Inf, '*char')';
        hasGBPAsSuperClass=~isempty(strfind(codeStr, '<masivPlugin'));
        if hasGBPAsSuperClass
            isGBPlugin=~isAbstractCode(codeStr);
        else
            isGBPlugin=0;
        end
        fclose(f);
    end
end
