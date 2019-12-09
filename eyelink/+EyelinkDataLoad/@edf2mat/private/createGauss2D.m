function gauss2D = createGauss2D(size, sigma)

  [Xm, Ym] = meshgrid(linspace(-.5, .5, size));

  s = sigma / size; % gaussian width as fraction of imageSize
  gauss2D = exp( -(( (Xm.^2) + (Ym.^2) ) ./ (2*s^2)) ); % formula for 2D gaussian

end
