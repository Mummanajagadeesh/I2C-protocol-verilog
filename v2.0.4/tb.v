// i2c_controller_tb.v
// Testbench for the I2C Master-Slave System using the top module
// It runs multiple test cycles to validate data exchange and varying clock stretch delay functionality.

`timescale 1ns / 1ps
module i2c_controller_tb();

    // Testbench inputs
    reg clk;
    reg rst;
    reg [6:0] addr;                  // Address sent from master
    reg [7:0] data_in;               // Data input to master for write operation
    reg enable;                      // Enable signal for master operation
    reg rw;                          // Read/Write signal (0 = Write, 1 = Read)
    reg [7:0] clock_stretch_delay;   // Adjustable clock stretch delay

    // Testbench outputs
    wire [7:0] data_out;             // Data received by the master
    wire ready;                      // Ready signal indicating master availability

    // Bidirectional lines
    wire i2c_sda;                    // Shared SDA line
    wire i2c_scl;                    // Shared SCL line

    // Instantiate the top module to integrate master and slave
    top uut (
        .clk(clk),
        .rst(rst),
        .addr(addr),
        .data_in(data_in),
        .enable(enable),
        .rw(rw),
        .data_out(data_out),
        .ready(ready),
        .i2c_sda(i2c_sda),
        .i2c_scl(i2c_scl),
        .clock_stretch_delay(clock_stretch_delay)  // Pass delay configuration
    );

    // Clock generation (1ns high, 1ns low -> 2ns period)
    initial begin
        clk = 0;
        forever #1 clk = ~clk;  // Toggle clock every 1ns
    end

    // Test sequence
    initial begin
        $dumpfile("i2c_controller_tb.vcd");
        $dumpvars(0, i2c_controller_tb);

        // Initialize inputs
        rst = 1;
        enable = 0;
        addr = 7'b0101010;          // Address matching the slave's
        data_in = 8'b10101010;      // Example data to be written
        rw = 0;                     // Write operation
        clock_stretch_delay = 8'd10;  // Initial clock stretch delay

        // Release reset after initialization
        #10;
        rst = 0;

        // Cycle 1: Write operation with initial clock stretch delay
        enable = 1;                 // Start I2C communication
        #20 enable = 0;             // End enable signal

        // Observe response with the first clock stretch delay
        #100;

        // Cycle 2: Change clock stretch delay to test flexibility
        clock_stretch_delay = 8'd50;  // Increase clock stretch delay

        // Start another communication to observe new delay
        enable = 1;
        #20 enable = 0;

        // Wait to observe second cycle with adjusted clock stretch
        #200;

        // Cycle 3: Test with minimal clock stretch delay
        clock_stretch_delay = 8'd1;

        // Start another communication with minimal delay
        enable = 1;
        #20 enable = 0;

        // Wait to capture final interactions
        #600;
        $finish;
    end

endmodule
