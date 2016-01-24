function [freeMem, totalMem]=systemMemStats

switch computer
    case 'GLNXA64'
        s=strsplit(evalc('system(''free'');'), '\n');
        
        lineToScrape= find(~cellfun(@isempty, (strfind( s, 'Mem:'))));
        if isempty(lineToScrape)
            freeMem=0;
            totalMem=0;
        else
            secondLine=strsplit(s{lineToScrape});
            totalMem=str2double(secondLine{2});
            
            thirdLine=strsplit(s{lineToScrape+1});
            freeMem=str2double(thirdLine{4});
        end
    case 'MACI64'
        f=str2num(evalc('system(''vm_stat | grep free | awk ''''{ print $3 }'''' | sed ''''s/\.//'''''');')); %#ok<*ST2NM>
        spec=str2num(evalc('system(''vm_stat | grep speculative | awk ''''{ print $3 }'''' | sed ''''s/\.//'''''');'));

        freeMem=convertPagesToKiB(f+spec);
        totalMem=convertGBToKiB(str2num(evalc('system(''hostinfo | grep memory | awk '''' { print $4 } '''''');')));
    otherwise %It's windows
        [~,RAM]=memory;
        freeMem=RAM.PhysicalMemory.Available/1024;
        totalMem=RAM.PhysicalMemory.Total/1024;
end


end

function szMiB=convertPagesToKiB(nPages)
szMiB=nPages*4;
end

function KiB=convertGBToKiB(GB)
KiB=GB*1000^3/1024;
end