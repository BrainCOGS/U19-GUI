function palette = designPalette(nRows, nCols)
  
  %% Default arguments
  if nargin < 1 || isempty(nRows)
    nRows         = 256;
  end
  if nargin < 2 || isempty(nCols)
    nCols         = 64;
  end
  
  %% Set up principal colors here
  colorL          = [ 255   0   0; 255 255   0 ;   0 255   0 ;   0 255 255 ;   0   0 255 ; 255   0 255 ] / 255;
  colorR          = [   0   0   0; 158  95   0 ;   0 100   0 ;   0 179 255 ;   0   0 100 ; 255 150 220 ] / 255;
                                           
  
  %% Interpolate in HSV space
  colors          = [reshape(colorL,[],1,3), reshape(colorR,[],1,3)];
  palette         = imresize(rgb2hsv(colors), [nRows,nCols], 'bilinear');
  palette         = hsv2rgb(min(1,max(0, imgaussfilt(palette,10) )));

  %% If no output is requested, show the designed palette on screen
  if nargout < 1
    figure; 
    
    subplot(1,2,1); 
    image(colors); 
    axis image ij; 
    
    subplot(1,2,2); 
    image(palette); 
    axis image ij;
  end
  
end
