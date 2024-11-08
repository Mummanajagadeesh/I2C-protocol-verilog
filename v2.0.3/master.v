`timescale 1ns / 1ps

// Module: i2c_master
// Description: Implements an I2C Master for communication with I2C slave devices.
//              Supports basic operations such as start, stop, read, write, and clock stretching.
module i2c_master(
    input wire clk,                 // System clock
    input wire rst,                 // Active-high reset signal
    input wire [6:0] addr,          // 7-bit I2C address of the slave device
    input wire [7:0] data_in,       // Data to be written to the slave
    input wire enable,              // Start transaction when asserted
    input wire rw,                  // Read/Write control: 1 for read, 0 for write
    output reg [7:0] data_out,      // Data read from the slave
    output wire ready,              // Ready signal, asserted when the bus is idle
    inout i2c_sda,                  // I2C data line (SDA)
    inout wire i2c_scl              // I2C clock line (SCL)
);

    // Define states in the I2C state machine
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

    // Clock divider for generating I2C clock frequency
    localparam DIVIDE_BY = 4;

    // State and data registers
    reg [7:0] state;                // Current state of the I2C FSM
    reg [7:0] saved_addr;           // Holds the I2C address with read/write bit
    reg [7:0] saved_data;           // Holds the data to be written to the slave
    reg [7:0] counter;              // Bit counter for address/data transfer
    reg [7:0] counter2 = 0;         // Counter for clock division
    reg write_enable;               // Controls output direction of SDA line
    reg sda_out;                    // Data to be driven on SDA line
    reg i2c_scl_enable = 0;         // Enable signal for SCL line
    reg i2c_clk = 1;                // I2C clock generated from system clock
    reg [7:0] clock_stretch_delay;  // Delay counter for clock stretching

    // Indicate ready status when the state machine is idle and reset is not active
    assign ready = ((rst == 0) && (state == IDLE)) ? 1 : 0;

    // Control SCL line: high when disabled, follows generated clock otherwise
    assign i2c_scl = (i2c_scl_enable == 0) ? 1 : i2c_clk;

    // Control SDA line: driven by sda_out when write_enable is set, high impedance otherwise
    assign i2c_sda = (write_enable == 1) ? sda_out : 'bz;

    // I2C clock divider: generate I2C clock by dividing system clock frequency
    always @(posedge clk) begin
        if (counter2 == (DIVIDE_BY / 2) - 1) begin
            i2c_clk <= ~i2c_clk;    // Toggle I2C clock at half the divide value
            counter2 <= 0;          // Reset counter
        end else 
            counter2 <= counter2 + 1; // Increment counter
    end

    // Control enable for I2C clock based on state
    always @(negedge i2c_clk or posedge rst) begin
        if (rst == 1) begin
            i2c_scl_enable <= 0;   // Disable clock if reset
        end else begin
            // Enable SCL for data transfer and disable during idle, start, stop, or clock stretch
            if ((state == IDLE) || (state == START) || (state == STOP) || (state == CLOCK_STRETCH)) begin
                i2c_scl_enable <= 0;
            end else begin
                i2c_scl_enable <= 1;
            end
        end
    end

    // State machine for I2C master, implementing start, address, data transfer, and stop conditions
    always @(posedge i2c_clk or posedge rst) begin
        if (rst == 1) begin
            state <= IDLE;                      // Initialize state to IDLE on reset
            clock_stretch_delay <= 0;           // Reset clock stretch delay
        end else begin
            case (state)
                // IDLE: Wait for enable signal to start transaction
                IDLE: begin
                    if (enable) begin
                        state <= START;         // Move to START condition
                        saved_addr <= {addr, rw}; // Prepare address with read/write bit
                        saved_data <= data_in;   // Save data to be transmitted
                        clock_stretch_delay <= 8'd20; // Set delay for clock stretching
                    end
                end

                // START: Initiate I2C start condition by pulling SDA low
                START: begin
                    counter <= 7;              // Initialize counter for address bits
                    state <= ADDRESS;          // Move to ADDRESS state
                end

                // ADDRESS: Transmit the 7-bit address and RW bit
                ADDRESS: begin
                    if (counter == 0) begin 
                        state <= READ_ACK;      // Move to ACK read after address
                    end else 
                        counter <= counter - 1; // Decrement counter for next bit
                end

                // READ_ACK: Check for acknowledgment from the slave
                READ_ACK: begin
                    if (i2c_sda == 0) begin    // ACK received (SDA pulled low)
                        state <= CLOCK_STRETCH; // Move to clock stretching
                    end else 
                        state <= STOP;         // NACK received, end transaction
                end

                // CLOCK_STRETCH: Hold SCL low for a specified delay
                CLOCK_STRETCH: begin
                    if (clock_stretch_delay == 0) begin
                        // If write, move to WRITE_DATA; if read, move to READ_DATA
                        state <= (saved_addr[0] == 0) ? WRITE_DATA : READ_DATA;
                        counter <= 7;           // Reset bit counter
                    end else 
                        clock_stretch_delay <= clock_stretch_delay - 1; // Decrement delay
                end

                // WRITE_DATA: Transmit data to slave bit-by-bit
                WRITE_DATA: begin
                    if (counter == 0) begin
                        state <= READ_ACK2;      // After all bits sent, expect ACK
                    end else 
                        counter <= counter - 1;  // Decrement bit counter
                end

                // READ_ACK2: Check for acknowledgment after data write
                READ_ACK2: begin
                    if ((i2c_sda == 0) && (enable == 1)) 
                        state <= IDLE;           // End transaction on ACK
                    else 
                        state <= STOP;           // Go to stop on NACK
                end

                // READ_DATA: Read data bits from slave and save to data_out
                READ_DATA: begin
                    data_out[counter] <= i2c_sda; // Capture each data bit
                    if (counter == 0) 
                        state <= WRITE_ACK;      // Move to ACK after reading data
                    else 
                        counter <= counter - 1;  // Decrement counter
                end

                // WRITE_ACK: Acknowledge read to the slave
                WRITE_ACK: begin
                    state <= STOP;               // Move to stop condition
                end

                // STOP: Release SDA line to signal end of transmission
                STOP: begin
                    state <= IDLE;               // Return to idle state
                end
            endcase
        end
    end

    // Control SDA output based on current state
    always @(negedge i2c_clk or posedge rst) begin
        if (rst == 1) begin
            write_enable <= 1;                   // SDA in output mode initially
            sda_out <= 1;                        // Set SDA high initially
        end else begin
            case (state)
                START: begin
                    write_enable <= 1;           // SDA output mode for start
                    sda_out <= 0;                // SDA low for start condition
                end

                ADDRESS: begin
                    sda_out <= saved_addr[counter]; // Output address bits
                end

                READ_ACK: begin
                    write_enable <= 0;           // Switch to input mode to read ACK
                end

                CLOCK_STRETCH: begin
                    write_enable <= 0;           // Input mode during clock stretching
                end

                WRITE_DATA: begin
                    write_enable <= 1;           // Output mode for data
                    sda_out <= saved_data[counter]; // Transmit data bits
                end

                WRITE_ACK: begin
                    write_enable <= 1;           // Output mode to send ACK
                    sda_out <= 0;                // ACK bit (SDA low)
                end

                READ_DATA: begin
                    write_enable <= 0;           // Input mode to read data
                end

                STOP: begin
                    write_enable <= 1;           // Output mode for stop condition
                    sda_out <= 1;                // SDA high to release bus
                end
            endcase
        end
    end

endmodule
