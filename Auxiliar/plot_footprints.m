function [] = plot_footprints(centroid, vertices)
% This function takes the centroid and vertices of a polygon on the surface of a sphere and plots them using geoplot
% The centroid is a 1x2 vector of the latitude and longitude coordinates of the center of mass in degrees
% The vertices is a nx2 matrix of the latitude and longitude coordinates of the polygon's vertices in degrees, where n is the number of sides

% Create a new figure
figure;

% Create a geographic axes
ax = geoaxes;

% Set the base map to 'grayterrain'
geobasemap(ax, 'grayterrain');

% Plot the centroid as a red star
geoplot(ax, centroid(1), centroid(2), 'g*');

% Hold on to plot more things on the same axes
hold on;

% Plot the vertices as blue circles
%geoplot(ax, vertices(:, 1), vertices(:, 2), 'Color',rgb('gold'));

% Plot the polygon as a blue line connecting the vertices and closing at the first vertex
geoplot(ax, [vertices(:, 1); vertices(1, 1)], [vertices(:, 2); vertices(1, 2)], 'Color',rgb('gold'));


ax.Basemap='grayterrain';
% Release the hold
hold off;

end
