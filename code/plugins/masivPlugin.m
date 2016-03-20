classdef(Abstract) masivPlugin<handle
    % masivPlugin
    %  Base class for masivPlugins. 
    
    properties
        parentMenuItem
        MaSIV
        Meta
    end
    
    methods
        function obj=masivPlugin(caller)
            if isa(caller, 'uimenu')
                obj.MaSIV=caller.UserData;
            else
                obj.MaSIV=caller;
            end
            obj.Meta=obj.MaSIV.Meta;
            
            items=get(obj.MaSIV.mnuPlugins, 'Children');
            obj.parentMenuItem=findall(items, 'Label', obj.displayString);
            set(obj.parentMenuItem, 'Enable', 'off');
        end
        function deleteRequest(obj)
            set(obj.parentMenuItem, 'Enable', 'on');
        end
        function registerPluginAsOpenWithParentViewer(obj)
            obj.MaSIV.registerOpenPluginForCloseReqs(obj)
        end
        function deregisterPluginAsOpenWithParentViewer(obj)
             obj.MaSIV.deregisterOpenPluginForCloseReqs(obj)
        end
        
    end
    methods(Static)
        displayString
    end
    
end

