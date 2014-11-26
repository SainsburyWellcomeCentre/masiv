function n=matlabMemUsageMiB
    s=strsplit(evalc('system(''ps -o rss -p $(pidof MATLAB)'');'));

    isValidNum=~cellfun(@(x) isempty(x)||isempty(str2num(x)), s); %#ok<ST2NM>

    n=sum(cellfun(@str2double, s(isValidNum)))/1024;
end