classdef drawRandomPoints<goggleBoxPlugin %drawRandomPoints inherits goggleBoxPlugin


	% Purpose 
	% drawRandomPoints is an example plugin to show how the plugin system works.
	% Starting the plugin creates a GUI window with three buttons and one slider:
	% 1. Button that draws randomly positioned marker in the current view (over the image). 
	%    Pressing again will draw more markers.
	% 2. Button to delete all drawn markers.
	% 3. Button exit the GUI. Pressing the regular close button in the menu bar 
	%    also does this. 
    % 4. A slider that allows the user to specify how many random points will be plotted. 
    %
	%
	% Markers are drawn using the goggleMarker class
	%
	%
    % The plugin system is written using object oriented MATLAB code. If this is new
    % to you, you might want to read up on this in the MATLAB docs. 
	%
	%
	%
	% Rob Campbell - Basel 2015



	%Define properties of testPlug
	properties   
	    hFig
        fontName
        fontSize

        markers
        hDisplayedMarkers
        hDisplayedMarkerHighlights

        slider
        sliderBaseString
        txtBox

        keyPressListener        
        scrolledListener
        zoomedListener
        pannedListener
	end

    %Define protected properties
    properties(Dependent, SetAccess=protected)
        currentType
        cursorZVoxels
        cursorZUnits
    end


	%Define methods of testPlug
	methods 
	   %Constructor - runs once when testPlug is loaded
	   function obj = drawRandomPoints(caller,~)
	   	obj=obj@goggleBoxPlugin(caller);
	   	obj.goggleViewer=caller.UserData;            

	   	%% Get settings from main GUI so we can apply to plugin GUI
        obj.fontName=gbSetting('font.name');
        obj.fontSize=gbSetting('font.size');

        %Create GUI window for plugin and position nicely on screen
        ssz=get(0, 'ScreenSize');
        lb=[ssz(3)/3 ssz(4)/3];
        pos=round([lb 400 400]);

        obj.hFig=figure(...
                'Position', pos, ...
                'CloseRequestFcn', {@deleteRequest, obj}, ...
                'MenuBar', 'none', ...
                'NumberTitle', 'off', ...
                'Name', ['Test Plugin: ' obj.goggleViewer.Meta.experimentName], ...
                'Color', gbSetting('viewer.panelBkgdColor'), ...
                'KeyPressFcn', {@keyPress, obj});


        %Add some wonderful buttons to our plugin's GUI
        buttonDefaults={...
            'Parent', obj.hFig, ...
            'Style', 'pushbutton', ...
            'Units', 'normalized', ...
            'FontName', obj.fontName, ...
            'FontSize', obj.fontSize, ...          
            'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
            'ForegroundColor', gbSetting('viewer.textMainColor') };

       uicontrol(...
       	buttonDefaults{:},...
       	'Position', [0.05 0.90 0.55 0.06], ...
        'String', 'Draw random markers', ...
        'Value', 1, ...
        'Callback', {@addMarkers, obj});

        uicontrol(...
         buttonDefaults{:}, ...
         'Position', [0.05 0.80 0.55 0.06], ...
         'String', 'Delete markers', ...
         'Value', 0, ...
         'Callback', {@trashMarkers, obj});

        uicontrol(...
         buttonDefaults{:}, ...
         'Position', [0.15 0.50 0.34 0.06], ...
         'String', 'EXIT', ...
         'ForegroundColor','red', ...
         'FontWeight','bold', ...
         'Value', 0, ...
         'Callback', {@deleteRequest, obj}); 


        %add a slider to define the number of points to plot
        obj.slider = uicontrol(...
            'Parent', obj.hFig,...
            'Style','slider',...
            'Units','normalized',...
            'Position',[0.05, 0.7, 0.55, 0.06],...
            'Min',1, 'Max',50,...
            'Value',10,...
            'SliderStep',[0.05 0.2],...
            'Callback', {@sliderUpdate, obj}); 


        %Add a text panel to report the current slider value
        obj.sliderBaseString='Points to plot: ';
        obj.txtBox = uicontrol(...
            'Parent', obj.hFig, ...
            'Units', 'normalized', ...
            'Style','text', ...
            'String',  [obj.sliderBaseString, num2str(get(obj.slider, 'value'))], ...
            'FontName', obj.fontName, ...
            'FontSize', obj.fontSize-1, ...    
            'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
            'ForegroundColor', gbSetting('viewer.textMainColor'), ...
            'HorizontalAlignment', 'left', ...
            'Position', [0.05 0.62 0.5 0.05]);

        %Set up a listener for the keyboard. This will allow the plugin to 
        %respond to key presses in order to build a short-cut system. 
        obj.keyPressListener=event.listener(obj.goggleViewer, 'KeyPress', @obj.parentKeyPress);

        %Respond to scroll, zoom, and pan events but re-drawing the markers on the screen
        obj.scrolledListener=event.listener(obj.goggleViewer, 'Scrolled', @obj.drawMarkers);
        obj.zoomedListener=event.listener(obj.goggleViewer, 'Zoomed', @obj.drawMarkers);
        obj.pannedListener=event.listener(obj.goggleViewer, 'Panned', @obj.drawMarkers);


	   end %close constructor method



        function parentKeyPress(obj, ~,ev)
            keyPress([], ev.KeyPressData, obj);
        end
        function parentClosing(obj, ~, ~)
            deleteRequest([],[], obj,1) %force quit if the parent GUI (goggleViewer) closes
        end


        function clearMarkers(obj)
            if ~isempty(obj.hDisplayedMarkers)
                delete(findobj(obj.goggleViewer.hMainImgAx, 'Tag', 'drawRandomPoints'))
            end
        end
        

        function drawMarkers(obj, ~, ~)
            if ~isempty(obj.markers)
                goggleDebugTimingInfo(2, 'drawRandomPoints.drawMarkers: Beginning',toc,'s')
                obj.clearMarkers;
                goggleDebugTimingInfo(2, 'drawRandomPoints.drawMarkers: Markers cleared',toc,'s')


                %Concatenate all marker x and y coordinates into vectors
                markerX=[obj.markers.xVoxel];
                markerY=[obj.markers.yVoxel];
                
                markerSz=12; %hard-code a default marker size
                
                markerCol=cat(1, obj.markers.color);
                
                hImgAx=obj.goggleViewer.hMainImgAx; 
                prevhold=ishold(hImgAx);
                hold(hImgAx, 'on')

                %% Eliminate markers not in the current x y view
                xView=obj.goggleViewer.mainDisplay.viewXLimOriginalCoords;
                yView=obj.goggleViewer.mainDisplay.viewYLimOriginalCoords;
                
                inViewX=(markerX>=xView(1))&(markerX<=xView(2));
                inViewY=(markerY>=yView(1))&(markerY<=yView(2));
                
                inViewIdx=inViewX&inViewY;
                
                markerX=markerX(inViewIdx);
                markerY=markerY(inViewIdx);
                markerCol=markerCol(inViewIdx, :);

                %% Draw markers
                goggleDebugTimingInfo(2, 'drawRandomPoints.drawMarkers: Beginning drawing',toc,'s')
                obj.hDisplayedMarkers=scatter(hImgAx, markerX , markerY, markerSz, markerCol, 'filled', 'HitTest', 'off', 'Tag', 'drawRandomPoints');
                goggleDebugTimingInfo(2, 'drawRandomPoints.drawMarkers: Drawing complete',toc,'s')

                goggleDebugTimingInfo(2, 'drawRandomPoints.drawMarkers: Complete',toc,'s')

                %% Restore original hold state
                if ~prevhold
                    hold(hImgAx, 'off')
                end

            end
        end



        %% Getters
        function z=get.cursorZVoxels(obj)
            z=obj.goggleViewer.mainDisplay.currentZPlaneOriginalVoxels;
        end



    end %methods


    methods(Static)
       %This is what the plugin is named in the goggleViewer "plugins" menu
       function d=displayString
        d='Draw random markers';
       end % close displayString method
    end %close methods(Static)

