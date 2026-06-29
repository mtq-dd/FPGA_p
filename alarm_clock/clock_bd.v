// clock_bd.v —— 闹钟核心 v4
// v4: 2键控制 — S2切模式, 设时/闹钟模式自动走位+自动增值
module clock_bd #(parameter CNT_MAX = 25_000_000) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [2:0] key,
    output reg  [3:0] hour_h, hour_l, min_h, min_l, sec_h, sec_l,
    output wire       tick_1s,
    output wire [3:0] led,
    output reg        buzzer
);

    reg [3:0] alarm_min_l, alarm_min_h, alarm_hour_l, alarm_hour_h;
    reg       alarm_en;
    reg [1:0] mode;        // 0=走时 1=设时钟 2=设闹钟
    reg [2:0] pos;         // 当前编辑位: 0=秒个位 1=秒十位 2=分个位 3=分十位

    // 1秒分频
    reg [25:0] cnt_1s;
    assign tick_1s = (cnt_1s == CNT_MAX - 1);
    wire buzzer_wave = cnt_1s[14];  // ~763Hz方波

    // 设置模式下: pos_auto计时器, 每3秒自动进一位
    reg [1:0]  pos_timer;  // 0..2 计数tick_1s次数, 数到3时pos自动+1
    wire       pos_adv = (pos_timer == 2'd2);  // 每3个tick_1s进位

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cnt_1s <= 0;
        else if (cnt_1s == CNT_MAX - 1) cnt_1s <= 0;
        else cnt_1s <= cnt_1s + 1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode <= 2'b00; pos <= 0; alarm_en <= 1'b0;
            sec_l <= 0; sec_h <= 0; min_l <= 0; min_h <= 0;
            hour_l <= 0; hour_h <= 0;
            alarm_min_l <= 0; alarm_min_h <= 0;
            alarm_hour_l <= 0; alarm_hour_h <= 0;
            buzzer <= 1'b0;
            pos_timer <= 0;
        end else begin

            // ===== 模式切换 (S2短按) =====
            if (key[0]) begin
                mode <= (mode == 2'b10) ? 2'b00 : mode + 1;
                pos  <= 0;
                pos_timer <= 0;
            end

            // ===== 设置模式: 自动控制 =====
            if (mode != 2'b00 && tick_1s) begin
                // 每秒当前位值自动+1
                case (mode)
                    2'b01: begin  // 设时钟
                        case (pos)
                            0: sec_l <= (sec_l == 9) ? 0 : sec_l + 1;
                            1: sec_h <= (sec_h == 5) ? 0 : sec_h + 1;
                            2: min_l <= (min_l == 9) ? 0 : min_l + 1;
                            3: min_h <= (min_h == 5) ? 0 : min_h + 1;
                        endcase
                    end
                    2'b10: begin  // 设闹钟
                        case (pos)
                            0: alarm_min_l  <= (alarm_min_l  == 9) ? 0 : alarm_min_l  + 1;
                            1: alarm_min_h  <= (alarm_min_h  == 5) ? 0 : alarm_min_h  + 1;
                            2: alarm_hour_l <= (alarm_hour_l == 9) ? 0 : alarm_hour_l + 1;
                            3: alarm_hour_h <= (alarm_hour_h == 2) ? 0 : alarm_hour_h + 1;
                        endcase
                        alarm_en <= 1'b1;
                    end
                endcase

                // 每3秒pos自动进位
                if (pos_adv) begin
                    pos <= (pos == 3) ? 0 : pos + 1;
                    pos_timer <= 0;
                end else begin
                    pos_timer <= pos_timer + 1;
                end
            end

            // ===== 手动位选 (key[1], DIP, 保留兼容) =====
            if (key[1]) begin
                if (mode != 2'b00) begin
                    pos <= (pos == 3) ? 0 : pos + 1;
                    pos_timer <= 0;
                end
            end

            // ===== 手动增值 (key[2], DIP, 保留兼容) =====
            if (key[2]) begin
                case (mode)
                    2'b01: begin
                        case (pos)
                            0: sec_l <= (sec_l == 9) ? 0 : sec_l + 1;
                            1: sec_h <= (sec_h == 5) ? 0 : sec_h + 1;
                            2: min_l <= (min_l == 9) ? 0 : min_l + 1;
                            3: min_h <= (min_h == 5) ? 0 : min_h + 1;
                        endcase
                    end
                    2'b10: begin
                        case (pos)
                            0: alarm_min_l  <= (alarm_min_l  == 9) ? 0 : alarm_min_l  + 1;
                            1: alarm_min_h  <= (alarm_min_h  == 5) ? 0 : alarm_min_h  + 1;
                            2: alarm_hour_l <= (alarm_hour_l == 9) ? 0 : alarm_hour_l + 1;
                            3: alarm_hour_h <= (alarm_hour_h == 2) ? 0 : alarm_hour_h + 1;
                        endcase
                        alarm_en <= 1'b1;
                    end
                    default: ;
                endcase
            end

            // ===== 走时 =====
            if (tick_1s && mode == 2'b00) begin
                sec_l <= (sec_l == 9) ? 0 : sec_l + 1;
                if (sec_l == 9) begin
                    sec_h <= (sec_h == 5) ? 0 : sec_h + 1;
                    if (sec_h == 5) begin
                        min_l <= (min_l == 9) ? 0 : min_l + 1;
                        if (min_l == 9) begin
                            min_h <= (min_h == 5) ? 0 : min_h + 1;
                            if (min_h == 5) begin
                                if (hour_h == 2 && hour_l == 3) begin
                                    hour_h <= 0; hour_l <= 0;
                                end else if (hour_l == 9) begin
                                    hour_h <= hour_h + 1; hour_l <= 0;
                                end else
                                    hour_l <= hour_l + 1;
                            end
                        end
                    end
                end
            end

            // ===== 闹钟 =====
            if (alarm_en && (sec_l == 0))
                buzzer <= buzzer_wave;
            else if (cnt_1s == CNT_MAX/2)
                buzzer <= 1'b0;
            else if (key[0] || key[1] || key[2])
                buzzer <= 1'b0;
        end
    end

    // ===== LED =====
    // 走时模式: [0]=1Hz心跳 [1]=快闪 [2:1]=mode
    // 设置模式: [pos对应的LED]=快闪 指示当前位置
    reg led0_toggle;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) led0_toggle <= 1'b0;
        else if (tick_1s) led0_toggle <= ~led0_toggle;
    end

    // pos位置指示: 设置模式下对应位LED快闪
    wire [3:0] pos_indicator;
    assign pos_indicator[0] = (pos == 0) ? cnt_1s[23] : 1'b0;  // ~3Hz快闪
    assign pos_indicator[1] = (pos == 1) ? cnt_1s[23] : 1'b0;
    assign pos_indicator[2] = (pos == 2) ? cnt_1s[23] : 1'b0;
    assign pos_indicator[3] = (pos == 3) ? cnt_1s[23] : 1'b0;

    assign led = (mode == 2'b00) ? {mode, cnt_1s[24], led0_toggle} : pos_indicator;

endmodule
