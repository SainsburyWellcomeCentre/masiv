function T=convertMarkerStructToTable(yml) %#ok<*AGROW>
% Convert masivmarker structure into a table. 
%
% function T=convertMarkerStructToTable(yml) 
%
% e.g.
%  Y=YAML.read('my_points.yml')
%  T=convertMarkerStructToTable(T)

ML=[];
DV=[];
PA=[];
type={};
f=fieldnames(yml);
for ii=1:numel(f)
    if isfield(yml.(f{ii}), 'markers')
        thisTypeX=[yml.(f{ii}).markers.x]';
        thisTypeY=[yml.(f{ii}).markers.y]';
        thisTypeZ=[yml.(f{ii}).markers.z]';
        
        ML=[ML; thisTypeX];
        DV=[DV; thisTypeY];
        PA=[PA; thisTypeZ];
        type=[type; repmat(f(ii), numel(thisTypeX), 1)];
    end
end

type=categorical(type);
T=table(ML, DV, PA, type);
end