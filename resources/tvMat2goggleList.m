function tvMat2goggleList(stitchedDir)
% Make goggleViewer files listing the stitched file locations from tvMat data
%
% function makeStictichedFileLists(stitchedDir)
%
%
% Purpose
% Make stitched image file lists from data stitched with tvMat to
% enable import into goggleViewer.
%
%
% Inputs
% stitchedDir - path to stitched data directory. 
%
% 
% Rob Campbell



if ~exist(stitchedDir,'dir')
	fprintf('Directory %s not found\n',stitchedDir)
	return
end


%Make file root name
baseName=directoryBaseName(getMosaicName);
baseName(end)=[]; %remove trailing '-'
stitchedFileListName=[baseName,'_','StitchedImagesPaths','_'];



%find the channels
chans = dir(stitchedDir);

for ii=1:length(chans)

	if regexp(chans(ii).name,'\d+')

		fprintf('Making channel %s file\n',chans(ii).name)
		tifDir=[stitchedDir,filesep,chans(ii).name];
		tifs=dir([tifDir,filesep,'*.tif']);

		if isempty(tifs)
			fprintf('No tiffs in %s. Skipping\n',tifDir)
			continue
		end

		thisChan = str2num(chans(ii).name);
        
		fid=fopen(sprintf('%sCh%02d.txt',stitchedFileListName,thisChan),'w+');
		for thisTif = 1:length(tifs)
			fprintf(fid,[tifDir,filesep,tifs(thisTif).name,'\n']);
		end
		fclose(fid);

	end

end
