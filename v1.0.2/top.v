`timescale 1ns / 1ps

// Top module to integrate i2c_master and i2c_slave
// Top module to integrate i2c_master and i2c_slave
module top(
    input wire clk,                 // System clock
    input wire rst,                 // Reset signal
    input wire [6:0] addr,          // 7-bit I2C address for the master to communicate with
    input wire [7:0] data_in,       // Data to be sent from the master to the slave
    input wire enable,              // Enable signal to initiate I2C communication
    input wire rw,                  // Read/Write signal (0 = Write, 1 = Read)
    output wire [7:0] data_out,     // Data received by the master from the slave
    output wire ready,              // Signal indicating the master is ready for a new operation
    inout wire i2c_sda,             // I2C data line (SDA) - bidirectional
    inout wire i2c_scl              // I2C clock line (SCL)
);

    // Internal register to store the address the slave will respond to.
    // This is the fixed address of the slave in this example.
    reg [6:0] slave_address = 7'b0101010;  // Example default slave address

    // Instantiate the I2C slave module
    i2c_slave slave_inst (
        .addr_in(slave_address),   // Provide the fixed slave address to the slave instance
        .sda(i2c_sda),             // Connect the slave's SDA line to the top-level SDA
        .scl(i2c_scl)              // Connect the slave's SCL line to the top-level SCL
    );

    // Instantiate the I2C master module
    i2c_master master_inst (
        .clk(clk),                 // Connect the system clock to the master
        .rst(rst),                 // Connect the reset signal to the master
        .addr(addr),               // Provide the I2C address the master should communicate with
        .data_in(data_in),         // Data to be sent to the slave (if writing)
        .enable(enable),           // Enable signal to start the I2C transaction
        .rw(rw),                   // Read/Write signal (0 = Write, 1 = Read)
        .data_out(data_out),       // Data received from the slave (if reading)
        .ready(ready),             // Master ready signal indicating it's idle or ready for a new transaction
        .i2c_sda(i2c_sda),         // Connect the master's SDA line to the top-level SDA
        .i2c_scl(i2c_scl)          // Connect the master's SCL line to the top-level SCL
    );

endmodule
