n = 1000; % number of points 
mu = 0.1; % average growth rate of asset
sigma = 0.0 * (1./linspace(0.5,3,n) + 1./linspace(5,0.4,n)); % volatility of growth rate (vector equal in size to time vector)
Xzero = 1; % starting value for X, in this case our initial wealth
t = linspace(0,1,n); % vector of timestamps to calculate discretized brownian
M = 100; % number of simulations to perform

[t,X] = trajectory_simulation(mu,sigma,Xzero,t,M); %X matrix will be [M x length(t)]

% visualization
plot(t, (X)');
xlabel('Time');
ylabel('Trajectory');
title('Trajectory Simulation');
grid on;

% average all trajectories, get final value
finalValue = mean(X(:, end)); % average of final values from all simulations