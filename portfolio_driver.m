muR = 0.1; % average growth rate of risky asset
sigmaR = 5*(1./linspace(0.5,3,100) + 1./linspace(5,0.4,100)); % volatility of risky asset (vector equal in size to time vector)

muS = 0.02; %average growth rate of safe asset
sigmaS = 0.0015; % volatility of safe asset, we will assume this remains the same

investments = linspace(0.8,0.2,100); %proportion of wealth invested in risky asset at any time

t = linspace(0,5,100); % vector of timestamps to calculate discretized brownian
M = 20; % number of simulations to perform

[t,X] = portfolio_simulation(muR,sigmaR,muS,sigmaS,investments,Xzero,t,M); %X matrix will be [M x length(t)]

% visualization
plot(t, X);
xlabel('Time');
ylabel('Portfolio');
title('Portfolio Simulation');
grid on;

% average all trajectories, get final value
finalValue = mean(X(:, end)); % average of final values from all simulations