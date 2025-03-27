`timescale 1ns / 1ps

module tb_mm;

    // Parameters
    parameter C_S0_AXIS_TDATA_WIDTH = 32;
    parameter C_M0_AXIS_TDATA_WIDTH = 32;
    parameter C_M0_AXIS_START_COUNT = 32;
    parameter N = 4;

    // Clock and reset
    reg s0_axis_aclk;
    reg s0_axis_aresetn;
    reg m0_axis_aclk;
    reg m0_axis_aresetn;

    // Slave AXI Stream signals
    reg [C_S0_AXIS_TDATA_WIDTH-1:0] s0_axis_tdata;
    reg [(C_S0_AXIS_TDATA_WIDTH/8)-1:0] s0_axis_tstrb;
    reg s0_axis_tlast;
    reg s0_axis_tvalid;
    wire s0_axis_tready;

    // Master AXI Stream signals
    wire [C_M0_AXIS_TDATA_WIDTH-1:0] m0_axis_tdata;
    wire [(C_M0_AXIS_TDATA_WIDTH/8)-1:0] m0_axis_tstrb;
    wire m0_axis_tlast;
    wire m0_axis_tvalid;
    reg m0_axis_tready;

    // Instantiate the matrix multiplier module
    mm #(
        .C_S0_AXIS_TDATA_WIDTH(C_S0_AXIS_TDATA_WIDTH),
        .C_M0_AXIS_TDATA_WIDTH(C_M0_AXIS_TDATA_WIDTH),
        .C_M0_AXIS_START_COUNT(C_M0_AXIS_START_COUNT),
        .N(N)
    ) uut (
        .s0_axis_aclk(s0_axis_aclk),
        .s0_axis_aresetn(s0_axis_aresetn),
        .s0_axis_tready(s0_axis_tready),
        .s0_axis_tdata(s0_axis_tdata),
        .s0_axis_tstrb(s0_axis_tstrb),
        .s0_axis_tlast(s0_axis_tlast),
        .s0_axis_tvalid(s0_axis_tvalid),
        .m0_axis_aclk(m0_axis_aclk),
        .m0_axis_aresetn(m0_axis_aresetn),
        .m0_axis_tvalid(m0_axis_tvalid),
        .m0_axis_tdata(m0_axis_tdata),
        .m0_axis_tstrb(m0_axis_tstrb),
        .m0_axis_tlast(m0_axis_tlast),
        .m0_axis_tready(m0_axis_tready)
    );

    // Clock generation
    always #5 s0_axis_aclk = ~s0_axis_aclk;
    always #5 m0_axis_aclk = ~m0_axis_aclk;

    integer i, j;
    initial begin
        // Initialize signals
        s0_axis_aclk = 0;
        m0_axis_aclk = 0;
        s0_axis_aresetn = 0;
        m0_axis_aresetn = 0;
        s0_axis_tdata = 0;
        s0_axis_tstrb = { (C_S0_AXIS_TDATA_WIDTH/8){1'b1} };
        s0_axis_tlast = 0;
        s0_axis_tvalid = 0;
        m0_axis_tready = 1;
        
        // Reset pulse
        #20;
        s0_axis_aresetn = 1;
        m0_axis_aresetn = 1;

        // Send input matrix A and B
        @(posedge s0_axis_aclk);
        s0_axis_tvalid = 1;
        

        for (i = 0; i < 2*N*N; i = i + 1) begin
            @(posedge s0_axis_aclk);
            s0_axis_tdata = i + 1; // Example test data
            s0_axis_tlast = (i == 2*N*N-1) ? 1 : 0;
        end

        s0_axis_tvalid = 1;
        s0_axis_tlast = 1;

		#10;
        s0_axis_tvalid = 0;
        s0_axis_tlast = 0;

        // Wait for result
        wait(m0_axis_tvalid);
        
        // Read output matrix C
        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                @(posedge m0_axis_aclk);
                if (m0_axis_tvalid) begin
                    $display("C[%0d][%0d] = %d", i, j, m0_axis_tdata);
                end
            end
        end

        $finish;
    end

endmodule

