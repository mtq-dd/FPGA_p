// uart_time_sender.v —— 把BCD时间格式化成ASCII串, 通过UART发送
// 每秒发送一次 "HH:MM:SS\r\n"
module uart_time_sender (
    input  wire       clk,       // 50MHz系统时钟
    input  wire       rst_n,     // 异步复位, 低有效
    input  wire       tick_1s,   // 1秒脉冲, 上升沿触发一次完整发送
    input  wire [3:0] hour_h,    // 时十位 BCD
    input  wire [3:0] hour_l,    // 时个位 BCD
    input  wire [3:0] min_h,     // 分十位 BCD
    input  wire [3:0] min_l,     // 分个位 BCD
    input  wire [3:0] sec_h,     // 秒十位 BCD
    input  wire [3:0] sec_l,     // 秒个位 BCD
    output reg        uart_send, // 连接到uart_tx.send
    output reg  [7:0] uart_data, // 连接到uart_tx.data_in
    input  wire       uart_busy  // 来自uart_tx.busy
);

    // 待发送的字符序列: "HH:MM:SS\r\n" 共10个字节
    // 索引: 0=H十位 1=H个位 2=':' 3=M十位 4=M个位 5=':' 6=S十位 7=S个位 8='\r' 9='\n'
    reg [3:0] char_idx;    // 当前发送到第几个字符
    reg       sending;     // 是否正在发送一轮
    reg       tick_d1;     // tick_1s的前一拍, 用于边沿检测

    // BCD转ASCII: 0-9的BCD直接加 8'h30 即可得到 '0'-'9'
    function [7:0] bcd2ascii;
        input [3:0] bcd;
        begin
            bcd2ascii = {4'h3, bcd};  // '0' = 0x30, 所以高4位=3, 低4位=BCD值
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_send <= 1'b0;
            uart_data <= 8'd0;
            char_idx  <= 4'd0;
            sending   <= 1'b0;
            tick_d1   <= 1'b0;
        end else begin
            // 检测tick_1s上升沿, 启动一轮发送
            if (tick_1s && !tick_d1) begin
                sending  <= 1'b1;
                char_idx <= 4'd0;
            end
            tick_d1 <= tick_1s;

            if (sending) begin
                if (!uart_busy) begin
                    // UART空闲, 发当前字符
                    case (char_idx)
                        0: uart_data <= bcd2ascii(hour_h);
                        1: uart_data <= bcd2ascii(hour_l);
                        2: uart_data <= ":";  // 8'h3A
                        3: uart_data <= bcd2ascii(min_h);
                        4: uart_data <= bcd2ascii(min_l);
                        5: uart_data <= ":";
                        6: uart_data <= bcd2ascii(sec_h);
                        7: uart_data <= bcd2ascii(sec_l);
                        8: uart_data <= 8'h0D; // '\r'
                        9: uart_data <= 8'h0A; // '\n'
                        default: uart_data <= 8'h00;
                    endcase
                    uart_send <= 1'b1;   // 触发一次发送

                    if (char_idx == 9) begin
                        sending <= 1'b0; // 本轮发完
                    end else begin
                        char_idx <= char_idx + 1;
                    end
                end else begin
                    uart_send <= 1'b0;   // send只需维持1个周期
                end
            end else begin
                uart_send <= 1'b0;
            end
        end
    end

endmodule
