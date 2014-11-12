function I=deComb(I)

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