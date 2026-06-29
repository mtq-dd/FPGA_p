// alarm_clock_bd.v —— 闹钟顶层 v3
// v3: POR上电复位 + 统一sys_rst_n分发 + 诊断确认所有引脚正常
module alarm_clock_bd (
    input  wire       clk,       // P34 50MHz
    input  wire       rst_n,     // P31 按键S1
    input  wire [2:0] key,       // P30,P45,P23
    output wire       uart_tx,   // P17
    output wire       buzzer,    // P27
    output wire [3:0] led        // P51,P52,P57,P59
);

    // ===== 上电复位(POR): 配置后自动产生1ms低脉冲 =====
    reg [16:0] por_cnt;
    reg       por_done;
    wire      sys_rst_n = rst_n && por_done;  // 外部按键 AND 上电复位

    always @(posedge clk) begin
        if (por_cnt < 50000) begin
            por_cnt <= por_cnt + 1;
            por_done <= 1'b0;
        end else begin
            por_done <= 1'b1;
        end
    end

    // 内部信号
    wire [2:0] key_out;
    wire [3:0] hour_h, hour_l, min_h, min_l, sec_h, sec_l;
    wire       tick_1s;
    wire       uart_send, uart_busy;
    wire [7:0] uart_data;

    // 1. 按键消抖 — 用sys_rst_n确保上电后正确初始化
    key_debounce #(.KEY_W(3)) u_debounce (
        .clk     (clk),
        .rst_n   (sys_rst_n),
        .key_in  (key),
        .key_out (key_out)
    );

    // 2. 时钟核心
    clock_bd u_clock (
        .clk     (clk),
        .rst_n   (sys_rst_n),
        .key     (key_out),
        .hour_h  (hour_h),
        .hour_l  (hour_l),
        .min_h   (min_h),
        .min_l   (min_l),
        .sec_h   (sec_h),
        .sec_l   (sec_l),
        .tick_1s (tick_1s),
        .led     (led),
        .buzzer  (buzzer)
    );

    // 3. UART发送
    uart_tx u_uart (
        .clk     (clk),
        .rst_n   (sys_rst_n),
        .send    (uart_send),
        .data_in (uart_data),
        .tx      (uart_tx),
        .busy    (uart_busy)
    );

    // 4. 时间→ASCII
    uart_time_sender u_sender (
        .clk       (clk),
        .rst_n     (sys_rst_n),
        .tick_1s   (tick_1s),
        .hour_h    (hour_h),
        .hour_l    (hour_l),
        .min_h     (min_h),
        .min_l     (min_l),
        .sec_h     (sec_h),
        .sec_l     (sec_l),
        .uart_send (uart_send),
        .uart_data (uart_data),
        .uart_busy (uart_busy)
    );

endmodule
