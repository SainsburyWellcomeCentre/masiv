function varargout = exportGogglePoints(ymlPoints,fname,downSample,separateFiles)
% export a neurite tree to a text file or return it as a matrix
%
% function logging = exportGogglePoints(ymlPoints,fname,downSample,separateFiles)
%
%
% Purpose
%  Clicked point data are stored in a YAML file that lists the voxels that contain 
% clicked points, the series of the points, and color associated with them. This 
% function exports the point list to a csv file. The user can optionally down-sample 
% the coordinates or write a series of files (one per point series).  Exporting is 
% useful if for overlaying points over a down-sampled brain, such as one in the Allen
% Reference Atlas space.
% 
% Inputs
% ymlPoints - a string defining the path to a YAML file or a points structure that has
%             been imported by readSimpleYAML.
% fname - path to the csv file that will contain the exported data. 
% downSample - a vector or length 2 defining how much to down-sample the tree in
%              xy and in z. e.g. [20,5] will down-sample by 20 times in x and y and 
%              by 5 times in z. [OPTIONAL]
% separateFiles - false by default. If true, separate point series are saved to 
%                 separate files.  
% 
% Output CSV format
% The returned the exported data are in following format:
%  * One row per point
%  * If separateFiles is false, each row is: 
%    [z position,x position,y position,point series]
%  * If separateFiles is true, each row is: 
%    [z position,x position,y position]
%
%
%
% Outputs
% logging - [optional] contains the names of the files that were created 
%
%
% Rob Campbell - Basel 2015
%
% See also: convertMarkerStructToTable, readSimpleYAML


if isstr(ymlPoints)
	fprintf('Reading %s\n', ymlPoints)
	ymlPoints=readSimpleYAML(ymlPoints);
end

if nargin<2
	fprintf('A file name must be supplied\n')
end

if nargin<3
	downSample=[1,1];
end

if nargin<4
	separateFiles=false;
end

if separateFiles==false
	thisFname=fname;
end


%Loop through the fields of ymlPoints and write to disk
if ~separateFiles
	fid = fopen(fname,'w+');
	logging.fname = fname;
	logging.type = 'sparse points';
	logging.downsample=downSample;
end

theseFields = fields(ymlPoints);
for ii = 1:length(theseFields) %loop through each point series

	thisField = theseFields{ii};

	if ~isfield(ymlPoints.(thisField),'markers')
		continue
	end

	mrk = ymlPoints.(thisField).markers;
	if length(mrk)==0 %unlikely, but let's check anyway
		continue
	end

	if separateFiles
		[filePath,fileName,fileExtension] = fileparts(fname);
		thisFname = sprintf('%s_%02d%s', fileName,ii,fileExtension);
		thisFname = fullfile(filePath,thisFname);
		fid = fopen(thisFname,'w+');
		logging(ii).fname = thisFname;
		logging(ii).type = 'sparse points';
		logging(ii).downsample=downSample;
	end

	for m = 1:length(mrk)
		thisLine = sprintf('%0.3f,%0.3f,%0.3f', mrk(m).z/downSample(2), mrk(m).x/downSample(1), mrk(m).y/downSample(1));
		if ~separateFiles
			thisLine = sprintf('%s,%d',thisLine,ii); %add index for this line series
		end

		fprintf(fid,'%s\n',thisLine); %write it
	end

	if separateFiles
		fclose(fid);
	end

	fprintf('Wrote %d points from series %s to %s\n', length(mrk), thisField, thisFname)

end 

if ~separateFiles
	fclose(fid);
end



if nargout>0
	logging(cellfun(@isempty,{logging.fname})) = []; %remove empty structures
	varargout{1}=logging;
end