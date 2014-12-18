classdef singleImage_subtractBackground<singleImage_DisplayProcessor
    properties
        filterSize
        sigma
        amount
    end
    methods
        function obj=singleImage_subtractBackground(filterSize, sigma, amount)
            
            if nargin<1||isempty(filterSize)
                filterSize=cellfun(@str2num, inputdlg('Filter Size', 'Background Subtraction', 1, {'250'}));
            end
            if nargin<2||isempty(sigma)
                sigma=cellfun(@str2num, inputdlg('Gaussian Sigma', 'Background Subtraction', 1, {'50'}));
            end
            if nargin<2||isempty(amount)
                amount=cellfun(@str2num, inputdlg('Amount to subtract [0-1]', 'Background Subtraction', 1, {'0.8'}));
            end
            
            if ~isscalar(filterSize)&&isnumeric(filterSize)||isempty(filterSize)&&isscalar(sigma)&&isnumeric(sigma)||isempty(sigma)
                error('Bad filter specification')
            end
            
            obj.filterSize=filterSize;
            obj.sigma=sigma;
            obj.amount=amount;
        end
        function s=toString(obj)
            s=sprintf('Blur: Size %u Sigma %3.2f', obj.filterSize, obj.sigma);
        end
        
        function I=processImage(obj, I, ~)
            backgroundImage=imfilter(double(I), fspecial('gaussian', obj.filterSize, obj.sigma));
            backgroundImage=obj.amount*backgroundImage;
            
            I=I-uint16(backgroundImage);
        end
    end
    methods (Static)
        function nm=displayName()
            nm='Subtract Background';
        end
    end
end