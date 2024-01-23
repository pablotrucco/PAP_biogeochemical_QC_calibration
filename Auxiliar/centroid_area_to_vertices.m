function [vertices] = centroid_area_to_vertices(centroid, area)
% This function calculates the coordinates of the vertices of a polygon approximating a circle
% given the centroid and area of the circle.
% The centroid is a 1x2 vector of the latitude and longitude coordinates of the center of mass in degrees.
% The area is a scalar value of the circle's area in square kilometers.
% The vertices is a nx2 matrix of the latitude and longitude coordinates of the polygon's vertices in degrees,
% where n is the number of vertices.

% Convert the centroid from degrees to radians
centroid_rad = deg2rad(centroid);

% Calculate the radius of the circle from the area
radius_km = sqrt(area / pi);

% Number of sides (vertices) for the polygon approximation (you can adjust this for more accuracy)
n = 100;

% Initialize the vertices matrix
vertices = zeros(n, 2);

% Calculate the angle between each vertex in radians
angle_step = 2 * pi / n;

% Loop through each vertex and calculate its coordinates
for i = 1:n
    % The angle of the current vertex
    theta = angle_step * (i - 1);
    
    % Calculate the latitude and longitude coordinates of the current vertex in radians
    lat_rad = centroid_rad(1) + (radius_km / 6371) * cos(theta);
    lon_rad = centroid_rad(2) + (radius_km / 6371) * sin(theta) / cos(lat_rad);
    
    % Convert the latitude and longitude coordinates back to degrees and store in the vertices matrix
    vertices(i, :) = [rad2deg(lat_rad), rad2deg(lon_rad)];
end

end
