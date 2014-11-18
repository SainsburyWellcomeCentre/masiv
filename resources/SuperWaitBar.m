classdef SuperWaitBar<handle
    properties
        h
        x
    end
    properties(Access=protected)
        increment
    end
    methods
        function obj=SuperWaitBar(N, msg)
            obj.increment=1/N;
            obj.h=waitbar(0, msg);
            obj.x=0;
        end
        function progress(obj)
            obj.x=obj.x+obj.increment;
        end
        function set.x(obj,x)
            waitbar(x, obj.h) %#ok<MCSUP>
            obj.x=x;
        end
        function delete(obj)
            delete(obj.h)
            delete(obj)
        end
    end
end