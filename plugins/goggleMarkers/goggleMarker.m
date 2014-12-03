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
                if isscalar(x)&&isnumeric(x)
                    obj.xVoxel=x;
                end
            end
            if nargin>2
                if isscalar(y)&&isnumeric(y)
                    obj.yVoxel=y;
                end
            end
            if nargin>3
                if isscalar(z)&&isnumeric(z)
                    obj.zVoxel=z;
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