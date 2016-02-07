function masivDirPath=getMasivDirPath(obj)
    %% GETMASIVDIRPATH Returns the location of the directory MaSIV looks for data in
    %
    % If none is found, a new directory will be created, and the user will
    % be prompted for the metadata. 
    %
    % If an old GBStacks directory is found, this will be automatically
    % converted

    d=dir(fullfile(obj.baseDirectory, '*_MaSIV/'));
    if numel(d)>1
        error('More than one MaSIV data directory found.')
    elseif numel(d) ==1 % Found one, use it
        masivDirPath=fullfile(obj.baseDirectory, d.name);
    else % We haven't found any. Convert GBStacks, if found, or create.
        g=dir(fullfile(obj.baseDirectory,'*_GBStacks'));
        
        if isempty(g)
            % Get info and make directory
            warning('No MaSIV dir path found. Creating...')
            
            md=getUserInputMetadata();
            
            masivDirPath=fullfile(obj.baseDirectory, [md.sampleName, '_MaSIV']);
            mkdir(masivDirPath)
            
            writeSimpleYAML(yml, fullfile(masivDirPath, [md.sampleID '_Meta']));
        elseif numel(g)==1
            warning('No MaSIV dir path found, but an old GBStacks directory was detected. Updating...')
            % Move Directory
            gbDirPath=fullfile(obj.baseDirectory, g.name);
            masivDirPath=strrep(gbDirPath, 'GBStacks', 'MaSIV');
            movefile(gbDirPath, masivDirPath)
            % Move info file
            gbstackInfoFile=dir(fullfile(masivDirPath, '*GBStackInfo*'));
            if ~isempty(gbstackInfoFile)
                movefile(fullfile(masivDirPath, gbstackInfoFile.name), fullfile(masivDirPath, strrep(gbstackInfoFile.name, 'GBStackInfo', 'MaSIVInfo')))
            end
            % Move yml file
            % Get metadata
            oldMosaicFile=findOldMosaicFile(obj.baseDirectory);
            if ~isempty(oldMosaicFile)
                [~, outputFile]=convertTVtoMasivMetaData(oldMosaicFile);
            else
                md=getUserInputMetadata();
                writeSimpleYAML(yml, fullfile(masivDirPath, [md.sampleID '_Meta']));
            end
        else
            error('Multiple old GB directories found. Cannot automatically convert')
        end
    end
    
end

function fullPathToMosaicFile = findOldMosaicFile(baseDir)
    mFile=dir(fullfile(baseDir, '*Mosaic*.txt'));
    if isempty(mFile)
        fullPathToMosaicFile='';
    elseif numel(mFile)>1
        fullPathToMosaicFile='';
    else
        fullPathToMosaicFile=fullfile(baseDir, mFile.name);
    end
end

function md=getUserInputMetadata()
    response=inputdlg({'Sample name:', 'Voxel Size (x):', 'Voxel Size (y)', 'Voxel Size (z)'}, 'MaSIV Metadata', 1, {'', '1', '1', '1'});
    if isempty(response)
        error('Cancelled')
    end
    md.sampleName=response{1};
    md.voxelSize.x=str2double(response{2});
    md.voxelSize.y=str2double(response{3});
    md.voxelSize.z=str2double(response{4});
end