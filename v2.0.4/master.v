`timescale 1ns / 1ps

// I2C Master Module
// This module implements an I2C master with support for clock stretching, where the master can hold
// the clock line (SCL) low to pause communication for a defined period. This feature is useful for
// situations where the master needs to wait for data or synchronization.
module i2c_master(
    input wire clk,                    // System clock input
    input wire rst,                    // Reset signal
    input wire [6:0] addr,             // 7-bit address for target I2C slave
    input wire [7:0] data_in,          // Data to write to the slave (if applicable)
    input wire enable,                 // Enable signal to start communication
    input wire rw,                     // Read/Write control (0 = write, 1 = read)
    output reg [7:0] data_out,         // Data read from the slave (if applicable)
    output wire ready,                 // Ready signal (high when idle and ready for new command)
    inout i2c_sda,                     // I2C data line (bi-directional)
    inout wire i2c_scl,                // I2C clock line
    input wire [7:0] clock_stretch_delay // Delay duration for clock stretching
);

    // Define state machine states
    localparam IDLE = 0;
    localparam START = 1;
    localparam ADDRESS = 2;
    localparam READ_ACK = 3;
    localparam CLOCK_STRETCH = 4;
    localparam WRITE_DATA = 5;
    localparam WRITE_ACK = 6;
    localparam READ_DATA = 7;
    localparam READ_ACK2 = 8;
    localparam STOP = 9;

    // Parameters for clock divider
    localparam DIVIDE_BY = 4;

    // Internal registers and signals
    reg [7:0] state;                   // Current state of the FSM
    reg [7:0] saved_addr;              // Address register with RW bit
    reg [7:0] saved_data;              // Data register for write operation
    reg [7:0] counter;                 // Bit counter for address and data transfer
    reg [7:0] counter2 = 0;            // Clock divider counter
    reg write_enable;                  // Control SDA direction (1 = output, 0 = input)
    reg sda_out;                       // SDA line output value
    reg i2c_scl_enable = 0;            // Control for enabling/disabling SCL line
    reg i2c_clk = 1;                   // Internal I2C clock
    reg [7:0] clock_stretch_counter;   // Counter for clock stretching delay

    // Ready signal to indicate when the master is in IDLE state and ready for a new command
    assign ready = ((rst == 0) && (state == IDLE)) ? 1 : 0;

    // Control i2c_scl based on enable and clock states
    assign i2c_scl = (i2c_scl_enable == 0) ? 1 : i2c_clk;

    // Control i2c_sda direction based on write_enable signal
    assign i2c_sda = (write_enable == 1) ? sda_out : 'bz;

    // Clock divider for generating I2C clock from the system clock
    always @(posedge clk) begin
        if (counter2 == (DIVIDE_BY / 2) - 1) begin
            i2c_clk <= ~i2c_clk;       // Toggle internal I2C clock
            counter2 <= 0;
        end else begin
            counter2 <= counter2 + 1;
        end
    end

    // Control i2c_scl enable based on state
    always @(negedge i2c_clk or posedge rst) begin
        if (rst == 1) begin
            i2c_scl_enable <= 0;       // Disable SCL on reset
        end else begin
            // Enable SCL only in specific states
            if ((state == IDLE) || (state == START) || (state == STOP) || (state == CLOCK_STRETCH)) begin
                i2c_scl_enable <= 0;
            end else begin
                i2c_scl_enable <= 1;
            end
        end
    end

    // Main FSM controlling I2C operations with clock stretching
    always @(posedge i2c_clk or posedge rst) begin
        if (rst == 1) begin
            state <= IDLE;
            clock_stretch_counter <= 0;
        end else begin
            case (state)
                
                // IDLE State: Wait for enable signal to initiate communication
                IDLE: begin
                    if (enable) begin
                        state <= START;
                        saved_addr <= {addr, rw};   // Save address with RW bit
                        saved_data <= data_in;      // Save data for write operation
                    end
                end

                // START Condition: Generate start signal
                START: begin
                    counter <= 7;                  // Initialize bit counter for address
                    state <= ADDRESS;              // Move to address state
                end

                // ADDRESS: Transmit address and RW bit
                ADDRESS: begin
                    if (counter == 0) begin 
                        state <= READ_ACK;         // Move to read ACK state
                    end else begin
                        counter <= counter - 1;    // Decrement counter
                    end
                end

                // READ_ACK: Check for ACK from slave after sending address
                READ_ACK: begin
                    if (i2c_sda == 0) begin        // ACK received
                        state <= CLOCK_STRETCH;    // Move to clock stretching state
                        clock_stretch_counter <= clock_stretch_delay; // Initialize delay counter
                    end else begin
                        state <= STOP;             // NACK received, move to STOP
                    end
                end

                // CLOCK_STRETCH: Hold SCL low to simulate clock stretching
                CLOCK_STRETCH: begin
                    if (clock_stretch_counter == 0) begin
                        state <= (saved_addr[0] == 0) ? WRITE_DATA : READ_DATA;
                        counter <= 7;              // Reset bit counter for data transfer
                    end else begin
                        clock_stretch_counter <= clock_stretch_counter - 1;
                    end
                end

                // WRITE_DATA: Transmit data to slave
                WRITE_DATA: begin
                    if (counter == 0) begin
                        state <= READ_ACK2;        // Move to second ACK state
                    end else begin
                        counter <= counter - 1;
                    end
                end

                // READ_ACK2: Check for second ACK
                READ_ACK2: begin
                    if ((i2c_sda == 0) && (enable == 1)) begin
                        state <= IDLE;
                    end else begin
                        state <= STOP;
                    end
                end

                // READ_DATA: Receive data from slave
                READ_DATA: begin
                    data_out[counter] <= i2c_sda;
                    if (counter == 0) begin
                        state <= WRITE_ACK;
                    end else begin
                        counter <= counter - 1;
                    end
                end

                // WRITE_ACK: Send ACK after reading data
                WRITE_ACK: begin
                    state <= STOP;
                end

                // STOP: Generate stop condition and return to IDLE
                STOP: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // SDA output control based on current FSM state
    always @(negedge i2c_clk or posedge rst) begin
        if (rst == 1) begin
            write_enable <= 1;          // SDA as output on reset
            sda_out <= 1;               // SDA high on reset
        end else begin
            case (state)
                
                START: begin
                    write_enable <= 1;   // Generate START condition by pulling SDA low
                    sda_out <= 0;
                end
                
                ADDRESS: begin
                    sda_out <= saved_addr[counter]; // Transmit each address bit
                end
                
                READ_ACK: begin
                    write_enable <= 0;   // Release SDA for ACK from slave
                end

                CLOCK_STRETCH: begin
                    write_enable <= 0;   // Hold SDA during clock stretch
                end
                
                WRITE_DATA: begin 
                    write_enable <= 1;   // Output each data bit
                    sda_out <= saved_data[counter];
                end
                
                WRITE_ACK: begin
                    write_enable <= 1;   // Send ACK after reading
                    sda_out <= 0;
                end
                
                READ_DATA: begin
                    write_enable <= 0;   // Release SDA for data read
                end
                
                STOP: begin
                    write_enable <= 1;   // Release SDA after STOP
                    sda_out <= 1;
                end
            endcase
        end
    end

endmodule

