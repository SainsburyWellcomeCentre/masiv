classdef goggleMarker
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
        function obj=goggleMarker(type, x, y, z)
            if nargin>0
                if isa(type, 'goggleMarkerType')
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
                    obj(numel(x))=goggleMarker;
                    for ii=1:numel(x)
                        obj(ii)=goggleMarker(type, x(ii), y(ii), z(ii));
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
        
    end
end