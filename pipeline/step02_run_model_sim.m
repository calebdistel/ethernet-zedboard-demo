% Signal Parameters must be in workspace before running this

mdl = 'SignalChainModelWithNCO';
stop_time = num2str(6000/Fs);
out = sim(mdl, 'StartTime', '0', 'StopTime', stop_time, ...
    'ReturnWorkspaceOutputs', 'on');