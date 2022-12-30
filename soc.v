`timescale 1ns/1ns

`define MASTERNR 1
`define SLAVENR 5

module soc (
    input rst_i,
`ifdef TEST
    input clk_i,
`endif
    input [31:0] parallel_i,
    output [31:0] parallel_o,
`ifdef TEST
    output flashClk_o,
`endif
    output flashMosi_o,
    input flashMiso_i,
    output flashWp_o,
    output flashHold_o,

    output uartTx_o,
    input uartRx_i
);

wire reset = rst_i;
`ifndef TEST
wire clk_i;
OSCG #(.DIV(10)) I1 (.OSC(clk_i)); //fsys=310MHz/x ; x=10 => 31MHz
`endif

//32bit Bus with byte granularity => word addressed; byte selected
//The slave wb interfaces
wire [31:2] madr [`MASTERNR-1:0];
reg [31:0] mdatMiso [`MASTERNR-1:0];
wire [31:0] mdatMosi [`MASTERNR-1:0];
wire mwe [`MASTERNR-1:0];
wire [3:0] msel [`MASTERNR-1:0];
wire mstb [`MASTERNR-1:0];
reg mack [`MASTERNR-1:0];
wire mcyc [`MASTERNR-1:0];

//The master wb interfaces
reg [31:2] sadr [`SLAVENR-1:0];
wire [31:0] sdatMiso [`SLAVENR-1:0];
reg [31:0] sdatMosi [`SLAVENR-1:0];
reg swe [`SLAVENR-1:0];
reg [3:0] ssel [`SLAVENR-1:0];
reg sstb [`SLAVENR-1:0];
wire sack [`SLAVENR-1:0];
reg scyc [`SLAVENR-1:0];

genvar procNr;
generate
    for (procNr = 0; procNr < `MASTERNR; procNr=procNr+1) begin
        //riscv cpu instantiation: is wishbone master #0
        riscvWb #(.RESET(0)) cpu0(
        .rst_i(reset),
        .clk_i(clk_i),
        .adr_o(madr[procNr]),
        .dat_i(mdatMiso[procNr]),
        .dat_o(mdatMosi[procNr]),
        .we_o(mwe[procNr]),
        .sel_o(msel[procNr]),
        .stb_o(mstb[procNr]),
        .ack_i(mack[procNr]),
        .cyc_o(mcyc[procNr])
        );
    end
endgenerate

//BOOTROM instantiation: is slave #0
rom #(.FILE("firmware.mem"),.ROMADDRBITS(12)) bootrom(
    .clk_i(clk_i),
    .rst_i(reset),
    .adr_i(sadr[0]),
    .dat_o(sdatMiso[0]),
    .stb_i(sstb[0]),
    .ack_o(sack[0])
);

//IO_0 instantiation: is slave #1
parallelport io_0(
    .clk_i(clk_i),
    .rst_i(reset),
    .adr_i(sadr[1][2]), //two words
    .stb_i(sstb[1]),
    .we_i(swe[1]),
    .sel_i(ssel[1]),
    .dat_i(sdatMosi[1]),
    .dat_o(sdatMiso[1]),
    .ack_o(sack[1]),
    .parallel_o(parallel_o),
    .parallel_i(parallel_i)
);

//RAM instantiation: is slave #2
ram #(.RAMADDRBITS(14)) blkram(
    .clk_i(clk_i),
    .rst_i(reset),
    .stb_i(sstb[2]),
    .we_i(swe[2]),
    .sel_i(ssel[2]),
    .dat_i(sdatMosi[2]),
    .dat_o(sdatMiso[2]),
    .adr_i(sadr[2]),
    .ack_o(sack[2])
);

//SPI_0 instantiation: is slave #3
`ifndef TEST
wire flashClkTristate = 1'b0;
wire flashClk_o;
USRMCLK u1 (.USRMCLKI(flashClk_o), .USRMCLKTS(flashClkTristate));
`endif //TEST
assign flashWp_o = 1'b1;
assign flashHold_o = 1'b1;
spi spi_0(
    .clk_i(clk_i),
    .rst_i(reset),
    .adr_i(sadr[3][3:2]),
    .stb_i(sstb[3]),
    .sel_i(ssel[3]),
    .we_i(swe[3]),
    .dat_i(sdatMosi[3]),
    .dat_o(sdatMiso[3]),
    .ack_o(sack[3]),
    .spiClk_o(flashClk_o),
    .spiMosi_o(flashMosi_o),
    .spiMiso_i(flashMiso_i)
);

