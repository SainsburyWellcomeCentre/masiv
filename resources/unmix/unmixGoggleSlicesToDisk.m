function unmixGoggleSlicesToDisk(t, emissionCSVFiles, outputChannelNames, varargin)
f=fieldnames(t.stitchedImagePaths);
p=inputParser;
addParameter(p, 'idx', 1:numel(t.stitchedImagePaths.(f{1})));
addParameter(p, 'outputDirectory', fullfile(t.baseDirectory, 'unmixed'));
addParameter(p, 'gaussianBlurRadius', [])

parse(p, varargin{:})

q=p.Results;

if nargin<1 || isempty(t) || ~isa(t, 'TVStitchedMosaicInfo')
    error('First argument should be a TVStitchedMosaicInfo object')
end

if nargin<2||isempty(emissionCSVFiles) || ~iscell(emissionCSVFiles)
    error('Second argument should be a cell array containing the path to emission profiles')
end

emissionMatrixNormalised=loadUnmixingVectors(emissionCSVFiles);

if nargin<3 || isempty(outputChannelNames) || ~iscell(outputChannelNames)|| ~(numel(outputChannelNames)==3)
    error('Third argument should be output channel names')
end

if ~exist(q.outputDirectory, 'dir')
    mkdir(q.outputDirectory)
end



fprintf('Beginning unmixing...\n')

parfor ii=1:numel(q.idx)
    idx=q.idx(ii); %#ok<PFBNS>
          
    fname1=fullfile(t.baseDirectory,t.stitchedImagePaths.Ch01{idx}); %#ok<PFBNS>
    fname2=fullfile(t.baseDirectory,t.stitchedImagePaths.Ch02{idx});
    fname3=fullfile(t.baseDirectory,t.stitchedImagePaths.Ch03{idx});
    
    if ~exist(fname1, 'file')|| ~exist(fname2, 'file') || ~exist(fname3, 'file')
        fprintf('\tOne or more files matching %s could not be loaded. Skipping.\n', t.stitchedImagePaths.Ch01{ii})
    else
        displayName=strrep(t.stitchedImagePaths.Ch01{idx}, '_StitchedImage_Ch_1.tif', '');
        fprintf('\tLoading %s\n', displayName)
        ch1=double(openTiff(fname1));
        ch2=double(openTiff(fname2));
        ch3=double(openTiff(fname3));
        fprintf('\tFiltering %s\n', displayName)
        if ~isempty(q.gaussianBlurRadius)
            ch1=doFilter(ch1, q.gaussianBlurRadius);
            ch2=doFilter(ch2, q.gaussianBlurRadius);
            ch3=doFilter(ch3, q.gaussianBlurRadius);
        end
        fprintf('\tUnmixing %s\n', displayName)
        [ch1Out, ch2Out, ch3Out]=doUnmix(ch1, ch2, ch3, emissionMatrixNormalised);
        
        
        if ~isempty(outputChannelNames{1}) %#ok<PFBNS>
            [~, f]=fileparts(fname1);
            tmpFileName=fullfile(tempdir, [f '.tif']);
            outputFileName=fullfile(q.outputDirectory, [strrep(f, 'Ch_1', outputChannelNames{1}) '.tif']);
            fprintf('\tSaving to %s\n', outputFileName)
            imwrite(uint16(ch1Out), tmpFileName, 'Compression', 'None');
            movefile(tmpFileName,outputFileName);
        end
        
        if ~isempty(outputChannelNames{2})
            [~, f]=fileparts(fname2);
            tmpFileName=fullfile(tempdir, [f '.tif']);
            outputFileName=fullfile(q.outputDirectory, [strrep(f, 'Ch_2', outputChannelNames{2}) '.tif']);
            fprintf('\tSaving to %s\n', outputFileName)
            imwrite(uint16(ch2Out), tmpFileName, 'Compression', 'None');
            movefile(tmpFileName,outputFileName);
        end
        
        if ~isempty(outputChannelNames{3})
            [~, f]=fileparts(fname3);
            tmpFileName=fullfile(tempdir, [f '.tif']);
            outputFileName=fullfile(q.outputDirectory, [strrep(f, 'Ch_3', outputChannelNames{3}) '.tif']);
            fprintf('\tSaving to %s\n', outputFileName)
            imwrite(uint16(ch3Out), tmpFileName, 'Compression', 'None');
            movefile(tmpFileName,outputFileName);
        end
            
    end
end


end

function emissionMatrixNormalised=loadUnmixingVectors(filesToLoad)

   
    %% Load spectral data
    S=cell(size(filesToLoad));
    for ii=1:length(filesToLoad);
        S{ii}=load(filesToLoad{ii});
    end
    
    emissionMatrix=cellfun(@(x) mean(x), S, 'UniformOutput', 0);
    emissionMatrix=cat(1, emissionMatrix{:})';
    %% Normalise each vector to unit length
    emissionMatrixNormalised=bsxfun(@mrdivide, emissionMatrix, sqrt(sum(emissionMatrix.^2)));
end

function [ch1Out, ch2Out, ch3Out]=doUnmix(ch1, ch2, ch3, emissionMatrixNormalised)
    
    [h,w, n]=size(ch1);
    
    u=emissionMatrixNormalised\cat(2, ch1(:), ch2(:), ch3(:))';
    %% Reshape
    ch1Out=reshape(u(1, :), h, w, n);
    ch2Out=reshape(u(2, :), h, w, n);
    ch3Out=reshape(u(3, :), h, w, n);
    
end

function I=doFilter(I, filtSig)
    
    sz=filtSig*8;
    x=-ceil(sz/2):ceil(sz/2);
    H = exp(-(x.^2/(2*filtSig^2)));
    H = H/sum(H(:));
    Hx=reshape(H,[length(H) 1 1]);
    Hy=reshape(H,[1 length(H) 1]);

    
    for ii=1:size(I, 3)
        I(:,:,ii)=imfilter(imfilter(I(:,:,ii), Hx, 'same', 'replicate'), Hy, 'same', 'replicate');
    end
end
