% Reads acceleration and rotation data from a file, then plots the rocket's
% trajectory, position, and other values; it takes in IMU acceleration in
% gees and angular velocity in degrees per second, both relative to the
% body of the rocket, and outputs and plots flight data
clc; clear all; close all;

%% Import

disp("Starting Importing");

sim_data = importdata("simFlight6_g.mat"); % Sim data file name in quotes

options = odeset('RelTol',1E-12,'AbsTol',1e-12);

movmean_val = 31; % width of moving mean for basic data smoothing
g = 9.81; % force of gravity
rot_init = [45, 70, 0]; % [Yaw, Pitch, Roll] -> relative to 0,0,0
vel_init_body = [30; 0; 0]; % Initial velocity, in m/s, IN NED

% Imports IMU data from sim (this may need editing depending on the file)
imu_data = sim_data{12}.Values; 

% Get actual position from sim data 
% (this may need editing depending on the file)
real_pos_N = (sim_data{7}.Values.signal1.data);
real_pos_E = (sim_data{7}.Values.signal2.data);
real_pos_D = (sim_data{7}.Values.signal3.data);

DCM0 = eulerANGLEStoDCM([3,2,1], deg2rad(rot_init));
vel_init = DCM0.'*vel_init_body;
A = permute(imu_data.IMU_accel_body.data, [2 3 1])';
A = A * 9.81;
t_data = imu_data.IMU_accel_body.time;
ang_vel_data = permute(imu_data.IMU_rot_body.data, [2 3 1])';

% Split IMU acceleration data
Ax_in = A(:,1);
Ay_in = A(:,2);
Az_in = A(:,3);

% Get angular velocity AND CONVERT TO RADIANS
Rx = deg2rad(ang_vel_data(:,1));
Ry = deg2rad(ang_vel_data(:,2));
Rz = deg2rad(ang_vel_data(:,3));

disp("Finished Importing");

%% Unsmoothed Computations

disp("Starting Unsmoothed Processing")

% Convert angular velocity into an nx3 matrix
w_data = [Rx, Ry, Rz];

% Run vector rotation correction using the input vectors, angular
% velocities, time data, and base rotation [yaw, pitch, roll]

[a_i, BN_out, EP_hist] = vecRotCorrect(A, w_data, t_data, rot_init);

% Add gravity to the z direction
a_i(:,3) = a_i(:,3) + 9.81;

% Calculate pitch, roll, and yaw from the output of the vector correction
pitch = permute(real(-asin(BN_out(1,3,:))), [3, 1, 2])';
roll = permute(real(atan2(BN_out(2,3,:), BN_out(3,3,:))), [3, 1, 2])';
yaw = permute(real(atan2(BN_out(1,2,:), BN_out(1,1,:))), [3, 1, 2])';

% Use trapezoidal Riemann sums to calculate velocity from acceleration
vx_i = cumtrapz(t_data, a_i(:,1)) + vel_init(1);
vy_i = cumtrapz(t_data, a_i(:,2)) + vel_init(2);
vz_i = cumtrapz(t_data, a_i(:,3)) + vel_init(3);

% Use trapezoidal Riemann sums to calulate position from velocity
dx_i = cumtrapz(t_data, vx_i);
dy_i = cumtrapz(t_data, vy_i);
dz_i = cumtrapz(t_data, vz_i);

% Calculate horizontal distance from launch using Pythagorean theorem
horiz_dist = (dx_i .^ 2 + dy_i .^ 2) .^ 0.5;

% Calculate inclination
inclination = atan(sqrt(tan(roll) .^ 2 + tan(pitch) .^ 2));

disp("Finished Unsmoothed Processing");

%% smoothed Computations

disp("Starting Smoothed Processing");

% Calculate smoothed angular velocity data using a moving mean
Rxx = movmean(Rx, movmean_val);
Ryy = movmean(Ry, movmean_val);
Rzz = movmean(Rz, movmean_val);

% Convert smoothed angular velocity into an nx3 matrix
w_data_smoothed = [Rxx, Ryy, Rzz];

