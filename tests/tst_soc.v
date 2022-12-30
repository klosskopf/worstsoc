`timescale 1ns/1ns

module tst_soc (
    input rst_i,
    input clk_i,
    input [31:0] parallel_i,
    output [31:0] parallel_o,
    output flashClk_o,
    output flashMosi_o,
    input flashMiso_i,
    output flashWp_o,
    output flashHold_o,
    output uartTx_o,
    input uartRx_i
);

soc top(
    .rst_i(rst_i),
    .clk_i(clk_i),
    .parallel_i(parallel_i),
    .parallel_o(parallel_o),
    .flashClk_o(flashClk_o),
    .flashMosi_o(flashMosi_o),
    .flashMiso_i(flashMiso_i),
    .flashWp_o(flashWp_o),
    .flashHold_o(flashHold_o),
    .uartTx_o(uartTx_o),
    .uartRx_i(uartRx_i)
);

initial begin
    $dumpfile("logs/vlt_dump.vcd");
    $dumpvars();
end

endmodule
