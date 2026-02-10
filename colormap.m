clear; clc;

inFile  = 'file path';    
outFile = 'outfile.pdf';

LOW  = 20;   
HIGH = 110;   

cmapName = jet(256);                 

raw = imread(inFile);
if ndims(raw)==3                     
    raw = raw(:,:,2);
end
I = double(raw);                       

I_norm = (I - LOW) / max(HIGH - LOW, eps);  
I_norm = max(min(I_norm,1),0);             

idx   = uint8(round(I_norm*255)) + 1;       
rgbIm = ind2rgb(idx, cmapName);

figure; imshow(rgbIm); axis image off
colormap(cmapName);
cb = colorbar;    
cb.Ticks = [];   

exportgraphics(gcf, outFile, 'ContentType', 'vector');
fprintf('Saved pseudocolor image to  %s\n', outFile);


