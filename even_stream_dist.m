function dist = even_stream_dist(xy, verbose)
% function dist = even_stream_dist(xy, verbose)
%
% Return minimum distance to neighboring streamlines for streamlines
% created with the even_stream_xy fuction. This step is part of the Jobar &
% Lefer [1] algorithm to plot evenly spaced streamlines with tapered width.
%
% Arguments:
%   xy = Matrix, evenly-spaced streamlines, as created by the
%       even_stream_xy function, with [x,y] points in rows, and lines
%       separated by NaNs
%   verbose: Scalar, set to True to enable verbose progress messages
%   dist = Vector, minimum distance to neighboring stream lines for all
%       points in xy
%
% References: 
% [1] Jobard, B., & Lefer, W. (1997). Creating Evenly-Spaced Streamlines of
%   Arbitrary Density. In W. Lefer & M. Grave (Eds.), Visualization in
%   Scientific Computing ?97: Proceedings of the Eurographics Workshop in
%   Boulogne-sur-Mer France, April 28--30, 1997 (pp. 43?55). inbook,
%   Vienna: Springer Vienna. http://doi.org/10.1007/978-3-7091-6876-9_5
% %

% handle inputs
if nargin < 2; verbose = false; end
sanity_check(xy, verbose);

% get length (# pts) of each streamline
sep_idx = find(isnan(xy(:,1)));
start_idx = [1; sep_idx+1];
stop_idx = [sep_idx-1; size(xy,1)];
len = stop_idx-start_idx+1;
num_lines = length(len);

% create triangulation for all points
is_pt = ~isnan(xy(:,1));
tri = delaunayTriangulation(xy(is_pt,1), xy(is_pt,2));

% compute dist for points in each line using triangulation
dist = nan(size(xy, 1), 1);
for ii = 1:num_lines
    if verbose
        fprintf('%s: line %d of %d\n', mfilename, ii, num_lines);
    end
    stream_xy = tri.Points(1:len(ii), :);    
    tri.Points(1:len(ii), :) = [];    
    [~, stream_dist] = nearestNeighbor(tri, stream_xy);       
    dist(start_idx(ii):stop_idx(ii)) = stream_dist;
    tri.Points = [tri.Points; stream_xy]; 
end

function sanity_check(xy, verbose)
% function sanity_check(xy, verbose)
% 
% Check for valid inputs, fail with error if any are invalid
% %

validateattributes(xy, {'numeric'}, {'2d', 'ncols', 2}, ...
    mfilename, 'xy');
for ii = 1:size(xy,1)
    if isnan(xy(ii,1))
        assert(isnan(xy(ii,2)), 'NaN in xy is not used as a separator');
    end
end
assert(~any(isnan(xy(1,:))), 'First row in xy should not contain NaN');
assert(~any(isnan(xy(end,:))), 'Last row in xy should not contain NaN');

validateattributes(verbose, {'numeric', 'logical'}, {'binary', 'scalar'}, ...
    mfilename, 'verbose');
