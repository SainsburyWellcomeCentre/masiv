function markerStruct=convertTableToMarkerStruct(T)
%CONVERTTABLETOMARKERSTRUCT 

types=categories(T.type);


for ii=1:size(types)
    theseTypeMarkers=T(T.type==types(ii), :);
    newStruct=struct('x', num2cell(theseTypeMarkers.x)', 'y', num2cell(theseTypeMarkers.y)', 'z', num2cell(theseTypeMarkers.z)');
    markerStruct.(types{ii}).markers=newStruct;
end
end