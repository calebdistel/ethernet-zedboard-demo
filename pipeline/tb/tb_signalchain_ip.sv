// IP-level testbench for the HDL Coder IP core SignalCha_ip.
// Reads/writes the AXI4-Lite registers, receives the AXI4-Stream output with
// random backpressure plus one long stall (fills the IP's output FIFO), and
// writes every accepted beat as "TDATA TLAST" to the file given by +out=<file>.

`timescale 1ns / 1ps

module tb_signalchain_ip;

  localparam int FRAME    = 1024;
  localparam int N_FRAMES = 3;

  // register offsets (ipcore/SignalCha_ip_v1_0/include/SignalCha_ip_addr.h)
  localparam logic [15:0] REG_PACKET_SIZE = 16'h0008;
  localparam logic [15:0] REG_TIMESTAMP   = 16'h000C;
  localparam logic [15:0] REG_ENABLE      = 16'h0100;

  logic clk = 0, rstn = 0;
  always #4 clk = ~clk;   // 125 MHz

  // AXI4-Lite
  logic [15:0] awaddr = 0, araddr = 0;
  logic [31:0] wdata = 0, rdata;
  logic        awvalid = 0, wvalid = 0, bready = 0, arvalid = 0, rready = 0;
  logic        awready, wready, bvalid, arready, rvalid;
  logic [1:0]  bresp, rresp;

  // AXI4-Stream
  logic [31:0] tdata;
  logic        tvalid, tlast, tready = 0;

  SignalCha_ip dut (
    .IPCORE_CLK                (clk),
    .IPCORE_RESETN             (rstn),
    .AXI4_Lite_ACLK            (clk),
    .AXI4_Lite_ARESETN         (rstn),
    .AXI4_Lite_AWADDR          (awaddr),
    .AXI4_Lite_AWVALID         (awvalid),
    .AXI4_Lite_WDATA           (wdata),
    .AXI4_Lite_WSTRB           (4'hF),
    .AXI4_Lite_WVALID          (wvalid),
    .AXI4_Lite_BREADY          (bready),
    .AXI4_Lite_ARADDR          (araddr),
    .AXI4_Lite_ARVALID         (arvalid),
    .AXI4_Lite_RREADY          (rready),
    .AXI4_Lite_AWREADY         (awready),
    .AXI4_Lite_WREADY          (wready),
    .AXI4_Lite_BRESP           (bresp),
    .AXI4_Lite_BVALID          (bvalid),
    .AXI4_Lite_ARREADY         (arready),
    .AXI4_Lite_RDATA           (rdata),
    .AXI4_Lite_RRESP           (rresp),
    .AXI4_Lite_RVALID          (rvalid),
    .AXI4_Stream_Master_TREADY (tready),
    .AXI4_Stream_Master_TDATA  (tdata),
    .AXI4_Stream_Master_TVALID (tvalid),
    .AXI4_Stream_Master_TLAST  (tlast)
  );

  // ------------------------------------------------------------ AXI4-Lite
  task automatic axi_write(input logic [15:0] addr, input logic [31:0] data);
    @(posedge clk);
    awaddr <= addr; awvalid <= 1; wdata <= data; wvalid <= 1; bready <= 1;
    fork
      begin do @(posedge clk); while (!awready); awvalid <= 0; end
      begin do @(posedge clk); while (!wready);  wvalid  <= 0; end
    join
    do @(posedge clk); while (!bvalid);
    bready <= 0;
    if (bresp != 0) $error("write 0x%04h: BRESP=%0d", addr, bresp);
  endtask

  task automatic axi_read(input logic [15:0] addr, output logic [31:0] data);
    @(posedge clk);
    araddr <= addr; arvalid <= 1; rready <= 1;
    do @(posedge clk); while (!arready);
    arvalid <= 0;
    do @(posedge clk); while (!rvalid);
    data = rdata;
    rready <= 0;
    if (rresp != 0) $error("read 0x%04h: RRESP=%0d", addr, rresp);
  endtask

  // ---------------------------------------------------------- stream sink
  int    fd, beats = 0, cycle = 0;
  string fname;

  always @(posedge clk) begin
    cycle <= cycle + 1;
    if (tvalid && tready && beats < N_FRAMES * FRAME) begin
      $fdisplay(fd, "%0d %0d", tdata, tlast);
      beats <= beats + 1;
    end
    // ~75% random TREADY, and a 1000-cycle stall to fill the IP output FIFO
    if (!rstn || (cycle >= 4000 && cycle < 5000)) tready <= 0;
    else                                         tready <= ($urandom_range(3) != 0);
  end

  // ---------------------------------------------------------------- main
  logic [31:0] r;

  initial begin
    if (!$value$plusargs("out=%s", fname)) fname = "ip_stream.txt";
    fd = $fopen(fname, "w");

    repeat (10) @(posedge clk);
    rstn <= 1;
    repeat (10) @(posedge clk);

    axi_read(REG_TIMESTAMP, r);
    $display("IP timestamp: %0d", r);              // yymmddHHMM

    // packet size is write-only; set it like the software driver will
    axi_write(REG_PACKET_SIZE, FRAME);

    // start the signal chain (enable -> NCO validIn)
    axi_write(REG_ENABLE, 1);

    wait (beats == N_FRAMES * FRAME);
    repeat (10) @(posedge clk);
    $fclose(fd);
    $display("IP TB DONE: %0d beats, %0d cycles", beats, cycle);
    $finish;
  end

  initial begin
    #1ms;
    $display("IP TB TIMEOUT: %0d beats", beats);
    $fclose(fd);
    $finish;
  end

endmodule
