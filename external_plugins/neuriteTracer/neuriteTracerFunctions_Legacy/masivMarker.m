classdef masivMarker
    properties
        type
        xVoxel
        yVoxel
        zVoxel
    end
    properties(SetAccess=protected, Dependent)
        color
    end
    methods
        %% Constructor
        function obj=masivMarker(type, x, y, z)
            if nargin>0
                if isa(type, 'masivMarkerType')
                    obj.type=type;
                else
                    error('Must be a valid marker type')
                end
            end
            if nargin>1
                if ~isscalar(x)
                    if any(diff([numel(x) numel(y) numel(z)]));
                        error('x y and z vectors must be of equal size')
                    end
                    obj(numel(x))=masivMarker;
                    for ii=1:numel(x)
                        obj(ii)=masivMarker(type, x(ii), y(ii), z(ii));
                    end
                elseif isnumeric(x)
                    obj.xVoxel=x;
                    if nargin>2
                        if ~isnumeric(y)||numel(y)~=1
                            error('Y must be a numeric scalar')
                        end
                        obj.yVoxel=y;
                    end
                    if nargin>3 
                        if ~isnumeric(z)||numel(z)~=1
                            error('Z must be a numeric scalar')
                        end
                        obj.zVoxel=z;
                    end
                end
            end
        end
        
        %% Conversion function
        function s=toStructArray(obj)
            s=struct('x', {obj.xVoxel}, 'y', {obj.yVoxel}, 'z', {obj.zVoxel});
        end
        %% Getter
        function col=get.color(obj)
            col=obj.type.color;
        end
        %% Iseq
        function e=eq(obj, obj2)
            if isempty(obj)||isempty(obj2)
                e=0;
                return
            end
            if isscalar(obj)
                if ~isa(obj2, 'masivMarker')
                    error('Comparator must be a masivMarker object')
                end
                if ~isscalar(obj2)
                    e=obj2==obj;
                else
                    e=(obj.xVoxel==obj2.xVoxel)&&(obj.yVoxel==obj2.yVoxel)&&(obj.zVoxel==obj2.zVoxel)&&(obj.type==obj2.type);
                end
              
            else
                if (numel(obj)==numel(obj2))
                    e=zeros(numel(obj), 1);
                    for ii=1:numel(obj)
                        e(ii)=obj(ii)==obj2(ii);
                    end
                elseif isscalar(obj2)
                    for ii=1:numel(obj)
                        e(ii)=obj(ii)==obj2;
                    end
                else
                    error('arrays must be of the same size')
                end
                
            end
        end
        function e=ne(obj, obj2)
            e=~(obj==obj2);
        end
        %% Sorting
        function [sorted, idx]=sort(obj)
           xyz=cat(1, [obj.xVoxel],[obj.yVoxel], [obj.zVoxel]);
           [~, idx]=sortrows(xyz', [3 1 2]);
           sorted=obj(idx);
        end
        
    end
end