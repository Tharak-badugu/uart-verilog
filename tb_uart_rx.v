// sends 8'hA5 over rx_in with start/stop bits and checks what comes out
// clk/baud overridden to 10 MHz / 1 Mbps just to keep the waveform short

`timescale 1ns/1ps
`include "uart_rx.v"
module tb_uart_rx;

    parameter CLK_FREQ  = 10_000_000;
    parameter BAUD_RATE = 1_000_000;
    parameter CLK_PER_BIT = CLK_FREQ / BAUD_RATE;

    reg clk;
    reg rst_n;
    reg rx_in;

    wire [7:0] rx_data;
    wire       rx_done;
    wire       rx_active;

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx_in(rx_in),
        .rx_data(rx_data),
        .rx_done(rx_done),
        .rx_active(rx_active)
    );

    always #50 clk = ~clk;

    task send_byte(input [7:0] data);
        integer i;
        begin
            rx_in = 1'b0;
            repeat (CLK_PER_BIT) @(posedge clk);

            for (i = 0; i < 8; i = i + 1) begin
                rx_in = data[i];
                repeat (CLK_PER_BIT) @(posedge clk);
            end

            rx_in = 1'b1;
            repeat (CLK_PER_BIT) @(posedge clk);
        end
    endtask

    reg [7:0] captured_data;
    reg       captured;

    always @(posedge clk) begin
        if (rx_done) begin
            captured_data <= rx_data;
            captured      <= 1'b1;
        end
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_uart_rx);

        clk       = 0;
        rst_n     = 0;
        rx_in     = 1'b1;
        captured  = 1'b0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        send_byte(8'hA5);

        repeat (5) @(posedge clk);

        if (captured && captured_data == 8'hA5)
            $display("PASS: received 0x%0h as expected", captured_data);
        else
            $display("FAIL: captured=%0d data=0x%0h", captured, captured_data);

        repeat (10) @(posedge clk);
        $finish;
    end

endmodule