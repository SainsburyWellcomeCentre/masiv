function saveTiffStack(I, fileName)
    if ~strfind(fileName, '.tif')
        fileName=[fileName, '.tif'];
    end
    if numel (I)*2<3.8e9 % small tiff, use imwrite
        fprintf('File size: %uMB. Using standard imWrite...\n ', round(numel(I)*2/1e6))
        imwrite(I(:,:,1), fileName);
        for ii=2:size(I, 3)
            imwrite(I(:,:,ii), fileName, 'writemode', 'append');
            fprintf('Saving slice %u of %u...\n', ii, size(I,3))
        end
        fprintf('Done. %u pages save to %s\n', size(I, 3), fileName)
    else
        fprintf('File size: %uMB. Using Tiff class to create BigTiff file...\n ', round(numel(I)*2/1e6))
        writeBigTiff(I, fileName)
    end
end


function writeBigTiff(I, filename)

bt=Tiff(filename, 'w8');

tags.ImageLength            = size(I,1);
tags.ImageWidth             = size(I,2);
tags.RowsPerStrip           = size(I, 1);
tags.Photometric            = Tiff.Photometric.MinIsBlack;
tags.PlanarConfiguration    = Tiff.PlanarConfiguration.Chunky;
tags.BitsPerSample          = 16;
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