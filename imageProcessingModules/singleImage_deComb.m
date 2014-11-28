classdef singleImage_deComb<singleImage_DisplayProcesor
   
    methods
        function obj=singleImage_deComb
            % Don't really need a constructor
            obj=obj@singleImage_DisplayProcesor;
        end
        function s=toString(~)
            s='De-Comb';
        end
        function I=processImage(~, I, zoomedViewObject)
            if mod(zoomedViewObject.downSampling, 2) %only do it if odd downsampling factor
                if mod(size(I,2), 2)    %ensure an even number of columns
                    target=I(:,1:2:end-1);
                else
                    target=I(:,1:2:end);
                end
                
                source=I(:,2:2:end);
                
                [~, Greg] = dftregistration(fft2(target),fft2(source),10);
                
                sourceShifted=(abs(ifft2(Greg)));
                
                I(:, 2:2:end)=sourceShifted;
            end
        end        
    end
    
    methods (Static)
        function nm=displayName()
            nm='De-Comb';
        end
    end
end