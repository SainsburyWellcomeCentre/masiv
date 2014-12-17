function offsets=getImageFilesXYOffsets(imageFileListSource, imageFileListTarget, regionSpec, maxMove, exceedMaxBehaviour)
% GETXYOFFSETS Loads specific image regions from a list and calculates the
% registration parameters between consecutive pairs of images. Returns the
% CUMULATIVE offset for each image (i.e. the offset relative to the first
% image)

    if ~all(size(imageFileListSource)==size(imageFileListTarget))
        error('File Lists must be the same size')
    end    
    
    offsets=zeros(numel(imageFileListSource), 2);
    %% Process each pair
    for ii=1:numel(imageFileListTarget)
        targetImageFFT=fft2(openTiff(imageFileListTarget{ii}, regionSpec, 1));
        sourceImageFFT=fft2(openTiff(imageFileListSource{ii}, regionSpec, 1));
        output=dftregistration(targetImageFFT, sourceImageFFT, 1);
        offsets(ii, :)=output(3:4);
    end
    % Sort out where it's too much
    eucDist=sqrt(sum(offsets.^2, 2));
    switch exceedMaxBehaviour
        case 0
            offsets(eucDist>maxMove, :)=0;
        case 1
            offsets(eucDist>maxMove, :)=offsets(eucDist>maxMove, :)*maxMove./eucDist;
        otherwise
            error('Unrecognised exceedMaxBehaviou')
    end
    %% Make it cumulative
    offsets=cumsum(offsets);
end
