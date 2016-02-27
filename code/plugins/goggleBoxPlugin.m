classdef(Abstract) goggleBoxPlugin<handle
    %GOGGLEBOXPLUGIN Base class for goggleBoxPlugins. 
    
    properties
        parentMenuItem
        goggleViewer
        Meta
    end
    
    methods
        function obj=goggleBoxPlugin(caller)
            obj.goggleViewer=caller.UserData;
            obj.Meta=obj.goggleViewer.Meta;
            
            items=get(obj.goggleViewer.mnuPlugins, 'Children');
            obj.parentMenuItem=findall(items, 'Label', obj.displayString);
            set(obj.parentMenuItem, 'Enable', 'off');
        end
        function deleteRequest(obj)
            set(obj.parentMenuItem, 'Enable', 'on');
        end
        function registerPluginAsOpenWithParentViewer(obj)
            obj.goggleViewer.registerOpenPluginForCloseReqs(obj)
        end
        function deregisterPluginAsOpenWithParentViewer(obj)
             obj.goggleViewer.deregisterOpenPluginForCloseReqs(obj)
        end
        
    end
    methods(Static)
        displayString
    end
    
end

