module key_debounce #(parameter KEY_W = 3, DELAY_TIME = 1_000_000)(
    input clk,
    input rst_n,
    input [KEY_W-1:0] key_in,
    output [KEY_W-1:0] key_out
);
    reg [19:0] cnt;
    wire add_cnt, end_cnt;
    reg flag;
    reg [KEY_W-1:0] key_r0, key_r1;
    wire [KEY_W-1:0] nedge;
    reg [KEY_W-1:0] key_flag;

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) cnt <= 0;
        else if(add_cnt) begin
            if(end_cnt) cnt <= 0;
            else cnt <= cnt + 1;
        end
    end
    assign add_cnt = flag;
    assign end_cnt = add_cnt && cnt == DELAY_TIME-1;

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) flag <= 1'b0;
        else if(nedge != 0) flag <= 1'b1;
        else if(end_cnt) flag <= 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            key_r0 <= {KEY_W{1'b1}};
            key_r1 <= {KEY_W{1'b1}};
        end else begin
            key_r0 <= key_in;
            key_r1 <= key_r0;
        end
    end
    assign nedge = key_r1 & ~key_r0; // 检测下降沿（按下）

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) key_flag <= 0;
        else key_flag <= end_cnt ? ~key_r1 : 0;
    end
    assign key_out = key_flag;
endmodule