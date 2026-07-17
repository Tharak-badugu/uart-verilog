// UART receiver - 1 start bit, 8 data bits (LSB first), 1 stop bit, no parity
// samples in the middle of each bit so noise on the edges doesn't mess it up

module uart_rx #(
    parameter CLK_FREQ  = 50000000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_in,

    output reg [7:0]  rx_data,
    output reg        rx_done,
    output reg        rx_active
);

    localparam CLK_PER_BIT = CLK_FREQ / BAUD_RATE;

    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;

    // sync flops for rx_in since it's coming from outside
    reg rx_sync1, rx_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx_in;
            rx_sync2 <= rx_sync1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            clk_count <= 0;
            bit_index <= 0;
            rx_data   <= 8'b0;
            rx_done   <= 1'b0;
            rx_active <= 1'b0;
        end else begin
            rx_done <= 1'b0;

            case (state)
                IDLE: begin
                    rx_active <= 1'b0;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (rx_sync2 == 1'b0) begin
                        state     <= START;
                        rx_active <= 1'b1;
                    end
                end

                START: begin
                    // check mid-bit that it's a real start bit, not a glitch
                    if (clk_count == (CLK_PER_BIT/2 - 1)) begin
                        if (rx_sync2 == 1'b0) begin
                            clk_count <= 0;
                            state     <= DATA;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                DATA: begin
                    if (clk_count == CLK_PER_BIT - 1) begin
                        clk_count           <= 0;
                        rx_data[bit_index]  <= rx_sync2;
                        if (bit_index == 3'd7)
                            state <= STOP;
                        else
                            bit_index <= bit_index + 1;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                STOP: begin
                    if (clk_count == CLK_PER_BIT - 1) begin
                        rx_done   <= 1'b1;
                        rx_active <= 1'b0;
                        state     <= IDLE;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule