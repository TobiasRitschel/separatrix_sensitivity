%% Fitzhugh-Nagumo model
% Clear command window
clc;

% Clear variables, etc.
clear all;

% Close all windows
close all;

% Restore default path
restoredefaultpath;

% Reset settings
reset(groot);

%% Initialize
% Parameter values
a   =  0.7;
b   =  2.0;
tau = 12.5;
e   =  0.35;

% Collect parameters
p = e;
q = [a; b; tau];

% Axis limits
xmin = [-2, -1.5];
xmax = [2, 2];

%% Steady states
% Options
fsolve_opts = optimoptions('fsolve', ...
    'FunctionTolerance', 1e-12, ...
    'OptimalityTolerance', 1e-12);

% Initial guess
x0 = [-1, 0, 1; 0, 0, 0];

for i = 1:size(x0, 2)
    % Solve for the steady state
    xs(:, i) = fsolve(@fitzhughnagumo, x0(:, i), fsolve_opts, ...
        p, q); %#ok

    % Evaluate Jacobian
    [~, J(:, :, i)] = fitzhughnagumo(xs(:, i), p, q); %#ok

    % Eigenvalues
    [V, D] = eig(J(:, :, i));

    % Store results
    lambda(:,    i) = diag(D); %#ok
    v     (:, :, i) = V; %#ok
end

%% Visualize vector field
% Points
x1 = linspace(xmin(1), xmax(1), 40);
x2 = linspace(xmin(2), xmax(2), 40);

% Mesh grid
[X1, X2] = meshgrid(x1, x2);

for i = 1:numel(x1)
    for j = 1:numel(x2)
        % Evaluate right-hand side function
        f = fitzhughnagumo([X1(i, j); X2(i, j)], p, q);
        
        % Store results
        F1(i, j) = f(1); %#ok
        F2(i, j) = f(2); %#ok
    end
end

% Add vector field to plot
quiver(X1, X2, F1, F2, 'HandleVisibility', 'off');

%% Simulate
% Options
ode15s_opts = odeset('AbsTol', 1e-12, 'RelTol', 1e-12);

% Time span (chosen specifically for computing the separatrix)
tspan = linspace(0, 164.875, 1e3);

% Points
x01 = linspace(xmin(1), xmax(1), 2e1);
x02 = linspace(xmin(2), xmax(2), 2e1);

% Add to existing plot
hold on;

for i = 1:numel(x01)
    for j = 1:numel(x02)
        % Initial state
        x0 = [x01(i); x02(j)];

        % Simulate
        [t, x] = ode15s(@(t, x) fitzhughnagumo(x, p, q), tspan, x0, ode15s_opts);

        % Visualize
        plot(x(:, 1), x(:, 2), 'HandleVisibility', 'off', 'Color', [0, 0, 0, 0.5]);
    end
end

%% Sensitivity of upper part of separatrix
% Small perturbation
epsilon = 1e-6;

% Eigenvector related to stable manifold
vs = v(:, 2, 2);

% Initial state
X0 = initial_state_separatrix(xs(:, 2), vs, lambda(2, 2), epsilon, ...
    p, q, @fitzhughnagumo);

% Compute sensitivities
[Tu, Xu] = ode15s(@(T, X) separatrix_sensitivity_equations(X, p, q, @fitzhughnagumo), ...
    tspan, X0, ode15s_opts);

% Extract solution
xu = Xu(:, 1:2);
Su = Xu(:, 3:end);

