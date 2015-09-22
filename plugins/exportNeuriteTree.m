function varargout = exportNeuriteTree(neuriteTree,fname,downSample)
% export a neurite tree to a text file or return it as a matrix
%
% function treeData = exportNeuriteTree(neuriteTree,fname,downSample))
%
%
% Purpose
%   The neurite trees are stored in a tree structure defined by the matlab-tree class
% (see: https://github.com/raacampbell13/matlab-tree). This function allows the tree
% to be exported to a text file in a way that maintains the information describing 
% the relationships between nodes. So the tree can be re-built in another programming 
% language of the user's choice. 
%   This function also provides the option of down-sampling the exported data. This 
% is useful in case the user wishes to plot the exported tree over a down-sampled
% brain, such as one in the Allen Reference Atlas space.
%
% 
% Inputs
% neuriteTree - an instance of the neurite tree class. (i.e. not the cell array
% 				returned by goggleNeuriteTracer but one of its cells)
% fname - path to the file that will contain the dumped tree. If empty no saving
%         to disk is performed. 
% downSample - a vector or length 2 defining how much to down-sample the tree in
%              xy and in z. e.g. [20,5] will down-sample by 20 times in x and y and 
%              by 5 times in z. 
%
%
% Outputs
% treeData - optionally return a matrix containing the dumped tree data. 
%
% 
% Output format
% The returned matrix and the dumped file are in following format:
%  * One row per node
%  * Each row is: [nodeId,parentID,z position,x position,y position]
%  * The node with a parent ID of zero is the root node
%
%
% Rob Campbell - Basel 2015



if ~strcmp(class(neuriteTree),'tree')
	fprintf('neuriteTree should be of class "tree", it is of class %s\n',class(neuriteTree))
	return
end

if nargin<2
	fname = [];
end

if nargin<3
	downSample=[1,1];
end


if isempty(fname) & nargout==0
	fprintf('No outputs requested\n')
	return
end




%Dump tree to a string using the dumptree method in matlab-tree
treeAsTextDump = neuriteTree.dumptree(@(n) sprintf('%0.3f,%0.3f,%0.3f',n.zVoxel/downSample(2),n.xVoxel/downSample(1),n.yVoxel/downSample(1)));

if length(treeAsTextDump)==0
	fprintf('Something went wrong with the tree dump: no data were returned\n')
	return
end


%Save to a file 
if ~isempty(fname)
	fid = fopen(fname,'w+');
	fprintf(fid,'%s',treeAsTextDump);
	fclose(fid);
end



%Return as a matrix if the user asked for this
if nargout>0
	varargout{1}=str2num(treeAsTextDump);
end