//UART_0 instantiation: is slave #4
uart uart_0(
    .clk_i(clk_i),
    .rst_i(reset),
    .adr_i(sadr[4][3:2]),
    .sel_i(ssel[4]),
    .stb_i(sstb[4]),
    .we_i(swe[4]),
    .dat_i(sdatMosi[4]), 
    .dat_o(sdatMiso[4]),
    .ack_o(sack[4]),
    .uartTx_o(uartTx_o),
    .uartRx_i(uartRx_i)
);

//The actual bus
reg cyc;
reg stb;
reg we;
reg [3:0] sel;
reg [31:0] datMosi;
reg [31:0] datMiso;
reg [31:2] adr;
reg ack;
reg acmp [`SLAVENR-1:0];
reg gnt [`MASTERNR-1:0];


//Slave inputs
integer i;
always @(*) begin
    for (i = 0; i<`SLAVENR; i=i+1) begin
        sadr[i] = adr;
        sdatMosi[i] = datMosi;
        ssel[i] = sel;
        swe[i] = we;
        scyc[i] = cyc;
        sstb[i] = acmp[i] & cyc & stb;
    end
end

//Memory-Map
//0x0000_0000 - 0x0FFF_FFFF: BOOTROM (0)
//0x1000_0000 - 0x1FFF_FFFF: UART_0 (4)
//0x2000_0000 - 0x2FFF_FFFF: IO_0 (1)
//0x3000_0000 - 0x3FFF_FFFF: SPI_0 (3)
//0x4000_0000 - 0x4FFF_FFFF: RAM (2)
always @(*) begin
    for (i = 0; i<`SLAVENR; i=i+1) begin
        acmp[i] = 1'b0;
    end
    if (adr[31:28] == 4'b0000) acmp[0] = 1'b1;//ROM
    else if (adr[31:28] == 4'b0001) acmp[4] = 1'b1;//uart0
    else if (adr[31:28] == 4'b0010) acmp[1] = 1'b1;//parallel
    else if (adr[31:28] == 4'b0011) acmp[3] = 1'b1;//spi0 (flash)
    else if (adr[31:28] == 4'b0100) acmp[2] = 1'b1;//RAM
    else acmp[0] = 1'b1; //mirror ROM outside, to prevent stall
end

//Slave outputs
always @(*) begin
    datMiso = 32'hxxxxxxxx;
    ack = 1'b0;
    for (i = 0; i<`SLAVENR; i=i+1) begin
        if (acmp[i]) begin
            datMiso = sdatMiso[i];
            ack = sack[i];
        end
    end
end

//Master inputs
always @(*) begin
    for (i = 0; i<`MASTERNR; i=i+1) begin
        if (gnt[i]) begin
            mdatMiso[i] = datMiso;
            mack[i] = ack;
        end
        else begin
            mdatMiso[i] = 32'hxxxxxxxx;
            mack[i] = 1'b0;
        end
    end
end

//Master output
always @(*) begin
    adr = 30'hxxxxxxxx;
    datMosi = 32'hxxxxxxxx;
    sel = 4'hx;
    we = 1'b0;
    stb = 1'b0;
    cyc = 1'b0;
    for (i = 0; i<`MASTERNR; i=i+1) begin
        if (gnt[i]) begin
            adr = madr[i];
            datMosi = mdatMosi[i];
            sel = msel[i];
            we = mwe[i];
            stb = mstb[i];
            cyc = 1'b1;
        end
    end
end

//Bus arbiter
reg busFree;
always @(*) begin
    busFree = 1'b1;
    for (i = 0; i<`MASTERNR; i=i+1) begin
        if (mcyc[i] && gnt[i])    //if a master has been granted access and is not finished yet,
            busFree = 1'b0;         //the bus is not free
    end
end
reg [`MASTERNR:0] accessPrio;   //Each bit says, that this or a higher prio master wants access
always @(*) begin
    accessPrio[0] = mcyc[0];
    for (i = 1; i<`MASTERNR; i=i+1) begin
        accessPrio[i] = mcyc[i] | accessPrio[i-1];
    end
end
always @(posedge(clk_i)) begin
    if (clk_i) begin
        if (busFree)                           //If a new master is searched for
            gnt[0] <= mcyc[0];                        //highest priority master can be it if it wants
        else
            gnt[0] <= gnt[0];
        for (i = 1; i < `MASTERNR; i=i+1) begin
            if (busFree) begin                 //If a new master is searched for
                if (accessPrio[i] && !accessPrio[i-1])  //if the master wants access and has priority (The higher prio master has accessPrio low)
                    gnt[i] <= 1'b1;                     //Take the access;
                else
                    gnt[i] <= 1'b0;
            end                                         //else nothing changes
            else
                gnt[i] <= gnt[i];
        end
    end
end

endmodule
