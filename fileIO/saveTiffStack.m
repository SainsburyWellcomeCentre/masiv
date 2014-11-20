function saveTiffStack(I, fileName)
    if ~strfind(fileName, '.tif')
        fileName=[fileName, '.tif'];
    end
    if needBigTiff(I)% small tiff, use imwrite
        fprintf('File size: %uMB. Using standard imWrite...\n ', tiffStackSizeMB(I))
        fprintf('Saving slice 1 of 1...\n')
        imwrite(I(:,:,1), fileName);
        for ii=2:size(I, 3)
            imwrite(I(:,:,ii), fileName, 'writemode', 'append');
            fprintf('Saving slice %u of %u...\n', ii, size(I,3))
        end
        fprintf('Done. %u pages save to %s\n', size(I, 3), fileName)
    else
        fprintf('File size: %uMB. Using Tiff class to create BigTiff file...\n ', tiffStackSizeMB(I))
        writeBigTiff(I, fileName)
    end
end


function writeBigTiff(I, filename)
   
    tags.ImageLength            = size(I,1);
    tags.ImageWidth             = size(I,2);
    tags.RowsPerStrip           = size(I, 1);
    tags.Photometric            = Tiff.Photometric.MinIsBlack;
    tags.PlanarConfiguration    = Tiff.PlanarConfiguration.Chunky;
    
    tags.BitsPerSample          = getBitDepth(I);
    tags.SamplesPerPixel        = 1;
    tags.Compression            = Tiff.Compression.None;
    tags.Software               =   'goggleBox';
    
    setTag(bt, tags);
    fprintf('Saving slice %u of %u...\n', 1, size(I,3))
    write(bt,  I(:,:,1));
    for ii=2:size(I, 3)
        bt.writeDirectory()
        bt.setTag(tags)
        bt.write(I(:,:,ii))
        fprintf('Saving slice %u of %u...\n', ii, size(I,3))
    end
    fprintf('Done. %u pages save to %s\n', size(I, 3), filename)
    close(bt);

end

function bitDepth=getBitDepth(I)
    pxStr=regexp(class(I), '[0-9]*', 'match');
    bitDepth=str2double(pxStr{:});
end

function n=needBigTiff(I)
sz=tiffStackSizeB(I);
n=sz>=1024^3;
end

function sz=tiffStackSizeB(I)
sz=numel(I)*getBitDepth(I)/8;
end

function sz=tiffStackSizeMB(I)
sz=ceil(tiffStackSizeB(I)/1024^2);
end