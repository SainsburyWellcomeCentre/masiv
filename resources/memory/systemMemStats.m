function [freeMem, totalMem]=systemMemStats

switch computer
    case 'GLNXA64'
        s=strsplit(evalc('system(''free'');'), '\n');
        
        secondLine=strsplit(s{2});
        totalMem=str2double(secondLine{2});
        
        thirdLine=strsplit(s{3});
        freeMem=str2double(thirdLine{4});
    case 'MACI64'
        f=str2num(evalc('system(''vm_stat | grep free | awk ''''{ print $3 }'''' | sed ''''s/\.//'''''');')); %#ok<*ST2NM>
        spec=str2num(evalc('system(''vm_stat | grep speculative | awk ''''{ print $3 }'''' | sed ''''s/\.//'''''');'));

        freeMem=convertPagesToKiB(f+spec);
        totalMem=convertGBToKiB(str2num(evalc('system(''hostinfo | grep memory | awk '''' { print $4 } '''''');')));
    otherwise
        freeMem=NaN;
        totalMem=NaN;
        warning('Memory functions currently only supported for 64-bit Mac and Linux platforms')
end


end

function szMiB=convertPagesToKiB(nPages)
szMiB=nPages*4;
end

function KiB=convertGBToKiB(GB)
KiB=GB*1000^3/1024;
end