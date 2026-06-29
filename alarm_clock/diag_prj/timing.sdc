# 主时钟约束: 50MHz, 周期20ns
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
