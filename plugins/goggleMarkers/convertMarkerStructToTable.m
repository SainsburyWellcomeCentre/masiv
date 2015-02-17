function T=convertMarkerStructToTable(yml) %#ok<*AGROW>
x=[];
y=[];
z=[];
type={};
f=fieldnames(yml);
for ii=1:numel(f)
    if isfield(yml.(f{ii}), 'markers')
        thisTypeX=[yml.(f{ii}).markers.x]';
        thisTypeY=[yml.(f{ii}).markers.y]';
        thisTypeZ=[yml.(f{ii}).markers.z]';
        
        x=[x; thisTypeX];
        y=[y; thisTypeY];
        z=[z; thisTypeZ];
        type=[type; repmat(f(ii), numel(thisTypeX), 1)];
    end
end

type=categorical(type);
T=table(x, y, z, type);
end