`timescale 1ns / 1ps
`include "uart_tx.v"
module tb_uart_tx;

    reg        clk;
    reg        rst_n;
    reg        tx_start;
    reg [7:0]  tx_byte;
    wire       tx_out;
    wire       tx_active;
    wire       tx_done;

    // DUT - using faster clk/baud here just so waveforms don't take forever to sim
    uart_tx #(
        .CLK_FREQ(10_000_000), // 10 MHz for sim
        .BAUD_RATE(1_000_000)  // 1 Mbps -> 10 cycles/bit, easy to eyeball on gtkwave
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_byte(tx_byte),
        .tx_out(tx_out),
        .tx_active(tx_active),
        .tx_done(tx_done)
    );
    // waveform dump
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_uart_tx);
    end 
    // clock gen - 100ns period
    always begin
        #50 clk = ~clk;
    end

    initial begin
        clk      = 1'b0;
        rst_n    = 1'b0;
        tx_start = 1'b0;
        tx_byte  = 8'h0;

        // hold reset a bit before releasing
        #200;
        rst_n = 1'b1;
        #100;

        // sending 8'hA5 = 10100101
        // line should go: START(0) D0(1) D1(0) D2(1) D3(0) D4(0) D5(1) D6(0) D7(1) STOP(1)
        $display("[%0t] Transmitting Data: 8'hA5...", $time);
        @(posedge clk);
        tx_byte  = 8'hA5;
        tx_start = 1'b1;
        @(posedge clk);
        tx_start = 1'b0; // just needs to be a pulse, drop it back down

        // let it run till tx_done fires
        @(posedge tx_done);
       rgb(85, 0, 0);

        $display("[%0t] Simulation Finished Successfully!", $time);
        $finish;
    end

endmodule