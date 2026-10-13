%% Real ZedBoard: receive the UDP frames sent by ethernet_udp_app
% Start this BEFORE running the app from Vitis. The PC's Ethernet adapter to
% the board must be 192.168.50.1 / 255.255.255.0.

%% setup output directory
here = fileparts(mfilename('fullpath'));
outDir = fullfile(here, '..', 'results', 'board');
if ~isfolder(outDir), mkdir(outDir); end

port = 5005;        % = PC_PORT in the Vitis build
nFrames = 3;        % = NUM_FRAMES in main.c
timeoutSec = 180;

% Expected frames: consecutive IP core frames from step 11 (the data in golden_frame.h)
expected = readtable(fullfile(here, '..', 'results', 'vivado', 'ip_stream.csv')).TDATA;
expected = reshape(expected(1:floor(end/1024)*1024), 1024, []);   % one column per frame

%% Receive frames: 4 packets x 256 bins, 12-byte header
% header (uint16, little-endian): frame, packet, total packets, start bin, bin count, reserved
u = udpport("datagram", "IPV4", "LocalPort", port, "Timeout", 1);
fprintf('Listening on UDP port %d - now run ethernet_udp_app from Vitis\n', port);

frames = containers.Map('KeyType', 'double', 'ValueType', 'any');
done = 0;
t0 = tic;
while done < nFrames && toc(t0) < timeoutSec
    if u.NumDatagramsAvailable == 0
        pause(0.01);
        continue
    end
    d = read(u, 1, "uint8");
    b = uint8(d.Data(:))';
    if numel(b) < 12, continue, end                 % 1-byte ARP warm-up
    h = double(typecast(b(1:12), 'uint16'));
    if numel(b) ~= 12 + 4 * h(5)
        fprintf('Text from board: %s\n', char(b));
        continue
    end

    if ~isKey(frames, h(1))
        frames(h(1)) = struct('mag', zeros(1024, 1), 'got', false(1, h(3)));
    end
    f = frames(h(1));
    f.mag(h(4)+1 : h(4)+h(5)) = double(typecast(b(13:end), 'uint32'));
    f.got(h(2)+1) = true;
    frames(h(1)) = f;

    if all(f.got)
        k = (0:1023)';
        writetable(table(k, f.mag, 'VariableNames', {'Bin', 'Magnitude'}), ...
            fullfile(outDir, sprintf('udp_frame_%d.csv', h(1))));
        [~, o] = sort(f.mag, 'descend');
        fprintf('Frame %d: strongest bin %d (%d), next %d (%d), %d/1024 bins match IP core frame %d\n', ...
            h(1), o(1)-1, f.mag(o(1)), o(2)-1, f.mag(o(2)), sum(f.mag == expected(:, h(1))), h(1));
        remove(frames, h(1));
        done = done + 1;
    end
end
clear u
if done < nFrames, fprintf('Timeout after %d of %d frames\n', done, nFrames); end
