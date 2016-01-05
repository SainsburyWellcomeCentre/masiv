function [I,info] = openTiff(fileName, regionSpec, downSample, methodFlag)
% fast loading of a tiff (or a portion of a TIFF) from disk
%
% function [I,info] = openTiff(fileName, regionSpec, downSample, methodFlag)
%
% 
% Purpose
% Fast tiff loading that bypasses imread. For fast loading you will
% need un-cropped images. This function reverts to imread if the 
% input image is compressed. Two fast reading approaches are
% provided. 
%
% 
% Inputs
% fileName - relative or full path to the tiff image. (string)
% regionSpec - Optional vector of length 4 defining the sub-region
%              of the image to load. [x y w h], origin top left
%              corner. Indexing is 1 based. If empty or missing, 
%              the full image is loaded. 
% downSample - Optionally down-sample by this factor using bicubic 
%              interpolation. If 1, missing, or empty then no down
%              sampling is performed. 
% methodFlag - Optional argument (a scalar from 0 to 3) which
%              defines the method for loading tiff file. Methods
%              are:
%                  0 - built-in imread with cropping performed
%                      after loading. 
%                  1 - built-in imread with cropping performed
%                      during loading. 
%                  2 - raw reading with fread. [default]. Fastest
%                      for full and, particularly, cropped images.
%                  3 - raw reading with memmap. Slower than (2) if
%                      image is cropped. 
%
%
% Output 
% I - matrix containing the image read from disk.
% info - a structure containing the image header information. 
%
%
% Alex Brown

  
  
%% Input parsing
if ~ischar(fileName)
    error('fileName must be a single character array')
elseif ~exist(fileName, 'file')
    error('File specified (%s) does not exist', fileName)
end


% Downsample: default to 1
if nargin<3||isempty(downSample)
    downSample=1;
end

% Default to fastest method
if nargin<4||isempty(methodFlag)
    methodFlag=2;
end

%% Crop spec
if nargin>1 && length(regionSpec)==4
    if ~isnumeric(regionSpec)||~isvector(regionSpec)||numel(regionSpec)~=4||any(regionSpec<1)
            error('regionSpec must be 4-element numeric vector with all elements > 0.\n Start indices are 1-based; w and h must be positive integers')
    end
    [x,y,~,h,x2,y2]=getCropParams(regionSpec);
    doCrop=1;
else
    doCrop=0;
end

%% Exceptions to method selection
%Do not do methods 2 or 3 if data are compressed
try
  info=imfinfo(fileName);
catch
  fprintf('%s failed with file %s\n\n', mfilename, fileName);
  rethrow(lasterror)
  return
end

if ~strcmp(info.Compression,'Uncompressed') && methodFlag>1
  fprintf('images are %s compressed. Reverting to imread.\n',info.Compression)

  if doCrop
    methodFlag=1;
  else
    methodFlag=0;
  end
  
end
       

%Don't do method 2 if not cropping: Edit AB: Why not? It's still quicker
% if ~doCrop && methodFlag==1
%   methodFlag=0;
% end


%% Do it
switch methodFlag
    case 0 %Read in, select region in memory. ~6s per slice
        I=imread(fileName);
        if doCrop
            I=I(y:y2, x:x2);
        end
    case 1 % Pixel region selection in imread. ~6s per slice
        I=imread(fileName, 'PixelRegion', {[y y2] [x x2]});
    case 2 % fread needed lines only; select pixels within line in memory. This is the fastest currently implemented.
        fh=fopen(fileName);
        
        if ~doCrop
            [x,y,~,h,x2,~]=getCropParams([1 1 info.Width info.Height]);
        end
        
        offset=info.StripOffsets(1)+(y-1)*info.Width*info.BitDepth/8;
        fseek(fh, offset, 'bof');

        %the second argument allows us (if cropping was requested)
        %to read all rows, but only the requested rows (we transpose below)
        I=fread(fh, [info.Width, h], ['*' selectMATLABDataType(info)], 0, selectMachineFormat(info));

        %Now trim the image to retain only the columns
        I=I(x:x2, :)';

        fclose(fh);
    case 3 %memmap method. This is equally fast as the fread method
           %for un-cropped images. It's much slower when images are
           %cropped. 
        info=imfinfo(fileName);
        if ~doCrop
            [x,y,~,~,x2,y2]=getCropParams([1 1 info.Width info.Height]);
        end
        m=memmapfile(fileName,...
                     'Offset', info.StripOffsets(1),...
                     'Format', {selectMATLABDataType(info),...
                     [info.Width info.Height], 'm'});
        dat=m.Data;
        I=dat.m(x:x2, y:y2);
        I=I';
        if ~isempty(strfind(info.ByteOrder,'big-'))
          I=swapbytes(I);
        end
        
end


%% Methods 0-3 do not have inbuilt downsampling, so downsample the loaded image if requested
if downSample~=1
    I=imresize(I, 1/downSample, 'bicubic');
end
end


function [x,y,w,h,x2,y2]=getCropParams(regionSpec)
  x=regionSpec(1);
  y=regionSpec(2);
  w=regionSpec(3);
  h=regionSpec(4);
  y2=y+h-1;
  x2=x+w-1;
end


function mft=selectMachineFormat(info)
  if ~isempty(strfind(info.ByteOrder,'little-'))
    mft = 'ieee-le';
  elseif ~isempty(strfind(info.ByteOrder,'big-'))
    mft = 'ieee-be';
  else
    fprintf('Can not determine byte order. defaulting to native.\n')
    mft = 'n';
    return
  end
  
  if ~isempty(strfind(info.ByteOrder,'64'))
    mft = [mft,'.l64'];
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