% Run vector rotation correction using the input vectors, angular
% velocities, time data, and base rotation [yaw, pitch, roll]
[fa_i, fBN_out, fEP_hist] = vecRotCorrect(A, w_data_smoothed, t_data, rot_init);

% Add gravity to the z direction
fa_i(:,3) = fa_i(:,3) + 9.81;

% Calculate pitch, roll, and yaw from the output of the vector correction
fpitch = permute(real(-asin(fBN_out(1,3,:))), [3, 1, 2])';
froll = permute(real(atan2(fBN_out(2,3,:), fBN_out(3,3,:))), [3, 1, 2])';
fyaw = permute(real(atan2(fBN_out(1,2,:), fBN_out(1,1,:))), [3, 1, 2])';

% Use trapezoidal Riemann sums to calculate velocity from acceleration
fvx_i = cumtrapz(t_data, fa_i(:,1)) + vel_init(1);
fvy_i = cumtrapz(t_data, fa_i(:,2)) + vel_init(2);
fvz_i = cumtrapz(t_data, fa_i(:,3)) + vel_init(3);

% Use trapezoidal Riemann sums to calulate position from velocity
fdx_i = cumtrapz(t_data, fvx_i);
fdy_i = cumtrapz(t_data, fvy_i);
fdz_i = cumtrapz(t_data, fvz_i);

% Calculate horizontal distance from launch using Pythagorean theorem
fhoriz_dist = (fdx_i .^ 2 + fdy_i .^ 2) .^ 0.5;

% Calculate inclination
finclination = atan(sqrt(tan(froll) .^ 2 + tan(fpitch) .^ 2));

disp("Finished Smoothed Processing");

%% Plotting

fig_ct = 1;

% Plot rocket position in 3D
figure(fig_ct);
fig_ct = fig_ct + 1;
clf;
plot3(dx_i, dy_i, -dz_i);
hold on;
grid on;
plot3(fdx_i, fdy_i, -fdz_i);
% legend('unsmoothed', 'smoothed');
axis equal;
xlabel('X (m)');
ylabel('Y (m)');
zlabel('Altitude (m)');

% Plot smoothed and unsmoothed rocket position in 3D
figure(fig_ct);
fig_ct = fig_ct + 1;
clf;
plot3(dx_i, dy_i, -dz_i);
hold on;
grid on;
plot3(real_pos_N, real_pos_N, -real_pos_D);
legend('calculated', 'actual');
axis equal;
xlabel('X (m)');
ylabel('Y (m)');
zlabel('Altitude (m)');

% Clear figure for next plots
figure(fig_ct);
fig_ct = fig_ct + 1;
clf;

% Plot pitch
subplot(3, 3, 1);
hold on;
plot(t_data, rad2deg(pitch));
plot(t_data, rad2deg(fpitch));
legend('unsmoothed', 'smoothed');
title('Pitch');
hold off;

% Plot roll
subplot(3, 3, 2);
hold on;
plot(t_data, rad2deg(roll));
plot(t_data, rad2deg(froll));
legend('unsmoothed', 'smoothed');
title('Roll');
hold off;

% Plot yaw
subplot(3, 3, 3);
hold on;
plot(t_data, rad2deg(yaw));
plot(t_data, rad2deg(fyaw));
legend('unsmoothed', 'smoothed');
title('Yaw');
hold off;

% Plot altitude (using -z due to NED coordinates)
subplot(3, 3, 4);
hold on;
plot(t_data, -dz_i);
plot(t_data, -fdz_i);
legend('unsmoothed', 'smoothed');
title('Altitude');
hold off;

% Plot horizontal distance traveled
subplot(3, 3, 5);
hold on;
plot(dx_i, dy_i);
plot(fdx_i, fdy_i);
legend('unsmoothed', 'smoothed');
title('Horizontal Position');
hold off;

% Plot inclination
subplot(3, 3, 6);
hold on;
plot(t_data, 90 - rad2deg(inclination));
plot(t_data, 90 - rad2deg(finclination));
legend('unsmoothed', 'smoothed');
title('Inclination from Vertical');

