function masivDirPath=getMasivDirPath(obj)
    %% GETMASIVDIRPATH Returns the location of the directory MaSIV looks for data in
    masivDirPath=fullfile(obj.baseDirectory, [obj.sampleName '_MaSIV']);
    if ~exist(masivDirPath, 'dir')
        % check if it's an old GB path; update if so
        gbDirPath=fullfile(obj.baseDirectory, [obj.sampleName '_GBStacks']);
        if exist(gbDirPath, 'dir')
            warning('No MaSIV dir path found, but an old GBStacks directory was detected. Updating...')
            movefile(gbDirPath, masivDirPath)
            gbstackInfoFile=dir(fullfile(masivDirPath, '*GBStackInfo*'));
            if ~isempty(gbstackInfoFile)
                movefile(fullfile(masivDirPath, gbstackInfoFile.name), fullfile(masivDirPath, strrep(gbstackInfoFile.name, 'GBStackInfo', 'MaSIVInfo')))
            end
        else
            mkdir(masivDirPath)
        end
        
    end
end