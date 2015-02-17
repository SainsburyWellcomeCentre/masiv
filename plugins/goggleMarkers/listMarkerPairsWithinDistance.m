function pairs=listMarkerPairsWithinDistance(markerTable, minSeparationDistance)
if nargin<2||isempty(minSeparationDistance)
    minSeparationDistance=0;
end
%% Get euclidean distance
distances=squareform(pdist([markerTable.x, markerTable.y, markerTable.z]));
%% Set diagonal to NaN
for ii=1:size(distances)
    distances(ii, ii)=NaN;
end
%% Get pair indices
[pairIdxR, pairIdxC]=find(distances<=minSeparationDistance);

pairs= unique(sort([pairIdxR, pairIdxC], 2), 'rows');


end