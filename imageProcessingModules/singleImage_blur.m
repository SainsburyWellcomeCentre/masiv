classdef singleImage_blur<singleImage_DisplayProcesor
    properties
        filterSize
        sigma
    end
    methods
        function obj=singleImage_blur(filterSize, sigma)
            
            if nargin<1||isempty(filterSize)
                filterSize=cellfun(@str2num, inputdlg('Filter Size', 'Blur', 1, {'5'}));
            end
            if nargin<2||isempty(sigma)
                sigma=cellfun(@str2num, inputdlg('Gaussian Sigma', 'Blur', 1, {'0.6'}));
            end
            
            if ~isscalar(filterSize)&&isnumeric(filterSize)||isempty(filterSize)&&isscalar(sigma)&&isnumeric(sigma)||isempty(sigma)
                error('Bad filter specification')
            end
            
            obj.filterSize=filterSize;
            obj.sigma=sigma;

        end
        function s=toString(obj)
            s=sprintf('Blur: Size %u Sigma %3.2f', obj.filterSize, obj.sigma);
        end
        
        function I=processImage(obj, I, ~)
            I=imfilter(I, fspecial('gaussian', obj.filterSize, obj.sigma));
        end
    end
    methods (Static)
        function nm=displayName()
            nm='Blur...';
        end
    end
end