// uart_tx.v —— 串口发送模块
// 波特率: 115200, 系统时钟: 25MHz
// 数据格式: 1起始位 + 8数据位 + 1停止位, 无校验
module uart_tx #(
    parameter CLK_FREQ = 25_000_000,  // 系统时钟频率
    parameter BAUD     = 115200       // 波特率
) (
    input  wire       clk,       // 25MHz系统时钟
    input  wire       rst_n,     // 异步复位, 低有效
    input  wire       send,      // 发送触发, 上升沿触发一次发送
    input  wire [7:0] data_in,   // 待发送的8位数据
    output reg        tx,        // UART TX输出
    output reg        busy       // 忙标志, 1=正在发送, 发送期间勿触发新发送
);

    // 波特率分频计数器: 每个bit持续 BIT_CNT 个时钟周期
    // 50M / 115200 ≈ 434
    localparam BIT_CNT = CLK_FREQ / BAUD;

    reg [9:0] bit_cnt;   // 波特率分频计数 (10位够用, 最大值434 < 1024)
    reg [3:0] bit_idx;   // 当前正在发送第几bit (0=起始位, 1-8=数据, 9=停止位)
    reg [7:0] tx_data;   // 锁存待发数据

    // 状态机: IDLE(空闲) / SENDING(发送中)
    reg state;
    localparam IDLE    = 1'b0;
    localparam SENDING = 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            tx      <= 1'b1;    // 空闲时TX保持高电平
            busy    <= 1'b0;
            bit_cnt <= 0;
            bit_idx <= 0;
            tx_data <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx      <= 1'b1;   // 空闲态TX=1
                    busy    <= 1'b0;
                    bit_cnt <= 0;
                    bit_idx <= 0;
                    if (send) begin     // 检测到发送脉冲
                        tx_data <= data_in;
                        state   <= SENDING;
                    end
                end

                SENDING: begin
                    busy <= 1'b1;

                    if (bit_cnt < BIT_CNT - 1) begin
                        bit_cnt <= bit_cnt + 1;
                    end else begin
                        bit_cnt <= 0;   // 当前bit发送完毕, 切换下一bit
                        if (bit_idx == 9) begin
                            // 10个bit全部发完 (起始+8数据+停止)
                            state <= IDLE;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end

                    // 根据bit_idx输出对应电平
                    case (bit_idx)
                        0: tx <= 1'b0;               // 起始位 = 低
                        1: tx <= tx_data[0];         // 数据bit0 (LSB先发)
                        2: tx <= tx_data[1];
                        3: tx <= tx_data[2];
                        4: tx <= tx_data[3];
                        5: tx <= tx_data[4];
                        6: tx <= tx_data[5];
                        7: tx <= tx_data[6];
                        8: tx <= tx_data[7];         // 数据bit7 (MSB最后)
                        9: tx <= 1'b1;               // 停止位 = 高
                        default: tx <= 1'b1;
                    endcase
                end
            endcase
        end
    end

endmodule
