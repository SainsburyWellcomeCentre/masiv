function n=matlabMemUsageMiB

switch computer
    case 'MACI64'
        a=strtok(strsplit(evalc('system(''ps -ax | grep -i matlab'')'), '\n'), ' ');
        pids=cellfun(@str2num, a, 'UniformOutput', 0);
        pids=cell2mat(pids(~cellfun(@(x) isempty(x)||x==0, pids)));
        
        
        memString=['system(''ps -o rss -p ' sprintf('%u ', pids) ''');']; 
        s=strsplit(evalc(memString));
        isValidNum=~cellfun(@(x) isempty(x)||isempty(str2num(x)), s); %#ok<ST2NM>
        
        n=sum(cellfun(@str2double, s(isValidNum)))/1024;
    case 'GLNXA64'
        s=strsplit(evalc('system(''ps -o rss -p $(pidof MATLAB)'');'));
        
        isValidNum=~cellfun(@(x) isempty(x)||isempty(str2num(x)), s); %#ok<ST2NM>
        
        n=sum(cellfun(@str2double, s(isValidNum)))/1024;
    otherwise
        n=NaN;
        warning('Memory functions currently only supported for 64-bit Mac and Linux platforms')
end
end