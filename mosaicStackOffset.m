function offsets=mosaicStackOffset(t, channelToCalculateOn, regionSpec)

    nLayers=t.metaData.layers;
    
    f=fullfile(t.baseDirectory, t.stitchedImagePaths.(channelToCalculateOn));
    
    fSource=f(nLayers+1:nLayers:end);
    fTarget=f(nLayers:nLayers:end-1);
    offsets=getImageFilesXYOffsets(fSource, fTarget, regionSpec, 50, 0);
    
    %% Centre and expand
    offsets=cat(1, zeros(1, 2), offsets);
    offsets=bsxfun(@minus, offsets, median(offsets));
    
    offsets=reshape(repmat(offsets, 1,nLayers)', 2, [])';

end