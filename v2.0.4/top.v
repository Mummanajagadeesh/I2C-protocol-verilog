// top.v
// Top Module integrating the i2c_master and i2c_slave modules
// This module sets up a simple I2C master-slave communication system
// and allows the I2C master to address, read, and write data to the slave.

`timescale 1ns / 1ps

module top(
    input wire clk,                  // System clock
    input wire rst,                  // System reset
    input wire [6:0] addr,           // Address to be used by the master
    input wire [7:0] data_in,        // Data to be sent from the master
    input wire enable,               // Enable signal to start communication
    input wire rw,                   // Read/Write control signal (0 = Write, 1 = Read)
    output wire [7:0] data_out,      // Data received by the master from slave
    output wire ready,               // Ready signal indicating master is ready
    inout wire i2c_sda,              // I2C data line (SDA)
    inout wire i2c_scl,              // I2C clock line (SCL)
    input wire [7:0] clock_stretch_delay  // Adjustable clock stretch delay for master
);

    // Slave's address to be matched by the master
    reg [6:0] slave_address = 7'b0101010;  // Default slave address

    // Instantiate the I2C slave with predefined address
    i2c_slave slave_inst (
        .addr_in(slave_address),  // Address to check against master's address
        .sda(i2c_sda),
        .scl(i2c_scl)
    );

    // Instantiate the I2C master
    i2c_master master_inst (
        .clk(clk),
        .rst(rst),
        .addr(addr),              // Master input address to be checked against the slave's
        .data_in(data_in),        // Data sent by master
        .enable(enable),          // Master enable signal
        .rw(rw),                  // Master Read/Write signal
        .data_out(data_out),      // Data received by master from slave
        .ready(ready),            // Ready signal from master
        .i2c_sda(i2c_sda),        // I2C SDA line shared between master and slave
        .i2c_scl(i2c_scl),        // I2C SCL line shared between master and slave
        .clock_stretch_delay(clock_stretch_delay)  // Configurable clock stretching delay
    );

endmodule
