function [px, py] = buildRectanglePoints(varargin)

  p = inputParser;
  p.addParameter('theta', 0, @isscalar);
  p.addParameter('depth', 1, @(x) isscalar(x) && x >= 0);
  p.addParameter('width', 1, @(x) isscalar(x) && x >= 0);
  p.parse(varargin{:});

  theta = p.Results.theta;
  depth = p.Results.depth;
  width = p.Results.width;
  
  x0 = 0;
  y0 = 0;

  rot = [cos(theta), -sin(theta); sin(theta), cos(theta)];
  c = rot * [-width/2 width/2 width/2 -width/2; ...
    -depth/2 -depth/2 depth/2 depth/2 ];

  px = c(1, :);
  py = c(2, :);

end