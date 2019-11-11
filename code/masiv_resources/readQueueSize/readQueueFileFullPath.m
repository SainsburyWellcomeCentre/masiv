function fName = readQueueFileFullPath
% function fName = readQueueFileFullPath
%
% The name of the read queue file. On a multi-user system
% we run into problems if two people are using MaSIV
% at the same time. Thus we append the date and time to the
% file name to create a unique file each time. 

% TODO % Test on Windows and if it fails, put in a conditional for a Windows alternative to getenv

  fName=fullfile(tempdir,...
                 sprintf('MaSIV_readqueue_%s.txt',...
                         getenv('USER')) );


end

