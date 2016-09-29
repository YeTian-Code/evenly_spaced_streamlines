function [xs, ys, ds, ls] = ...
    even_stream2(xx, yy, uu, vv, d_sep, d_test, step_size)
%
% Compute evenly-spaced streamlines with Jobar & Lefer algorithm (ref 1).
% Results can be used to plot using ____, ____, ...
%
% Arguments:
%
%   xx, yy:
%
%   uu, vv: 
%
%   d_sep:
%
%   d_test:
%
%   step_size: fraction of a cell (?)
%
%   xs, ys: Vectors, x-coord and y-coord for stream line points, individual
%       lines are separated by NaNs
%
%   ds: Vector, distance to nearest neighboring streamline for stream line
%       points, individual lines are separated by NaNs
%
%   ls: Vector, length along streamline for stream line points, individual
%       lines are separated by NaNs
%  
% References: 
% [1] Jobard, B., & Lefer, W. (1997). Creating Evenly-Spaced Streamlines of
%   Arbitrary Density. In W. Lefer & M. Grave (Eds.), Visualization in
%   Scientific Computing ?97: Proceedings of the Eurographics Workshop in
%   Boulogne-sur-Mer France, April 28--30, 1997 (pp. 43?55). inbook,
%   Vienna: Springer Vienna. http://doi.org/10.1007/978-3-7091-6876-9_5
% %

%% initialize

% gather some basic coordinate info
x_min = min(xx(:));
x_max = max(xx(:));
x_rng = x_max-x_min; 
y_min = min(yy(:));
y_max = max(yy(:));
y_rng = y_max-y_min;

% get seed point at random (non-NaN) point
% TODO: simplify by using a given grid point
u0 = NaN;
v0 = NaN;
while isnan(u0) || isnan(v0)
    x0 = x_min+rand(1)*x_rng;
    y0 = y_min+rand(1)*y_rng;
    u0 = interp2(xx, yy, uu, x0, y0);
    v0 = interp2(xx, yy, vv, x0, y0);
end
seed_xy = [x0, y0];

% add first streamline to triangulation and length list
[stream_xy, ~] = get_streamline(xx, yy, uu, vv, seed_xy, step_size);
stream_tri = delaunayTriangulation(stream_xy);
stream_len = size(stream_xy,1);

% create seed point candidate queue 
seed_queue{1} = get_seed_candidates(stream_xy, d_sep);

%% main loop

while ~isempty(seed_queue)
    
    % pop seed candidates from queue
    seed_xy = seed_queue{1}; 
    seed_queue(1) = []; 
    
    % check each seed candidate in random order
    for ii = randperm(length(seed_xy))
        
        % skip if candidate istoo close to any streamline point
        [~, d_min] = nearestNeighbor(stream_tri, seed_xy(ii,:));
        if d_min < d_sep
            continue
        end
                
        % create new streamline, skip if empty
        [stream_xy, seed_idx] = get_streamline(xx, yy, uu, vv, seed_xy(ii,:), step_size);
        if size(stream_xy,1) < 2
            continue
        end        
 
        % trim new streamline
        % TODO: try computing distances at once, then triming rather than looping
        for jj = seed_idx:size(stream_xy,1)
            [~, d_min] = nearestNeighbor(stream_tri, stream_xy(jj,:));
            if d_min < d_test
                break
            end
        end
        for kk = seed_idx:-1:1
            [~, d_min] = nearestNeighbor(stream_tri, stream_xy(kk,:));
            if d_min < d_test
                break
            end
        end
        stream_xy = stream_xy(kk:jj, :);
        
        % add streamline to triangulation and line length list
        stream_tri.Points = [stream_tri.Points; stream_xy]; % TODO: use length to append?
        stream_len(end+1) = size(stream_xy, 1); %#ok!
         
        % add seed candidate points to queue
        seed_queue{end+1}  = get_seed_candidates(stream_xy, d_sep); %#ok!

    end
end

%% prepare outputs

% extract line points and compute distance and arc length
num_lines = length(stream_len);
stream_data = cell(num_lines, 1);
for ii = 1:num_lines
    stream_xy = stream_tri.Points(1:stream_len(ii), :);    
    stream_tri.Points(1:stream_len(ii), :) = [];    
    [~, stream_d] = nearestNeighbor(stream_tri, stream_xy);
    stream_l = [0; cumsum(sqrt(sum(diff(stream_xy).^2, 2)))];
    stream_data{ii} = [stream_xy, stream_d, stream_l; nan(1,4)];    
    stream_tri.Points = [stream_tri.Points; stream_xy]; % TODO: use length to append?
end

% concatenate and split stream data into NaN-separated vectors
stream_data = cell2mat(stream_data);
xs = stream_data(:,1);
ys = stream_data(:,2);
ds = stream_data(:,3);
ls = stream_data(:,4);


function seed_xy = get_seed_candidates(xy, buf_dist)
%
% Compute the location of stream line seed point candidates that lie at a
% distance 'buf_dist' along a normal vector at each point in 'xy' 
%
% Arguments:
%   xy: Matrix, [x,y] coordinates of points along a streamline in rows
%   buf_dist: Scalar, buffer distance between xy and seed point candidates
%   seed_xy, y_seed: Vectors, canditate seed points
% %

% get unit normal vectors at segment midpoints
tangent = diff(xy);
normal = [tangent(:,2), -tangent(:,1)];
normal = bsxfun(@rdivide, normal, sqrt(sum(normal.*normal, 2)));
midpoint = xy(1:end-1, :)+0.5*tangent;

% get candidates offset buf_dist in positive and negative normal direction
seed_xy = [midpoint + buf_dist*normal; midpoint - buf_dist*normal];

function [stream_xy, seed_idx] = get_streamline(xx, yy, uu, vv, seed_xy, step_size)
%
% Compute streamline in both directions starting at seed point
%
% Arguments: 
%   xx, yy:
%   uu, vv:
%   seed_xy: Vector, [x, y] coordinates of seed point
%   stream_xy : Matrix, stream line x- and y-coordinates in rows, returns [] if
%       stream line has zero length
%   seed_idx: Scalar, index of seed point in output streamline
% %

fwd = stream2(xx, yy, uu, vv, seed_xy(1), seed_xy(2), step_size);
xy_fwd = fwd{1}(~any(isnan(fwd{1}), 2), :); % drop NaN rows
has_fwd = size(xy_fwd,1) > 1;

rev = stream2(xx, yy, -uu, -vv, seed_xy(1), seed_xy(2), step_size);
xy_rev = rev{1}(~any(isnan(rev{1}), 2), :); % drop NaN rows
has_rev = size(xy_rev,1) > 1;

if has_fwd && has_rev
    stream_xy = [xy_rev(end:-1:2, :); xy_fwd];
    seed_idx = size(xy_rev,1);
elseif has_rev
    stream_xy = xy_rev;
    seed_idx = 1;
elseif has_fwd
    stream_xy = xy_fwd;
    seed_idx = 1;
else
    stream_xy = [];
    seed_idx = [];
end