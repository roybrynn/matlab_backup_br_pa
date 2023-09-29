
% HAVE TO CLEAR ALL OUTPUT BEFORE USING

% create the computational grid
Nx = 128;           % number of grid points in the x (row) direction
Ny = 128;           % number of grid points in the y (column) direction
dx = 0.1e-3;        % grid point spacing in the x direction [m]
dy = 0.1e-3;        % grid point spacing in the y direction [m]
kgrid = kWaveGrid(Nx, dx, Ny, dy);

% define the properties of the propagation medium
medium.sound_speed = 1500;  % [m/s]
medium.alpha_coeff = 0.75;  % [dB/(MHz^y cm)]
medium.alpha_power = 1.5;
%kgrid.makeTime(medium.sound_speed);

% create initial pressure distribution using makeDisc (MAYBE CHANGE THESE
% AROUND)
disc_magnitude = 2; % [Pa]
disc_x_pos = 50;    % [grid points]
disc_y_pos = 70;    % [grid points]
disc_radius = 2;    % [grid points]
disc_1 = disc_magnitude * makeDisc(Nx, Ny, disc_x_pos, disc_y_pos, disc_radius);

disc_magnitude = 0; % [Pa]
disc_x_pos = 40;    % [grid points]
disc_y_pos = 25;    % [grid points]
disc_radius = 1.5;    % [grid points]
disc_2 = disc_magnitude * makeDisc(Nx, Ny, disc_x_pos, disc_y_pos, disc_radius);

disc_magnitude = 0; % [Pa]
disc_x_pos = 20;    % [grid points]
disc_y_pos = 35;    % [grid points]
disc_radius = 3;    % [grid points]
disc_3 = disc_magnitude * makeDisc(Nx, Ny, disc_x_pos, disc_y_pos, disc_radius);

%f(x,y)
source.p0 = disc_1 + disc_2 + disc_3;

% define a BINARY sensor mask
sensor_x_pos = Nx/2;        % [grid points]
sensor_y_pos = Ny/2;        % [grid points]
sensor_radius = Nx/2 - 22;  % [grid points]
sensor_arc_angle = 3*pi/2;  % [90 degree sensor gap]
sensor.mask = makeCircle(Nx, Ny, sensor_x_pos, sensor_y_pos, sensor_radius, sensor_arc_angle);

hold on
figure;
imagesc(sensor.mask + source.p0, [-1, 1]);
colormap(getColorMap);
ylabel('Sensor Position');
xlabel('Time Step');
colorbar;
hold off

% THE FOLLOWING CODE COMES FROM:
%http://www.medphys.ucl.ac.uk/research/mle/pdf_files/J_2010_Treeby_JBO_k-Wave_MATLAB_toolbox.pdf

% create the time array
kgrid.t_array = makeTime(kgrid, medium.sound_speed);
% run the forward simulation

sensor_data = kspaceFirstOrder2D(kgrid,medium, source, sensor);

% reorder the simulation data < (ONLY WORKS ON 2D DATA - fixes the gaps)
sensor_data = reorderSensorData(kgrid, sensor, sensor_data); %this doesnt seem to solve the problem

% ........................................................ %
% NEW CODE BELOW %
% ........................................................ %


% load an image for the initial pressure distribution
p0_image = loadImage('initial_pressure_with_sensors.png');

% make it binary
p0_image = double(p0_image > 0);

% smooth the initial pressure distribution
p0 = smooth(p0_image, true);

% assign to the source structure
source.p0 = p0;

% use the sensor points as sources in time reversal
source.p_mask = sensor.mask;

% time reverse and assign the data
source.p = fliplr(sensor_data);	

% enforce, rather than add, the time-reversed pressure values
source.p_mode = 'dirichlet';    

% set the simulation to record the final image (at t = 0)
sensor.record = {'p_final'};

% run the time reversal reconstruction
source.p0 = 0;
p0_estimate = kspaceFirstOrder2D(kgrid, medium, source, sensor);

% apply a positivity condition
p0_estimate.p_final = p0_estimate.p_final .* (p0_estimate.p_final > 0);

% set the initial pressure to be the latest estimate of p0
source.p0 = p0_estimate.p_final;

% set the simulation to record the time series
sensor = rmfield(sensor, 'record');

% calculate the time series using the latest estimate of p0
source.p0 = 0;
sensor_data2 = kspaceFirstOrder2D(kgrid, medium, source, sensor);

% calculate the error in the estimated time series
data_difference = sensor_data - sensor_data2;

% assign the data_difference as a time-reversal source
source.p_mask = sensor.mask;
source.p = fliplr(data_difference);
source = rmfield(source,'p0');
source.p_mode = 'dirichlet';   

% set the simulation to record the final image (at t = 0)
sensor.record = {'p_final'};

% run the time reversal reconstruction
p0_update = kspaceFirstOrder2D(kgrid, medium, source, sensor);

% add the update to the latest image
p0_estimate.p_final = p0_estimate.p_final + p0_update.p_final;

% apply a positivity condition
p0_estimate.p_final = p0_estimate.p_final .* (p0_estimate.p_final > 0);

% plot the MULTIPLE X simulated RECON sensor data
hold on
figure;
imagesc(p0_estimate.p_final + sensor.mask, [-1, 1]);
colormap(getColorMap);
ylabel('x');
xlabel('y');
colorbar;
hold off
clear all output;