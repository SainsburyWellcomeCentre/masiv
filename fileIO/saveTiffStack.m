function saveTiffStack(I, fileName, outputMode)
    %% Check filename
    pth=fileparts(fileName);
    if ~isempty(pth)&&~exist(pth, 'dir')
        error('Specified path does not exist')
    end
        
    %% Output Mode
    if nargin<3||isempty(outputMode)
        outputMode='c';
    end
    if ~ischar(outputMode)||~any(strcmp(outputMode, {'n', 'c', 'g'}))
        error('Invalid output mode. Choose ''c'' for command-line output; ''g'' for graphical output or ''n'' for none')
    else
        outputMode=lower(outputMode);
    end
    if strcmp(outputMode, 'g')&&usejava('jvm')&&~feature('ShowFigureWindows') %Switch to console display if no graphics available
        outputMode='c';
    end
    %% Check .tif extension
    if ~strfind(fileName, '.tif')
        fileName=[fileName, '.tif'];
    end
    %% do the write
    if ~needBigTiff(I)% small tiff, use imwrite
        switch outputMode
            case 'c'
                fprintf('File size: %uMB. Using standard imWrite...\n ', tiffStackSizeMB(I))
                fprintf('Saving slice 1 of 1...\n')
            case 'g'
                swb=SuperWaitBar(size(I, 3), sprintf('File size:%uMB. Saving file to: %s with standard imwrite', tiffStackSizeMB(I),strrep(fileName, '_', '\_')));
        end
        imwrite(I(:,:,1), fileName);
        if strcmp(outputMode, 'g');swb.progress();end
        for ii=2:size(I, 3)
            imwrite(I(:,:,ii), fileName, 'writemode', 'append');
            switch outputMode
                case 'c'
                    fprintf('Saving slice %u of %u...\n', ii, size(I,3))
                case 'g'
                    swb.progress()
            end
            
        end
        switch outputMode
            case 'c'
                fprintf('Done. %u pages save to %s\n', size(I, 3), fileName)
            case 'g'
                delete(swb)
                clear swb
        end
    else
        writeBigTiff(I, fileName, outputMode)
    end
end


function writeBigTiff(I, filename, outputMode)
    bt=Tiff(filename, 'w8');
    %% Set tags
    tags.ImageLength            = size(I,1);
    tags.ImageWidth             = size(I,2);
    tags.RowsPerStrip           = size(I, 1);
    tags.Photometric            = Tiff.Photometric.MinIsBlack;
    tags.PlanarConfiguration    = Tiff.PlanarConfiguration.Chunky;
    
    tags.BitsPerSample          = getBitDepth(I);
    tags.SamplesPerPixel        = 1;
    tags.Compression            = Tiff.Compression.None;
    tags.Software               =   'goggleBox';
    
    switch class(I)
        
        case {'logical', 'uint8', 'uint16', 'uint32'}
            tags.SampleFormat            = 1; %UInt
        case {'int8', 'int16', 'int32'}
            tags.SampleFormat            = 2; %Int
        case {'single' 'double'}
            tags.SampleFormat            = 3; %IEEEFP
        otherwise
            error('Unknown Image class type')
    end
    setTag(bt, tags);
    %% Prepare output
    switch outputMode
        case 'c'
            fprintf('File size: %uMB. Using Tiff class to create BigTIFF file...\n ', tiffStackSizeMB(I))
        case 'g'
            swb=SuperWaitBar(size(I, 3), sprintf('File size:%uMB. Saving file to: %s using Tiff class to create BigTIFF file', tiffStackSizeMB(I),strrep(filename, '_', '\_')));
    end
    %% Write the first slice
    write(bt,  I(:,:,1));
    %% Output first slice done
    switch outputMode
        case 'c'
            fprintf('Saving slice %u of %u...\n', 1, size(I,3))
        case 'g'
            swb.progress();
    end
    %% Write the rest
    for ii=2:size(I, 3)
        bt.writeDirectory()
        bt.setTag(tags)
        bt.write(I(:,:,ii))
        %% Output
        switch outputMode
            case 'c'
                fprintf('Saving slice %u of %u...\n', ii, size(I,3))
            case 'g'
                swb.progress();
        end
    end
    %% Finish up
    switch outputMode
        case 'c'
            fprintf('Done. %u pages save to %s\n', size(I, 3), filename)
        case 'g'
            delete(swb)
            clear swb
    end
    close(bt);

end

function bitDepth=getBitDepth(I)
    pxStr=regexp(class(I), '[0-9]*', 'match');
    if ~isempty(pxStr)
    bitDepth=str2double(pxStr{:});
    else
        switch class(I)
            case 'double'
                bitDepth=64;
            case 'single'
                bitDepth=32;
            otherwise
                error('unknown format')
        end
    end
               
end

function n=needBigTiff(I)
sz=tiffStackSizeB(I);
n=sz>=(4*1024^3);
end

function sz=tiffStackSizeB(I)
sz=numel(I)*getBitDepth(I)/8;
end

function sz=tiffStackSizeMB(I)
sz=ceil(tiffStackSizeB(I)/1024^2);
end