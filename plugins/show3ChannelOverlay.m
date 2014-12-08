classdef show3ChannelOverlay<goggleBoxPlugin
    %SHOW3CHANNELOVERLAY Opens the current view in a new window, with all 3
    %channels
    
    properties
    end
    
    methods
        function obj=show3ChannelOverlay(caller, ~)
            gvObj=caller.UserData;
            mosaicInfo=gvObj.mosaicInfo;
            
            xView=round(gvObj.hImgAx.XLim);xView(xView<1)=1;
            yView=round(gvObj.hImgAx.YLim);yView(yView<1)=1;
            sliceNum=gvObj.mainDisplay.currentZPlaneOriginalVoxels;
            
            baseDir=mosaicInfo.baseDirectory;
            tic
            ch01=(openTiff(fullfile(baseDir, mosaicInfo.stitchedImagePaths.Ch01{sliceNum}), [xView(1) yView(1) range(xView)+1 range(yView+1)], 1));
            ch02=(openTiff(fullfile(baseDir, mosaicInfo.stitchedImagePaths.Ch02{sliceNum}), [xView(1) yView(1) range(xView)+1 range(yView+1)], 1));
            ch03=(openTiff(fullfile(baseDir, mosaicInfo.stitchedImagePaths.Ch03{sliceNum}), [xView(1) yView(1) range(xView)+1 range(yView+1)], 1));
            clc
            fprintf('Load time: %3.2fs\n', toc),tic
                       
            I=double(cat(3, ch01, ch02, ch03));
            %if strcmp(questdlg('Apply unmixing?', '3 channel display', 'Yes', 'No', 'Yes'), 'Yes')
                I=unmix(I);
            %end
            fprintf('Unmixed in %3.2fs\n', toc),tic
            figure
            subplot('Position', [0.05 0.06 0.2 0.9])
            hold on
            
            bins=2000;
            
            histogram(I(:,:,1), bins, 'EdgeColor', 'none', 'FaceColor', hsv2rgb([0 0.8 0.8]))
            histogram(I(:,:,2), bins, 'EdgeColor', 'none', 'FaceColor', hsv2rgb([0.3 0.8 0.8]))
            histogram(I(:,:,3), bins, 'EdgeColor', 'none', 'FaceColor', hsv2rgb([0.6 0.8 0.8]))
            xlim([0 prctile(I(:), 99)])

            fprintf('Histogram displayed in %3.2fs\n', toc),tic

            hold off

            subplot('Position', [0.28 0.02 0.68 0.96])
            I=trueColorImage(I);
            fprintf('Truecolor conversion in %3.2fs\n', toc),tic
            I=defaultAdjustImage(I);
            fprintf('Adjusted in %3.2fs\n', toc),tic

            imshow(I)
            
           
        end
    end
    
    methods(Static)
        function d=displayString
            d='Show 3 channel overlay of current view';
        end
    end
    
end

function I=trueColorImage(I)
    I=I-min(I(:));
    I=I./max(I(:));
end

function I=defaultAdjustImage(I)
    for ii=1:size(I, 3)
        I(:,:,ii)=imadjust(I(:,:,ii), stretchlim(I(:,:,ii), [0.001 0.999]));
    end
end

function I=unmix(I)
    
    
    I=doFilter(I, 1.5);
    I=doUnmix(I);

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

function I=doUnmix(I)
    %% Get Vectors
    emissionMatrixNormalised=loadUnmixingVectorsNoGui;
    


    %% Do unmixing
    ch1=I(:,:,1);
    ch2=I(:,:,2);
    ch3=I(:,:,3);

    [h,w, n]=size(ch1);
    
    u=emissionMatrixNormalised\cat(2, ch1(:), ch2(:), ch3(:))';
    %% Reshape
    ch1Out=reshape(u(1, :), h, w, n);
    ch2Out=reshape(u(2, :), h, w, n);
    ch3Out=reshape(u(3, :), h, w, n);
    
    I=cat(3, ch1Out, ch2Out, ch3Out);
end

function emissionMatrixNormalised=loadUnmixingVectorsNoGui()
    sourceDirectory='unmixing/sources/';
    
    filesToLoad=cellfun(@(x) fullfile(sourceDirectory, [x '.csv']),  {'tagRFP', 'GFP', 'Cerulean'},'UniformOutput',0 );
    spectraNames=strrep(strrep(filesToLoad, '.csv', ''),sourceDirectory, '');
    
    %% Load spectral data
    S=cell(size(spectraNames));
    for ii=1:length(spectraNames);
        S{ii}=load(filesToLoad{ii});
    end
    
    emissionMatrix=cellfun(@(x) mean(x), S, 'UniformOutput', 0);
    emissionMatrix=cat(1, emissionMatrix{:})';
    %% Normalise each vector to unit length
    emissionMatrixNormalised=bsxfun(@mrdivide, emissionMatrix, sqrt(sum(emissionMatrix.^2)));
end
