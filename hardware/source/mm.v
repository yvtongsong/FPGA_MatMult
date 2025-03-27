module mm #
(
    // AXI4-Stream 接口数据宽度参数
    parameter integer C_S0_AXIS_TDATA_WIDTH = 32,
    parameter integer C_M0_AXIS_TDATA_WIDTH = 32,
    parameter integer C_M0_AXIS_START_COUNT = 32,
    // 矩阵阶数参数（N×N矩阵）
    parameter integer N = 8
)
(
    output wire [1:0]                   current_state_debug,
    output wire [1:0]                   next_state_debug,
    output wire [32:0]                  read_cnt_debug,
    // AXI4-Stream Slave Interface (输入矩阵数据)
    input  wire                         s0_axis_aclk,
    input  wire                         s0_axis_aresetn,
    output reg                          s0_axis_tready,
    input  wire [C_S0_AXIS_TDATA_WIDTH-1:0] s0_axis_tdata,
    input  wire [(C_S0_AXIS_TDATA_WIDTH/8)-1:0] s0_axis_tstrb,
    input  wire                         s0_axis_tlast,
    input  wire                         s0_axis_tvalid,

    // AXI4-Stream Master Interface (输出矩阵乘积)
    input  wire                         m0_axis_aclk,
    input  wire                         m0_axis_aresetn,
    output reg                          m0_axis_tvalid,
    output reg [C_M0_AXIS_TDATA_WIDTH-1:0] m0_axis_tdata,
    output reg [(C_M0_AXIS_TDATA_WIDTH/8)-1:0] m0_axis_tstrb,
    output reg                          m0_axis_tlast,
    input  wire                         m0_axis_tready
);

//
// 状态机定义：
// STATE_IDLE  : 复位后进入，准备接收数据
// STATE_READ  : 通过 s0_axis 接口连续接收两个矩阵的数据（A 后接 B）
// STATE_CALC  : 计算矩阵乘法（所有乘法加法并行展开）
// STATE_WRITE : 通过 m0_axis 接口将结果矩阵 C 按顺序输出
//
localparam STATE_IDLE  = 2'd0;
localparam STATE_READ  = 2'd1;
localparam STATE_CALC  = 2'd2;
localparam STATE_WRITE = 2'd3;

reg [1:0] state, next_state;
assign current_state_debug = state;
assign next_state_debug = next_state;

// 定义存放矩阵的存储阵列（A、B 为输入矩阵，C 为输出矩阵）
reg [C_S0_AXIS_TDATA_WIDTH-1:0] A [0:N-1][0:N-1];
reg [C_S0_AXIS_TDATA_WIDTH-1:0] B [0:N-1][0:N-1];
reg [C_S0_AXIS_TDATA_WIDTH-1:0] C [0:N-1][0:N-1];

// 用于统计接收的数据个数（共需接收 2×N×N 个数据）
integer read_cnt;
assign read_cnt_debug = read_cnt;
localparam integer TOTAL_WORDS = 2 * N * N;

// 用于输出阶段的行、列索引
integer out_row, out_col;

// 用于循环变量
integer i, j, k;
reg [C_S0_AXIS_TDATA_WIDTH-1:0] mult_sum;

// 状态机的顺序逻辑（采用 s0_axis_aclk，假定 m0_axis_aclk 与之同步）
always @(posedge s0_axis_aclk) begin
    if (!s0_axis_aresetn) begin
        state         <= STATE_IDLE;
        read_cnt      <= 0;
        out_row       <= 0;
        out_col       <= 0;
        s0_axis_tready<= 1'b0;
        m0_axis_tvalid<= 1'b0;
        m0_axis_tdata <= 0;
        m0_axis_tstrb <= { (C_M0_AXIS_TDATA_WIDTH/8){1'b1} };
        m0_axis_tlast <= 1'b0;
    end else begin
        state <= next_state;
        case (state)
            STATE_IDLE: begin
                // 复位时初始化
                read_cnt       <= 0;
                out_row        <= 0;
                out_col        <= 0;
                s0_axis_tready <= 1'b1;
                m0_axis_tvalid <= 1'b0;
                m0_axis_tlast  <= 1'b0;
            end

            STATE_READ: begin
                // 当输入有效且准备好时采样数据
                if(s0_axis_tvalid && s0_axis_tready) begin
                    if (read_cnt < N*N) begin
                        // 前 N×N 数据存入矩阵 A
                        A[read_cnt / N][read_cnt % N] <= s0_axis_tdata;
                    end else begin
                        // 后 N×N 数据存入矩阵 B
                        B[(read_cnt - N*N) / N][(read_cnt - N*N) % N] <= s0_axis_tdata;
                    end
                    read_cnt <= read_cnt + 1;
                end
            end

            STATE_CALC: begin
                // 对于每个结果元素 C[i][j]，计算： sum_{k=0}^{N-1} A[i][k] * B[k][j]
                for(i = 0; i < N; i = i + 1) begin
                    for(j = 0; j < N; j = j + 1) begin
                        mult_sum = 0;
                        for(k = 0; k < N; k = k + 1) begin
                            mult_sum = mult_sum + A[i][k] * B[k][j];
                        end
                        C[i][j] <= mult_sum;
                    end
                end
            end

            STATE_WRITE: begin
                m0_axis_tvalid <= 1'b1;
                // 当主机准备好接收时输出数据
                if(m0_axis_tready) begin

                    m0_axis_tdata  <= C[out_row][out_col];
                    // 当输出最后一个数据时置 tlast 高电平
                    if((out_row == N-1) && (out_col == N-1))
                        m0_axis_tlast <= 1'b1;
                    else
                        m0_axis_tlast <= 1'b0;
                    
                    // 输出索引更新
                    if(out_col == N-1) begin
                        out_col <= 0;
                        out_row <= out_row + 1;
                    end else begin
                        out_col <= out_col + 1;
                    end
                end
            end

            default: begin
                // 默认情况下不做操作
            end
        endcase
    end
end

reg ok;

// 状态机的组合逻辑：决定下一个状态
always @(*) begin
    next_state = state;
    case (state)
        STATE_IDLE: begin
            // 一旦复位完成，即进入数据接收状态
            next_state = STATE_READ;
            ok = 1'b0;
        end
        STATE_READ: begin
            // 当已接收所有数据并且 tlast 也收到时，进入计算阶段
            if( (read_cnt == TOTAL_WORDS-1) && s0_axis_tlast) begin
                next_state = STATE_CALC;
                ok = 1'b1;
            end else if (ok == 1'b1) 
                next_state = STATE_CALC;
            else
                next_state = STATE_READ;
        end
        STATE_CALC: begin
            // 计算完成后进入数据输出阶段
            next_state = STATE_WRITE;
            ok = 1'b0;
        end
        STATE_WRITE: begin
            // 当所有 N×N 个数据全部输出后，返回空闲等待下一个运算
            if((out_row == N) && (out_col == 0))
                next_state = STATE_IDLE;
            else
                next_state = STATE_WRITE;
        end
        default: next_state = STATE_IDLE;
    endcase
end

endmodule
