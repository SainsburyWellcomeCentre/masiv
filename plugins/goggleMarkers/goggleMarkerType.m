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
                    iseq=obj2==obj;
                else
                    iseq=zeros(size(obj));
                    for ii=1:numel(obj)
                        iseq(ii)=obj(ii)==obj2(ii);
                    end
                end
            else
                iseq= strcmp(obj.name, {obj2.name})&cellfun(@(x) all(abs(x-obj.color)<1e-5), {obj2.color});
            end
        end
        function neq=ne(obj,obj2)
            neq=~(obj==obj2);
        end
    end
end