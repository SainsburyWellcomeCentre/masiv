classdef neuriteTracerNode < neuriteTracerMarker
    % neuriteTracerNode
    % neuriteTracerNode inherits neuriteTracerMarker and adds other meta-data
    
    properties
        branchType              %any string such as 'axon', 'dendrite', 'bulklabel', etc 
        isPrematureTermination  %0 or 1. If 1, then this node ought to be a leaf (but this is not enforced right now [TODO?])
        isBouton                %0 or 1. If 1, then this node is considered to be a putative bouton
        data                    %Structure that can contain other data. Reserved and not used right now 2015/10/13

    end

    methods
        function obj=neuriteTracerNode(thisType,xVoxel,yVoxel,zVoxel,branchType,isPrematureTermination,isBouton,data)
            % Constructor of masivTreeNode
            obj = obj@neuriteTracerMarker(thisType,xVoxel,yVoxel,zVoxel); %call masivMarker constructor

            %Define default properties
            if nargin<5
                obj.branchType='axon';
            end
            if nargin<6
                obj.isPrematureTermination=0;
            end
            if nargin<7
                obj.isBouton=0;
            end
            if nargin<8
                data=struct;
            end

        end %constructor
    end %methods

   
end