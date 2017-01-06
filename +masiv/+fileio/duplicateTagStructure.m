function tagStruct=duplicateTagStructure(filePath)
% Reads in and reproduces the Tiff tag structure of an image, for use in
% writing to a new image

if ~ischar(filePath) || ~exist(filePath, 'file')
    error('Not a valid path, or the filoe can not be opened')
end

info=imfinfo(filePath);
infoStructFieldNames=fieldnames(info);

validTiffTags=Tiff.getTagNames;

tagStruct=struct;

for ii=1:numel(infoStructFieldNames)
    if strcmp(infoStructFieldNames{ii}, 'PhotometricInterpretation')
        switch info.PhotometricInterpretation
            case 'BlackIsZero'
                tagStruct.Photometric=1;
            otherwise
                error('Unknown photometric. Could not convert.')
        end
    elseif strcmp(infoStructFieldNames{ii}, 'Compression')
        switch info.Compression
            case 'Uncompressed'
                tagStruct.Compression=1;
            otherwise
                error('Unknown compression. Could not convert.')
        end
    elseif strcmp(infoStructFieldNames{ii}, 'PlanarConfiguration')
        switch info.PlanarConfiguration
            case 'Chunky'
                tagStruct.PlanarConfiguration=1;
            case 'Separate'
                tagStruct.PlanarConfiguration=2;
            otherwise
                error('Unknown planar configuration. Could not convert.')
        end
    elseif strcmp(infoStructFieldNames{ii}, 'ResolutionUnit')
        switch info.ResolutionUnit
            case 'None'
                tagStruct.ResolutionUnit=1;
            case 'Inch'
                tagStruct.ResolutionUnit=2;
            case 'Centimeter'
                tagStruct.ResolutionUnit=3;
            otherwise
                error('Unknown resolution unit. Could not convert.')
        end
    elseif any(strcmp(infoStructFieldNames{ii}, {'StripOffsets', 'StripByteCounts'}))
        % Do nothing with these, they are read only
    elseif any(strcmp(infoStructFieldNames{ii}, validTiffTags))
        if ~isempty(info.(infoStructFieldNames{ii}))
            tagStruct.(infoStructFieldNames{ii})=info.(infoStructFieldNames{ii});
        end
    end
end
