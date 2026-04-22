% Parameters
S0 = 100;
v0 = 0.04;
r = 0.02;

kappa = 2;
theta = 0.04;
sigma = 0.3;
rho = -0.7;

[t,S,V] = trajectory_simulation(S0,v0,r,kappa,theta,sigma,rho); %X matrix will be [M x length(t)]

% visualization
plot(t, S);
xlabel('Time');
ylabel('Trajectory');
title('Trajectory Simulation');
grid on;

% average all trajectories, get final value
% finalValue = mean(X(:, end)); % average of final values from all simulations