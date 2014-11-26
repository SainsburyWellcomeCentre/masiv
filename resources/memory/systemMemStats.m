function [freeMem, totalMem]=systemMemStats
s=strsplit(evalc('system(''free'');'), '\n');

secondLine=strsplit(s{2});
totalMem=str2double(secondLine{2});

thirdLine=strsplit(s{3});
freeMem=str2double(thirdLine{4});


end