function I = quickOpenStitchedImageRegion( fileName, regionSpec , methodFlag)
%
% regionSpec: [x y w h], origin top left corner. 1 based.
%

%% Input parsing
if ~ischar(fileName)
    error('fileName must be a single character array')
elseif ~exist(fileName, 'file')
    error('File specified does not exist')
end

if any(regionSpec)<1
    error('All elements of regionSpec must be >0.\n Start indices are 1-based and w and h must be positive integers')
end
%%

x=regionSpec(1);
y=regionSpec(2);
w=regionSpec(3);
h=regionSpec(4);
y2=y+h-1;
x2=x+w-1;

%% Do it
switch methodFlag
    case 0 %Read in, select region in memory. ~6s per slice
        I=imread(fileName);
        I=I(y:y2, x:x2);
    case 1 % Pixel region selection in imread. ~6s per slice
        I=imread(fileName, 'PixelRegion', {[y y2] [x x2]});
    case 2 % fread needed lines only; select pixels within line in memory. This is the fastest currently implemented.
        fh=fopen(fileName);
        info=imfinfo(fileName);
        fseek(fh, info.StripOffsets+(y-1)*info.Width*info.BitDepth/8, 'bof');
        I=fread(fh, [info.Width, h], ['*' selectMATLABDataType(info)], 0, 'ieee-be');
        I=I(x:x2, :)';
    case 3 %memmap method
        info=imfinfo(fileName);
        m=memmapfile(fileName, 'Offset', info.StripOffsets, 'Format', {selectMATLABDataType(info), [info.Width info.Height], 'm'});
        dat=m.Data;
        I=dat.m(x:x2, y:y2);
        I=swapbytes(I)';
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