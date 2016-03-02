function [data,changed]=upgradeNeuriteTraces(data)
% convert neurite traces to the new object names
%
% function [data,changed]=upgradeNeuriteTraces(data)
%
% Purpose
% - convert "masivTreeNode" to "neuriteTracerNode"
% - convert "masivMarker" to "neuriteTracerMarker"
% - convert "masivMarkerType" to "neuriteTracerMarkerType"
%
%
% Inputs
% data is the cell array of trees
%
% Outpouts
% data - the modified data
% changed - 0 if nothing was changed 1 otherwise

if ~iscell(data)
	fprintf('%s - "data" should be a cell array of neurite trees\n', mfilename)
	return
end


changed = zeros(size(data));
for ii=1:length(data)
	if isempty(data{ii})
		continue
	end
	[data{ii},changed(ii)] = convertIt(data{ii});	
end

changed = any(changed);


function [data,changed] = convertIt(data)
	changed=0;

	for ii=1:length(data.Node)
		N=data.Node{ii};

		%Replace the masivMarkerType
		origType = N.type;
		if isa(origType,'masivMarkerType')
			new = neuriteTracerMarkerType;
			new.name = origType.name;
			new.color = origType.color;
			changed=1;
		else
			new = origType;
		end


		if isa(N,'masivTreeNode')
			newNode=neuriteTracerNode(new,N.xVoxel,N.yVoxel,N.zVoxel);

			newNode.branchType = N.branchType;
			newNode.isPrematureTermination = N.isPrematureTermination;
            newNode.isBouton = N.isBouton;
			newNode.data = N.data;

			data.Node{ii}=newNode;
			changed=1;
		elseif isa(N,'masivMarker') 
			newNode=neuriteTracerNode(new,N.xVoxel,N.yVoxel,N.zVoxel);

			newNode.branchType = '';
			newNode.isPrematureTermination = 0;
            newNode.isBouton = 0;
			newNode.data = struct;

			data.Node{ii}=newNode;
			changed=1;
		else
			N.type=new;			
			data.Node{ii}=N;
		end


	end