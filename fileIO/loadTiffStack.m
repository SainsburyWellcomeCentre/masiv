function I=loadTiffStack(fileName, idx, outputMode)
% Loads a multipage tiff stack. Can load stacks with IFDs preceeding each
% page, or one IFD at the start (imageJ convention for large files);
% mode selection is automatic

if nargin<3||isempty(outputMode)
    outputMode='n';
end
if ~ischar(outputMode)||~any(strcmp(outputMode, {'n', 'c', 'g'}))
    error('Invalid output mode. Choose ''c'' for command-line output; ''g'' for graphical output or ''n'' for none')
else
    outputMode=lower(outputMode);
end

info=imfinfo(fileName);

if numel(info)>1 %IFD before each page
    if nargin<2||isempty(idx)
        idx=1:numel(info);
    else
        if any(idx)>numel(info)
            error('Index specified out of range in the file')
        end
        d=unique(diff(idx));
        if numel(d)>1||any(d)<0
            error('Index specification must be monotonically increasing and evenly spaced')
        end
    end
    
    I=zeros(info(1).Height, info(1).Width, numel(idx), selectMATLABDataType(info(1)));
   
    switch outputMode
        case 'n'
            parfor ii=1:numel(idx)
                I(:,:,ii)=imread(fileName, 'Index', idx(ii));%, 'Info', info);
            end
        case 'c'
            parfor ii=1:numel(idx)
                I(:,:,ii)=imread(fileName, 'Index', idx(ii));%, 'Info', info);
                fprintf('Loading slice %u of %u...\n', ii, numel(idx)) %#ok<PFBNS>
            end
        case 'g'
            swb=SuperWaitBar(numel(idx), strrep(sprintf('Loading from %s ', fileName), '_', '\_'));
            parfor ii=1:numel(idx)
                I(:,:,ii)=imread(fileName, 'Index', idx(ii));%, 'Info', info);
                swb.progress; %#ok<PFBNS>
            end
            delete(swb)
            clear swb
    end
else %1 IFD at start
    numFramesStr = regexp(info.ImageDescription, 'images=(\d*)', 'tokens');
    if ~isempty(numFramesStr) %It's in imageJ large stack
        numFrames = str2double(numFramesStr{1}{1});
        
        %% Check idx
        if nargin<2||isempty(idx)
            idx=1:numFrames;
            d=1;
        else
            if any(idx)>numel(info)
                error('Index specified out of range in the file')
            end
            d=unique(diff(idx));
            if numel(d)>1||any(d)<0
                error('Index specification must be monotonically increasing and evenly spaced')
            end
        end
        %% Open and seek to start
        fp = fopen(fileName , 'rb');
        fseek(fp, info.StripOffsets, 'bof');
        if idx(1)>1
            fseek(fp, info.Width*info.Height*info.BitDepth/8*(idx(1)-1), 'cof');
        end
        %%
        I=zeros(info.Height, info.Width, numel(idx), selectMATLABDataType(info(1)));
        switch outputMode
            case 'n'
                for ii = 1:numel(idx)
                    I(:,:,ii)=getSliceUsingFread(fp, info);
                    seekIfNeeded(fp, d, info);
                end
            case 'c'
                for ii = 1:numel(idx)
                    I(:,:,ii)=getSliceUsingFread(fp, info);
                    seekIfNeeded(fp, d, info);
                    fprintf('Loading slice %u of %u...\n', ii,numel(idx))
                end
            case 'g'
                swb=SuperWaitBar(numel(idx), strrep(sprintf('Loading from %s ', fileName), '_', '\_'));
                for ii = 1:numel(idx)
                    I(:,:,ii)=getSliceUsingFread(fp, info);
                    seekIfNeeded(fp, d, info);
                    swb.progress;
                end
                delete(swb)
                clear swb
        end
        [~,differentlyEndian]=getEndianness(info(1));
        if differentlyEndian
            if strcmp(outputMode, 'c');fprintf('Swapping endiannes...'),end
            I=swapbytes(I);
        end
        fclose(fp);

    else %assume single slice image
        if strcmp(outputMode, 'c')
            fprintf('Image seems to only have one slice. Loading...')
        end
        I=imread(fileName);
    end
    if strcmp(outputMode, 'c');fprintf('Done.\n'),end
end

end


function dt=selectMATLABDataType(info)
switch info.BitDepth
    case(16)
        dt='uint16';
    case(8)
        dt='uint8';
    otherwise
        error('Unknown Data Type')
end
end

function [e, differentFlag]= getEndianness(info)
[~,~,systemEndianness]=computer;
differentFlag=0;
switch info.ByteOrder
    case 'little-endian'
        e='ieee-le';
        if strcmp(systemEndianness, 'B')
            differentFlag=1;
        end
    case 'big-endian'
        e='ieee-be';
        if strcmp(systemEndianness, 'L')
            differentFlag=1;
        end
    otherwise
        error('Unknown endianness')
end
end

function I=getSliceUsingFread(fp, info)
I=fread(fp, [info.Width info.Height], ['* ' selectMATLABDataType(info(1))])';
end

function seekIfNeeded(fp, d, info)
if d>1
    fseek(fp,info.Width*info.Height*info.BitDepth/8*d-1, 'cof');
end
end