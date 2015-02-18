function nmList=generateGBChannelFileList(t, channelName, subDir, outputToTextFile)

nFiles=numel(t.stitchedImagePaths.Ch01);

nmList=cell(nFiles, 1);
for ii=1:nFiles
    fileName=sprintf('%s_Layer_%04u_StitchedImage_%s.tif', t.sampleName, ii, channelName);
    nmList{ii}=fullfile(t.baseDirectory,subDir, fileName);
end

if nargin>3 && outputToTextFile==1;
    fName=fullfile(t.baseDirectory, [t.sampleName '_StitchedImagesPaths_' channelName '.txt']);
    if exist(fName, 'file')
        error('File %s already exists. Can not overwrite, for safety reasons!', fName)
    end
    f=fopen(fName, 'wt');
    fprintf(f, '%s\n',nmList{:});
    fclose(f);
end

end