// Testbench for the Top Module
// This module simulates the behavior of the top-level design and tests the I2C master-slave communication.

module i2c_controller_tb();

    // Define input signals
    reg clk;                     // Clock signal for simulation
    reg rst;                     // Reset signal for master and slave initialization
    reg [6:0] addr;              // Address to be sent by the master to the slave
    reg [7:0] data_in;           // Data to be sent by the master to the slave
    reg enable;                  // Enable signal to initiate communication from the master
    reg rw;                      // Read/Write control signal (0 = Write, 1 = Read)

    // Define output signals
    wire [7:0] data_out;         // Data received by the master from the slave
    wire ready;                  // Ready flag indicating master is idle

    // Define bidirectional signals for I2C
    wire i2c_sda;                // I2C SDA line (bi-directional data line)
    wire i2c_scl;                // I2C SCL line (clock)

    // Instantiate the Top Module (Device Under Test)
    top uut (
        .clk(clk),               // Connect system clock
        .rst(rst),               // Connect reset signal
        .addr(addr),             // Connect address input
        .data_in(data_in),       // Connect data input
        .enable(enable),         // Connect enable signal to start transaction
        .rw(rw),                 // Connect read/write control signal
        .data_out(data_out),     // Connect data output to receive data from slave
        .ready(ready),           // Connect ready flag from master
        .i2c_sda(i2c_sda),       // Connect bidirectional SDA line
        .i2c_scl(i2c_scl)        // Connect bidirectional SCL line
    );

    // Clock generation process
    initial begin
        clk = 0;                 // Initial clock state
        forever #1 clk = ~clk;   // Toggle clock every 1ns (2ns period, 500MHz frequency)
    end

    // Test sequence
    initial begin
        // Setup for waveform output
        $dumpfile("i2c_controller_tb.vcd");   // VCD output file for waveform viewing
        $dumpvars(0, i2c_controller_tb);      // Dump all variables in the testbench module

        // Initialize Inputs
        rst = 1;                 // Assert reset to initialize system
        enable = 0;              // Disable communication initially
        addr = 7'b0101011;       // Address to be matched with the slave's address
        data_in = 8'b11101110;   // Example data to be written to slave
        rw = 0;                  // Write operation (rw = 0)

        // Wait for reset to propagate
        #10;
        rst = 0;                 // Deassert reset, system begins normal operation

        // Test Case: Initiate a write operation to slave
        enable = 1;              // Enable the master to start communication
        #20 enable = 0;          // Disable enable after 20ns, allowing transaction to complete

        // Wait for response from slave
        #100;                    // Wait to observe results

        // Terminate the simulation
        #500
        $finish;                 // End the testbench
    end

endmodule
