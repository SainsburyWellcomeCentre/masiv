function I = createDownscaledStack( mosaicInfo, channel, idx, varargin )
%CREATEDOWNSCALEDSTACK 

%% Input parsing
p=inputParser;

addRequired(p, 'mosaicInfo', @(x) isa(x, 'TVStitchedMosaicInfo'));
addRequired(p, 'channel', @isstr);
addRequired(p, 'idx', @isvector)
addOptional(p, 'downSample', 1, @(x) isscalar(x));

parse(p, mosaicInfo, channel, idx, varargin{:})
q=p.Results;
if ~isfield(q.mosaicInfo.stitchedImagePaths, channel)
    error('Unknown channel identifier: %s', channel)
end

%% Start default parallel pool if not already
gcp;

%% Generate full file path
pths=fullfile(mosaicInfo.baseDirectory, mosaicInfo.stitchedImagePaths.(channel));
%% Get file information to determine crop
info=cell(numel(idx), 1);

fprintf('Getting file information...')
parfor ii=1:numel(idx)
    info{ii}=imfinfo(pths{ii});
end

fprintf('Done\n')
%%
minWidth=min(cellfun(@(x) x.Width, info));
minHeight=min(cellfun(@(x) x.Height, info));

outputImageWidth=ceil(minWidth/q.downSample);
outputImageHeight=ceil(minHeight/q.downSample);


fprintf('Preinitialising...')
I=zeros(outputImageHeight, outputImageWidth, numel(idx), 'uint16');
fprintf('Done\n')


fprintf('Loading stack...\n')


parfor ii=1:numel(idx)
    fName=fullfile(mosaicInfo.baseDirectory, mosaicInfo.stitchedImagePaths.(channel){idx(ii)});
    I(:,:,ii)=openTiff(fName, [1 1 minWidth minHeight], q.downSample);
    fprintf('\tSlice %u loaded\n', idx(ii))
end


fprintf('\tDone\n')
end

