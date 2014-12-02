classdef goggleMarkerType
    properties
        name=''
        color=[1 0 0]
    end
    methods
        function obj=goggleMarkerType(name, color)
            if nargin>0&&~isempty(name)
                obj.name=name;
            end
            if nargin>1&&~isempty(color)
                obj.color=color;
            end
        end
        function iseq=eq(obj, obj2)
            if ~isa(obj2, 'goggleMarkerType')
                error('Can''t compare goggleMarkerType to an object not of this class')
            end
            if numel(obj)>1
                if numel(obj2)==1
                    tmpObj=obj;
                    obj=obj2;
                    obj2=tmpObj;
                else
                    error('Can''t compare two object arrays')
                end
            end
            iseq= strcmp(obj.name, {obj2.name})&cellfun(@(x) all(x==obj.color), {obj2.color});
        end
    end
end