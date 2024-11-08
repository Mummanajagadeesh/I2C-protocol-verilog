
---

# Version 2.0.3

This I2C protocol implementation (v2.0.3) consists of four modules: `i2c_master`, `i2c_slave`, `top`, and `i2c_controller_tb` (testbench). This document provides a brief description of each module, as well as a specific explanation of how clock stretching is implemented in the master module.

---

## Module Overview

### 1. **i2c_master Module**

The `i2c_master` module simulates the behavior of an I2C master device. It generates I2C signals on the `i2c_scl` (clock) and `i2c_sda` (data) lines to communicate with an I2C slave.

#### Key Features
- **State Machine**: Implements a finite state machine (FSM) to manage different phases of I2C communication, including IDLE, START, ADDRESS, READ_ACK, WRITE_DATA, READ_DATA, and STOP.
- **Address and Data Handling**: Accepts a 7-bit address and an 8-bit data payload. The `rw` input determines whether the transaction is a read or a write.
- **Clock Stretching**: Implements a predefined clock-stretching phase after address transmission, allowing the master to wait for the slave's response.
- **Ready Signal**: Provides a `ready` output signal to indicate when the master is in the IDLE state and ready for a new transaction.

---

### 2. **i2c_slave Module**

The `i2c_slave` module simulates the behavior of an I2C slave device. It listens for an I2C address from the master and sends or receives data based on the master’s request.

#### Key Features
- **State Machine**: Utilizes an FSM to manage its response to the master’s requests. Key states include READ_ADDR, SEND_ACK, READ_DATA, WRITE_DATA, and SEND_ACK2.
- **Address Matching**: Contains an address register that is compared with the master’s address to verify if it’s the intended slave.
- **Data Transfer**: Receives data when in read mode and sends data when in write mode.
- **ACK/NACK Responses**: Provides ACK/NACK signals depending on whether the slave recognizes the address and whether the data transfer is successful.

---

### 3. **Top Module**

The `top` module integrates the `i2c_master` and `i2c_slave` modules to set up an I2C communication environment. This module serves as a test interface, connecting the master and slave via shared `i2c_sda` and `i2c_scl` lines.

#### Key Features
- **Shared Communication Lines**: Connects both the master and slave to the same SDA and SCL lines, as they would be in a real I2C setup.
- **Static Slave Address**: Sets a predefined address (`7'b0101011`) for the slave, which the master can match in its transactions.
- **Test Signals**: Passes key control and data signals to the master, such as `enable` to start communication, `addr` for the address to be checked, `data_in` for data transfer, and `rw` for read/write selection.

---

### 4. **i2c_controller_tb Module**

The `i2c_controller_tb` module serves as a testbench for the `top` module. This module simulates the I2C environment and verifies correct operation of master-slave communication by controlling and monitoring signals.

#### Key Features
- **Clock Generation**: Generates a clock signal to drive the I2C master.
- **Test Sequence**: Initializes inputs, simulates a write transaction, and observes the behavior of the `top` module.
- **Waveform Capture**: Generates a VCD file for waveform analysis, which can be used to verify the timing and behavior of the I2C transactions.

---

## Clock Stretching Implementation in `i2c_master`

Clock stretching is an I2C feature allowing the slave device to hold the SCL line low when it needs more time to process data. The `i2c_master` module in this implementation includes a predefined clock-stretching state, `CLOCK_STRETCH`, that simulates this behavior.

### How Clock Stretching Works in `i2c_master`

1. **Clock Stretching State**: The state machine in `i2c_master` includes a `CLOCK_STRETCH` state. When the master enters this state, it holds the SCL line low for a specified duration (in this case, defined by `clock_stretch_delay`).
   
2. **Clock Stretch Delay**: The variable `clock_stretch_delay` sets a predefined delay for the clock-stretching duration. This delay simulates the time a real slave might need to process data and prepare for the next frame.

3. **Automatic Transition**: After the clock-stretching period elapses, the master checks whether it should proceed with sending or receiving data based on the transaction type:
   - **Write Operation**: Transitions to `WRITE_DATA` if the master is writing to the slave.
   - **Read Operation**: Transitions to `READ_DATA` if the master is reading from the slave.

### Key Code Excerpts

Below is a code excerpt showing the `CLOCK_STRETCH` state in `i2c_master`:

```verilog
CLOCK_STRETCH: begin
    // Hold SCL low for clock stretching
    if (clock_stretch_delay == 0) begin
        state <= (saved_addr[0] == 0) ? WRITE_DATA : READ_DATA;
        counter <= 7;  // Reset the bit counter for data frame
    end else begin
        clock_stretch_delay <= clock_stretch_delay - 1;
    end
end
```

In this section:
- The `clock_stretch_delay` variable is decremented on each clock cycle.
- When `clock_stretch_delay` reaches zero, the master transitions to the next state based on the transaction type (write or read).
  
This predefined clock-stretching mechanism is used here to simulate a slave device holding the SCL line until it’s ready, thus verifying the master’s ability to handle stretched clock periods before data frames.

---