end %classdef testPlug<goggleBoxPlugin 


%----------------------------------------------------------------------------------------------
% Callback functions (http://mathworks.com/help/matlab/creating_plots/callback-definition.html)
% These are called when the user presses a button on the keyboard or clicks a UI element in the
% plugin GUI


%The keyPress function is run whenever the user presses a key. It's used to provide
%short-cut key controls for the plugin. Here we use it to exit the plugin if the user presses "ctrl+e"

function keyPress(~, eventdata, obj)
 key=eventdata.Key;
 ctrlMod=ismember('control', eventdata.Modifier);

 switch key
     case 'e'
         if ctrlMod
         	 fprintf('Exiting drawRandomMarkers\n')
             deleteRequest(0,0,obj);
         end
     otherwise
 end

end



%Closes the GUI and and detaches the plugin from goggleViewer. 
function deleteRequest(~, ~, obj, forceQuit)
    
    obj.deregisterPluginAsOpenWithParentViewer; %inherited from goggleBoxPlugin
    deleteRequest@goggleBoxPlugin(obj); %inherited from goggleBoxPlugin
    delete(obj.hFig);
    delete(obj);
    
end


function addMarkers(~, ~, obj)
    zvm=obj.goggleViewer.mainDisplay.zoomedViewManager;

    %We're going to make a marker object to plot. 
    G = goggleMarkerType;

    %Give all markers draw a single, randomly chosen, color
    nChoose=7; %Because there are only 7 unique colours in lines
    L=lines(nChoose);
    R=randperm(nChoose);
    thisColor=L(R(1),:);
    G.color=thisColor;


    %Select a random location in the current field of view
    XL=zvm.parentViewerDisplay.viewXLimOriginalCoords; %X limits of current view
    YL=zvm.parentViewerDisplay.viewYLimOriginalCoords; %Y limits of current view


    %Loop through, adding as many points as requested
    for ii=1:get(obj.slider,'value')
        x=round(rand*range(XL) + XL(1));
        y=round(rand*range(YL) + YL(1));

        z=obj.cursorZVoxels;
        newMarker=goggleMarker(G, x ,y, z); 

        %Append marker 
        if isempty(obj.markers) 
            obj.markers=newMarker; 
        else 
            obj.markers(end+1)=newMarker; 
        end 
    end

    fprintf('Currently %d markers\n',length(obj.markers) ) 
    drawMarkers(obj) 

end


function trashMarkers(~, ~, obj)
    fprintf('Trashing all markers\n')
    obj.clearMarkers;
    obj.markers=[];
end


function sliderUpdate(~, ~, obj)
    slider_value = round(get(obj.slider,'Value'));
    set(obj.txtBox, 'String', [obj.sliderBaseString,num2str(slider_value)])
end
            
