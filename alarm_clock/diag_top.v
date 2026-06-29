// diag_top.v —— 板级诊断固件
// 功能: 逐一验证每个外设引脚, 不依赖任何复杂逻辑
module diag_top (
    input  wire       clk,       // P34 50MHz
    input  wire       btn_s1,    // P31 按键S1 (rst_n位置)
    input  wire       btn_s2,    // P30 按键S2
    input  wire       dip1,      // P45 拨码1
    input  wire       dip2,      // P23 拨码2
    output wire       buzzer,    // P27 蜂鸣器
    output wire [7:0] led_all    // P14,P3,P2,P51,P52,P57,P59,P62 全部8个LED
);

    // ----- 简单计数器, 分频出低频方波 -----
    // 50MHz / 2^25 ≈ 1.49Hz, LED清晰可见闪烁
    reg [24:0] cnt;
    always @(posedge clk) begin
        cnt <= cnt + 1;
    end

    // ----- LED: 8个灯各有不同行为, 一眼能看出是否受控 -----
    // led[0]: 1.49Hz 闪烁 (计数器最高位) → 证明50MHz时钟存在
    // led[1]: 常亮 → 证明该引脚能输出高
    // led[2]: S1按下时亮 → 证明按键S1工作
    // led[3]: S2按下时亮 → 证明按键S2工作
    // led[4]: DIP1状态 → 证明拨码1可读
    // led[5]: DIP2状态 → 证明拨码2可读
    // led[6]: 常灭 → 证明引脚可控
    // led[7]: ~7.5Hz 闪烁 (cnt[23]) → 更快闪烁
    assign led_all[0] = cnt[24];          // ~1.5Hz闪烁
    assign led_all[1] = 1'b1;             // 常亮
    assign led_all[2] = ~btn_s1;          // S1按下亮 (按键低有效)
    assign led_all[3] = ~btn_s2;          // S2按下亮
    assign led_all[4] = ~dip1;            // DIP1 ON时亮 (低有效)
    assign led_all[5] = ~dip2;            // DIP2 ON时亮
    assign led_all[6] = 1'b0;             // 常灭
    assign led_all[7] = cnt[23];          // ~7.5Hz快闪

    // ----- 蜂鸣器: 用低频方波驱动, 持续响 -----
    // 2kHz方波 ≈ 50M / 25000
    assign buzzer = cnt[14];  // 50M/2^15 ≈ 1.5kHz, 人耳清晰

endmodule
