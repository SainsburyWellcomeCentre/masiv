function saveTiffStack(I, fileName)
if ~strfind(fileName, '.tif')
    fileName=[fileName, '.tif'];
end
imwrite(I(:,:,1), fileName);
for ii=2:size(I, 3)
    imwrite(I(:,:,ii), fileName, 'writemode', 'append');
    fprintf('Saving slice %u of %u...\n', ii, size(I,3))
end
fprintf('Done. %u pages save to %s\n', size(I, 3), fileName)
end