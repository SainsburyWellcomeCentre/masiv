function I=loadTiffStack(fileName, idx)
% Loads a multipage tiff stack. Can load stacks with IFDs preceeding each
% page, or one IFD at the start (imageJ convention for large files);
% mode selection is automatic
info=imfinfo(fileName);

if numel(info)>1 %IFD before each page
    if nargin<2||isempty(idx)
        idx=1:numel(info);
    else
        if any(idx)>numel(info)
            error('Index specified out of range in the file')
        end
    end
    I=zeros(info(1).Height, info(1).Width, numel(idx), selectMATLABDataType(info(1)));
    fp=fopen(fileName, 'r');
    
    for ii=1:numel(idx)
        fseek(fp, info(ii).StripOffsets, 'bof');
        I(:,:,ii)=fread(fp,[info(ii).Width info(ii).Height], ['* ' selectMATLABDataType(info(ii))])';
        fprintf('Loading slice %u of %u...\n', ii,numel(idx))
    end
    [~,differentlyEndian]=getEndianness(info(1));
    if differentlyEndian
        fprintf('Swapping endiannes...')
        I=swapbytes(I);
    end
    fclose(fp);
else %1 IFD at start
    numFramesStr = regexp(info.ImageDescription, 'images=(\d*)', 'tokens');
    if ~isempty(numFramesStr) %It's in imageJ large stack
        numFrames = str2double(numFramesStr{1}{1});
        fp = fopen(fileName , 'rb');
        fseek(fp, info.StripOffsets, 'bof');
        %% Check idx
        if nargin<2||isempty(idx)
            idx=1:numFrames;
        else
            if any(idx)>numel(info)
                error('Index specified out of range in the file')
            end
        end
        %%
        I=zeros(info.Height, info.Width, numel(idx), selectMATLABDataType(info(1)));
        
        for ii = 1:numel(idx)
            I(:,:,ii) = fread(fp, [info.Width info.Height], ['* ' selectMATLABDataType(info(1))])';
             fprintf('Loading slice %u of %u...\n', ii,numel(idx))
        end
        [~,differentlyEndian]=getEndianness(info(1));
        if differentlyEndian
            fprintf('Swapping endiannes...')
            I=swapbytes(I);
        end
        fclose(fp);

    else %assume single slice image
        fprintf('Image seems to only have one slice. Loading...')
        I=imread(fileName);
    end
    fprintf('Done.\n')
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