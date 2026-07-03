// UART Transmitter
// sends 1 byte serially - start bit, 8 data bits (LSB first), stop bit
module uart_tx #(
    parameter CLK_FREQ   = 50_000_000, // system clock, 50MHz
    parameter BAUD_RATE  = 115200
)(
    input  wire       clk,
    input  wire       rst_n,      // active low reset
    input  wire       tx_start,   // pulse this to start sending
    input  wire [7:0] tx_byte,    // byte to send
    output reg        tx_out,     // actual serial line
    output reg        tx_active,  // high while sending
    output reg        tx_done     // goes high for 1 cycle when done
);

    // how many clk cycles = 1 bit period
    localparam CLK_PER_BIT = CLK_FREQ / BAUD_RATE;

    // states for the fsm
    localparam STATE_IDLE  = 2'b00;
    localparam STATE_START = 2'b01;
    localparam STATE_DATA  = 2'b10;
    localparam STATE_STOP  = 2'b11;

    reg [1:0]  current_state, next_state;
    reg [15:0] clk_count;   // counts clk cycles within current bit
    reg [2:0]  bit_index;   // which data bit we're on (0-7)
    reg [7:0]  tx_data;     // local copy of the byte being sent

    // state register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // next state logic
    always @(*) begin
        next_state = current_state;

        case (current_state)
            STATE_IDLE: begin
                if (tx_start) next_state = STATE_START;
            end

            STATE_START: begin
                // wait out the full start bit before moving on
                if (clk_count == CLK_PER_BIT - 1)
                    next_state = STATE_DATA;
            end

            STATE_DATA: begin
                // move to stop bit once last data bit is done
                if (clk_count == CLK_PER_BIT - 1 && bit_index == 3'd7)
                    next_state = STATE_STOP;
            end

            STATE_STOP: begin
                if (clk_count == CLK_PER_BIT - 1)
                    next_state = STATE_IDLE;
            end

            default: next_state = STATE_IDLE;
        endcase
    end

    // output + datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_count  <= 16'd0;
            bit_index  <= 3'd0;
            tx_data    <= 8'd0;
            tx_out     <= 1'b1; // line idles high
            tx_active  <= 1'b0;
            tx_done    <= 1'b0;
        end else begin
            tx_done <= 1'b0; // default, only pulses high in STOP

            case (current_state)
                STATE_IDLE: begin
                    tx_out    <= 1'b1;
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;
                    tx_active <= 1'b0;

                    if (tx_start) begin
                        tx_data   <= tx_byte; // grab the byte before it changes
                        tx_active <= 1'b1;
                    end
                end

                STATE_START: begin
                    tx_out <= 1'b0; // start bit = pull low

                    if (clk_count < CLK_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 16'd0;
                    end
                end

                STATE_DATA: begin
                    tx_out <= tx_data[bit_index]; // LSB first

                    if (clk_count < CLK_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 16'd0;

                        if (bit_index < 3'd7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 3'd0; // reset for next byte
                        end
                    end
                end

                STATE_STOP: begin
                    tx_out <= 1'b1; // stop bit = high

                    if (clk_count < CLK_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 16'd0;
                        tx_active <= 1'b0;
                        tx_done   <= 1'b1; // let the world know we're done
                    end
                end
            endcase
        end
    end

endmodule