%% Sensitivity of lower part of separatrix
% Initial state (note the minus sign of epsilon
X0 = initial_state_separatrix(xs(:, 2), vs, lambda(2, 2), -epsilon, ...
    p, q, @fitzhughnagumo);

% Compute sensitivities
[Tl, Xl] = ode15s(@(T, X) separatrix_sensitivity_equations(X, p, q, @fitzhughnagumo), ...
    tspan, X0, ode15s_opts);

% Extract solution
xl = Xl(:, 1:2);
Sl = Xl(:, 3:end);

%% Postprocess sensitivities (make orthogonal to separatrix)
% Scaling factor (for plotting)
scal = 0.4;

% Select indices
idx = [1, 900, 950, 970, 980, 990, 999];

for i = 1:numel(idx)
    % Local index
    j = idx(i);

    % Evaluate right-hand side function (minus because we simulate
    % backwards in time)
    fu = -fitzhughnagumo(xu(j, :), p, q);
    fl = -fitzhughnagumo(xl(j, :), p, q);

    % Make sensitivity orthogonal to separatrix
    Suo(i, :) = Su(j, :)' - (Su(j, :)*fu)*fu/norm(fu)^2; %#ok
    Slo(i, :) = Sl(j, :)' - (Sl(j, :)*fl)*fl/norm(fl)^2; %#ok
end

% Norm of largest sensitivity
Smax = max([vecnorm(Suo, 2, 2); vecnorm(Slo, 2, 2)]);

% Normalize sensitivities
Suo = scal*Suo/Smax;
Slo = scal*Slo/Smax;

%% Perturbed separatrix
% Perturb parameter
pp = 1.3*p;

% Initial guess
xp0 = [0; 0];

% Solve for the steady state
xps = fsolve(@fitzhughnagumo, xp0, fsolve_opts, ...
    pp, q);

% Evaluate Jacobian
[~, J] = fitzhughnagumo(xps, pp, q);

% Eigenvalues
[V, D] = eig(J);

% Stable eigenvalue and eigenvector
lambdaps = D(2, 2);
vps      = V(:, 2);

% Time span (chosen specifically for computing the separatrix)
tspanpu = linspace(0, 173.5, 1e3);
tspanpl = linspace(0, 170, 1e3);

% Small perturbation
epsilon = 1e-6;

% Initial state
Xp0 = initial_state_separatrix(xps, vps, lambdaps, epsilon, ...
    pp, q, @fitzhughnagumo);

% Compute sensitivities
[Tpu, Xpu] = ode15s(@(T, X) separatrix_sensitivity_equations(X, pp, q, @fitzhughnagumo), ...
    tspanpu, Xp0, ode15s_opts);

% Initial state (note the minus sign of epsilon
Xp0 = initial_state_separatrix(xps, vps, lambdaps, -epsilon, ...
    pp, q, @fitzhughnagumo);

% Compute sensitivities
[Tpl, Xpl] = ode15s(@(T, X) separatrix_sensitivity_equations(X, pp, q, @fitzhughnagumo), ...
    tspanpl, Xp0, ode15s_opts);

% Extract solution
xpu = Xpu(:, 1:2);
xpl = Xpl(:, 1:2);

%% Add remaining plots
% Add to existing plot
hold on;

% Add separatrix
plot(xu(:, 1), xu(:, 2), 'k', 'Linewidth', 3, 'DisplayName', 'Separatrix');

% Add separatrix
plot(xl(:, 1), xl(:, 2), 'k', 'Linewidth', 3, 'HandleVisibility', 'off');

% Reset color order
set(gca, 'ColorOrderIndex', 1);

% Plot subspaces of saddle point
quiver(xs(1, 2), xs(2, 2), v(1, 1, 2), v(2, 1, 2), 'off', 'LineWidth', 2, ...
    'DisplayName', 'Linear subspaces');

% Reset color order
set(gca, 'ColorOrderIndex', 1);

% Plot subspaces of saddle point
quiver(xs(1, 2), xs(2, 2), v(1, 2, 2), v(2, 2, 2), 'off', 'LineWidth', 2, ...
    'HandleVisibility', 'off');

% Reset color order
set(gca, 'ColorOrderIndex', 1);

% Visualize stable steady states
plot(xs(1, [1, 3]), xs(2, [1, 3]), '.', 'MarkerSize', 30, 'DisplayName', 'Steady states');

% Reset color order
set(gca, 'ColorOrderIndex', 5);

% Add separatrix
plot(xpu(:, 1), xpu(:, 2), 'Linewidth', 3, ...'Color', [0, 0, 0, 0.5], ...
    'DisplayName', 'Perturbed separatrix');

% Reset color order
set(gca, 'ColorOrderIndex', 5);

% Add separatrix
plot(xpl(:, 1), xpl(:, 2), 'Linewidth', 3, ...'Color', [0, 0, 0, 0.5], ...
    'HandleVisibility', 'off');

% Reset color order
set(gca, 'ColorOrderIndex', 2);

% Plot sensitivities
quiver(xu(idx, 1), xu(idx, 2), Suo(:,  1), Suo(:,  2), 'off', 'LineWidth', 2, ...
    'DisplayName', 'Sensitivities');

% Reset color order
set(gca, 'ColorOrderIndex', 2);

% Plot sensitivities
quiver(xl(idx, 1), xl(idx, 2), Slo(:,  1), Slo(:,  2), 'off', 'LineWidth', 2, ...
    'HandleVisibility', 'off');

% Reset color order
set(gca, 'ColorOrderIndex', 1);

% Visualize stable steady states
plot(xs(1, 2), xs(2, 2), '.', 'MarkerSize', 30, 'HandleVisibility', 'off');

% Stop adding to existing plot
hold off;

% Axis limits
xlim([xmin(1), xmax(1)]);
ylim([xmin(2), xmax(2)]);

% Add legend
legend('Location', 'SouthEast', 'NumColumns', 2);

%% Save figure
exportgraphics(gcf, './eps/fitzhughnagumo.eps');
exportgraphics(gcf, './png/fitzhughnagumo.png');

%% Functions
function [f, dfx, dfp, d2fxp] = fitzhughnagumo(x, p, q)
% Compute derivatives?
ComputeStateJacobian     = (nargout > 1);
ComputeParameterJacobian = (nargout > 2);
ComputeMixedDerivatives  = (nargout > 3);

% Extract parameters
e   = p(1);
a   = q(1);
b   = q(2);
tau = q(3);

% Extract states
v = x(1);
w = x(2);

% Evaluate right-hand side functions
f = [v - v.^3/3 - w + e; (v + a - b*w)/tau];

if(ComputeStateJacobian)
    % Jacobian
    dfx = [1 - v.^2, -1; 1/tau, -b/tau];

    if(ComputeParameterJacobian)
        % Jacobian wrt. parameters
        dfp = [1; 0];

        if(ComputeMixedDerivatives)
            % Hessian wrt. states and the parameter
            d2fxp = zeros(size(dfx));
        end
    end
end
end

function F = separatrix_sensitivity_equations(X, p, q, f)
% Number of parameters
np = numel(p);

% Number of states
nx = numel(X)/(1 + np);

% Extract states and sensitivities
x = X(      1:nx    );
S = X(nx + (1:nx*np));

% Evaluate right-hand side function and Jacobians
[f, dfx, dfp] = f(x, p, q);

% Right-hand side
F = [-f; -(dfx*S + dfp)];
end

function X0 = initial_state_separatrix(xs, vs, lambdas, epsilon, p, q, f)
% Initial state
x0 = xs + epsilon*vs;

% Evaluate right-hand side and Jacobians
[~, dfx, dfp, d2fxp] = f(xs, p, q);

% Identity matrix
I = eye(size(dfx));

% Compute sensitivity of steady state
dxs = -dfx\dfp;

% Compute sensitivity of eigenvalue
dvs = pinv(lambdas*I - dfx)*d2fxp*vs;

% Sensitivity of initial state
S0 = dxs + epsilon*dvs;

% Collect initial state
X0 = [x0; S0];
end