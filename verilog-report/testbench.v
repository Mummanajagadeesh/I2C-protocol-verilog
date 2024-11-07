module i2c_controller_tb();

    // Inputs
    reg clk;                  // System clock
    reg rst;                  // Reset signal
    reg [6:0] addr;           // Address for the master to communicate with
    reg [7:0] data_in;        // Data to be sent from the master to the slave
    reg enable;               // Enable signal to start communication
    reg rw;                   // Read/Write control (0 = Write, 1 = Read)

    // Outputs
    wire [7:0] data_out;      // Data received by the master from the slave
    wire ready;               // Ready signal indicating the master is ready for a new operation

    // Bidirectional wires
    wire i2c_sda;             // I2C data line (SDA) - shared between master and slave
    wire i2c_scl;             // I2C clock line (SCL) - shared between master and slave

    // Instantiate the Top Module (Device Under Test - DUT)
    top uut (
        .clk(clk),           // Connect system clock to DUT
        .rst(rst),           // Connect reset signal to DUT
        .addr(addr),         // Connect address input to DUT
        .data_in(data_in),   // Connect data to be sent by master to DUT
        .enable(enable),     // Connect enable signal to DUT
        .rw(rw),             // Connect read/write control to DUT
        .data_out(data_out), // Receive data read by master from DUT
        .ready(ready),       // Receive ready signal from DUT
        .i2c_sda(i2c_sda),   // Connect bidirectional SDA line
        .i2c_scl(i2c_scl)    // Connect bidirectional SCL line
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #1 clk = ~clk;  // Toggle clock every 1 ns to generate a 2 ns period clock (500 MHz)
    end

    // Test sequence to simulate I2C operations
    initial begin
        // Set up VCD file for waveform dumping
        $dumpfile("i2c_controller_tb.vcd");  // Name of the VCD file for waveform output
        $dumpvars(0, i2c_controller_tb);     // Dump all variables in this module for waveform analysis

        // Initialize Inputs
        rst = 1;           // Assert reset to initialize the system
        enable = 0;        // Initially disable communication
        addr = 7'b0000000; // Set an initial address (not used immediately)
        data_in = 8'b0;    // Set initial data (not used immediately)
        rw = 0;            // Set initial operation to write (0 = Write, 1 = Read)

        // Wait for reset to complete
        #10;
        rst = 0;           // Deassert reset after 10 ns to start normal operation

        // Test Case 1: Write operation with matching address (Expect ACK from slave)
        addr = 7'b0101010;       // Set address to match the slave address
        data_in = 8'b10101010;   // Data to be sent to the slave
        rw = 0;                  // Set operation to write
        enable = 1;              // Assert enable to start the I2C communication
        #20 enable = 0;          // Deassert enable after 20 ns to complete the command

        // Wait and observe response (slave should ACK the address and receive data)
        #100;

        // Test Case 2: Write operation with non-matching address (Expect NACK from slave)
        addr = 7'b1111111;       // Set address to a non-matching address for the slave
        data_in = 8'b11001100;   // Different data to be sent to the slave
        rw = 0;                  // Set operation to write
        enable = 1;              // Assert enable to start the I2C communication
        #20 enable = 0;          // Deassert enable after 20 ns

        // Wait and observe response (slave should NACK the address since it does not match)
        #100;

        // Test Case 3: Read operation with matching address (Expect ACK from slave and read data)
        addr = 7'b0101010;       // Set address to match the slave address
        rw = 1;                  // Set operation to read
        enable = 1;              // Assert enable to start the I2C communication
        #20 enable = 0;          // Deassert enable after 20 ns

        // Wait and observe response (slave should ACK the address and send data to master)
        #100;

        #200
        $finish;  // End the simulation after 200 ns
    end

endmodule