% Plot raw acceleration data
subplot(3, 3, 7);
hold on;
plot(t_data, A);
% plot(t_data, A_mag);
legend('x', 'y', 'z');
title('Raw Acceleration');
hold off;

% Plot unsmoothed corrected acceleration data in NED coords
subplot(3, 3, 8);
hold on;
plot(t_data, a_i);
legend('x', 'y', 'z');
title('Corrected Acceleration (NED)');
hold off;

% Plot smoothed corrected acceleration data in NED coords
subplot(3, 3, 9);
hold on;
plot(t_data, fa_i);
legend('x', 'y', 'z');
title('Corrected Smoothed Acceleration (NED)');
hold off;

% Plot roll in 3D
figure(fig_ct);
fig_ct = fig_ct + 1;
clf;
plot3(cos(roll), sin(roll), -dz_i);
title("Roll");
hold on;
grid on;
% axis equal;
plot3(cos(froll), sin(froll), -fdz_i);
legend('unsmoothed', 'smoothed');
hold off;

% Output max altitude, max horizontal distance, and max inclination
fprintf("\n-=-=-=-\n");
fprintf("Maximum altitude: %.2f m (smoothed: %.2f m)\n", max(-dz_i), max(-fdz_i));
fprintf("Maximum distance from launchpad: %.2f m (smoothed: %.2f m)\n", max(horiz_dist), max(fhoriz_dist));
fprintf("Maximum inclination: %.2f deg (smoothed: %.2f deg)\n", max(90 - rad2deg(inclination)), max(90 - rad2deg(finclination)));
fprintf("-=-=-=-\n");

%% Old stuff

