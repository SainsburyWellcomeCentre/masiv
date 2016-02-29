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
            obj.MaSIV=caller.UserData;
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

