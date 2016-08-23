classdef neuriteTracerNode < neuriteTracerMarker
    % neuriteTracerNode
    % neuriteTracerNode inherits neuriteTracerMarker and adds other meta-data
    
    properties
        branchType              %any string such as 'axon', 'dendrite', 'bulklabel', etc 
        data                    %Structure that can contain other data. e.g. a string defining the node type
        isPrematureTermination  %0 or 1. If 1, then this node ought to be a leaf (but this is not enforced right now [TODO?]) [DEPRICATED]
        isBouton                %0 or 1. If 1, then this node is considered to be a putative bouton [DEPRICATED]
    end

    methods
        function obj=neuriteTracerNode(thisType,xVoxel,yVoxel,zVoxel,data,branchType,isPrematureTermination,isBouton)
            % Constructor of masivTreeNode
            obj = obj@neuriteTracerMarker(thisType,xVoxel,yVoxel,zVoxel); %call masivMarker constructor

            %Define default properties
            if nargin<5
                obj.data=struct;
            else
                obj.data=data;
            end

            if nargin<6
                obj.branchType='axon';
            end

            %These are depricated
            if nargin<7
                obj.isPrematureTermination=0;
            end
            if nargin<8
                obj.isBouton=0;
            end

        end %constructor
    end %methods

   
end