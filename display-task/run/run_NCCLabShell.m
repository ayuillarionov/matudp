% Clear the workspace and the screen
sca;
close all;
clearvars;

cxt = NCCLab_DisplayContext();

% PsychDebugWindowConfiguration

ns = EyelinkNetworkShell(cxt);
%ns.catchErrors = false;
ns.showEyes = false; % speedgoat data used if false

%ns.setTask(RewardPredictiveTargets_Task());
ns.run();