%figure(1);
%plot(t_data, (Ax.^2 + Ay.^2 + Az.^2).^.5);
% 
% rotAngles = deg2rad([0,90,0]);
% DCM0 = eulerANGLEStoDCM([3,2,1],rotAngles);
% EP0 =  DCMtoEP(DCM0);
% [t_data,EP_hist] = ode45(@(t, x) KDE_qauternions(t, x, t_data,w_data),t_data,EP0,options);
% 
% pitch_unsmoothed = zeros(length(t_data),1);
% roll_unsmoothed = zeros(length(t_data),1);
% yaw_unsmoothed = zeros(length(t_data),1);
% acc_inertial = zeros(length(t_data),3);
% for i = 1:length(t_data)
%     BN = EPtoDCM(EP_hist(i,:));
% 
%     acc_inertial(i,:) = (BN.'*[Ax(i);Ay(i);Az(i)]).'+[0;0;9.81].';
% 
%     pitch_unsmoothed(i) = real(-asin(BN(1,3)));
%     roll_unsmoothed(i) = real(atan2(BN(2,3),BN(3,3)));
%     yaw_unsmoothed(i) = real(atan2(BN(1,2),BN(1,1)));
% end
% 
% 
% 
% figure_counter = 1
% figure(1);
% clf
% subplot(2, 3, figure_counter);
% figure_counter = figure_counter + 1;
% % clf;
% hold on;
% plot(t_data,acc_inertial);
% %plot(t_data, [Ax, Ay, Az]);
% %legend('x','y','z','Ax','Ay','Az');
% legend('x','y','z')
% hold off;
% 
% subplot(2, 3, figure_counter);
% figure_counter = figure_counter + 1;
% % clf;
% xi = cumtrapz(t_data, cumtrapz(t_data, acc_inertial(:,1)));
% yi = cumtrapz(t_data, cumtrapz(t_data, acc_inertial(:,2)));
% zi = cumtrapz(t_data, cumtrapz(t_data, acc_inertial(:,3)));
% plot3(xi, yi, zi);
% axis off;
% % xlim([-250,250]);
% % ylim([-250,250]);
% % legend('x','y','z');
% 
% figure(1);
% subplot(2, 3, figure_counter);
% figure_counter = figure_counter + 1;
% % clf;
% plot(t_data, [Ax, Ay, Az]);
% legend('Ax','Ay','Az');
% 
% subplot(2, 3, figure_counter);
% figure_counter = figure_counter + 1;
% % clf;
% plot(Ax_all);
% 
% subplot(2, 3, figure_counter);
% figure_counter = figure_counter + 1;
% % clf;
% plot(pressure_all);
% 
% subplot(2, 3, figure_counter);
% figure_counter = figure_counter + 1;
% plot(t_data, cumtrapz(t_data, cumtrapz(t_data, (Ax + 9.81))));
% 
% 
% w_data = [Rxx, Ryy, Rzz];
% [t_data,EP_hist] = ode45(@(t, x) KDE_qauternions(t, x, t_data,w_data),t_data,EP0,options);
% 
% pitch_smoothed = zeros(length(t_data),1);
% roll_smoothed = zeros(length(t_data),1);
% yaw_smoothed = zeros(length(t_data),1);
% for i = 1:length(t_data)
%     BN = EPtoDCM(EP_hist(i,:));
% 
%     pitch_smoothed(i) = real(-asin(BN(1,3)));
%     roll_smoothed(i) = real(atan2(BN(2,3),BN(3,3)));
%     yaw_smoothed(i) = real(atan2(BN(1,2),BN(1,1)));
% end
% 
% %% Plot angular velocity
% figure(5);
% clf;
% plot(t_data, w_data);
% legend('Rx','Ry','Rz');
% 
% %% Plot data
% figure(1)
% clf;
% 
% subplot(3, 1, 1);
% hold on
% plot(t_data,rad2deg(pitch_smoothed))
% plot(t_data,rad2deg(roll_smoothed))
% plot(t_data,rad2deg(yaw_smoothed))
% legend('pitch','roll','yaw');
% title('smoothed Rotation')
% hold off;
% 
% subplot(3, 1, 2);
% hold on;
% plot(t_data, rad2deg(pitch_unsmoothed))
% plot(t_data, rad2deg(roll_unsmoothed))
% plot(t_data,rad2deg(yaw_unsmoothed))
% title('Unsmoothed Rotation')
% legend('pitch', 'roll', 'yaw');
% hold off;
% 
% subplot(3, 1, 3);
% hold on;
% plot(t_data, a_mag);
% legend('Acceleration');
% title('Acceleration')
% hold off;
% 
% %% Plot smoothed vs unsmoothed
% figure(2)
% clf
% hold on
% plot(t_data, rad2deg(pitch_smoothed));
% plot(t_data, rad2deg(pitch_unsmoothed));
% title('smoothed and Unsmoothed Pitch')
% legend('smoothed', 'unsmoothed')
% 
% %% Check time differences
% figure(3)
% t_diffs = zeros(length(t_data) - 1, 1);
% for i=1:length(t_data) - 1
%     t_delta = t_data(i + 1) - t_data(i);
%     if round(t_delta, 3) ~= .010
%         fprintf("Change at %f: delta of %f\n", t_data(i), t_delta);
%     end
%     t_diffs(i) = t_data(i + 1) - t_data(i);
% end
% plot(t_diffs);
% 
% %% FFT time
% T = t_data(2);
% freq = 1 / T
% L = length(t_data);
% f = freq * (0:(L/2)) / L;
% 
% fft_in = fft(pitch_smoothed);
% P2 = abs(fft_in/L);
% P1_smoothed = P2(1:L/2+1);
% P1_smoothed(2:end-1) = 2*P1_smoothed(2:end-1);
% 
% fft_in = fft(pitch_unsmoothed);
% P2 = abs(fft_in/L);
% P1_unsmoothed = P2(1:L/2+1);
% P1_unsmoothed(2:end-1) = 2*P1_unsmoothed(2:end-1);
% 
% figure(4)
% clf
% hold on;
% plot(f, P1_smoothed,'o--')
% plot(f, P1_unsmoothed)
% title("Single-Sided Amplitude Spectrum of Data")
% legend('smoothed', 'unsmoothed')
% xlabel("f (Hz)")
% ylabel("|P1(f)|")
% hold off;
