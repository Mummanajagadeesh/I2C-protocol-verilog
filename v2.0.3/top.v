`timescale 1ns / 1ps

// Top module to integrate i2c_master and i2c_slave instances
// This module coordinates the master and slave modules to simulate an I2C communication setup.

module top(
    input wire clk,                // System clock input
    input wire rst,                // System reset input
    input wire [6:0] addr,         // Address input for I2C master to communicate with the slave
    input wire [7:0] data_in,      // Data input to be sent by the I2C master
    input wire enable,             // Enable signal to start I2C communication
    input wire rw,                 // Read/Write control (0 = Write, 1 = Read)
    output wire [7:0] data_out,    // Data output received by the I2C master from the slave
    output wire ready,             // Ready signal from the I2C master indicating idle state
    inout wire i2c_sda,            // I2C SDA (data) line, bidirectional
    inout wire i2c_scl             // I2C SCL (clock) line, bidirectional
);

    // Internal register to hold the slave's address (7-bit I2C address format)
    reg [6:0] slave_address = 7'b0101011;  // Example address for testing (0x2B)

    // Instantiate the i2c_slave module
    i2c_slave slave_inst (
        .addr_in(slave_address),  // Slave address set in the top module
        .sda(i2c_sda),            // SDA line connected to both master and slave
        .scl(i2c_scl)             // SCL line connected to both master and slave
    );

    // Instantiate the i2c_master module
    i2c_master master_inst (
        .clk(clk),                // System clock to synchronize the master
        .rst(rst),                // System reset to initialize master states
        .addr(addr),              // Address provided to master, to be checked with slave
        .data_in(data_in),        // Data to be sent by the master to the slave
        .enable(enable),          // Enable signal to start the I2C transaction
        .rw(rw),                  // Read/Write signal (0 = Write to slave, 1 = Read from slave)
        .data_out(data_out),      // Data received by master if a read operation
        .ready(ready),            // Ready flag, high when master is idle
        .i2c_sda(i2c_sda),        // SDA line shared with slave
        .i2c_scl(i2c_scl)         // SCL line shared with slave
    );

endmodule
