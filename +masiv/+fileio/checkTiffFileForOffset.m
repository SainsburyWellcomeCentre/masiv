function [xoffset, yoffset]=checkTiffFileForOffset(info)

    if isfield(info, 'XPosition')
        xoffset=info.XPosition;
    else
        xoffset=0;
    end
    if isfield(info, 'YPosition')
        yoffset=info.YPosition;
    else
        yoffset=0;
    end
    
end