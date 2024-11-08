# Version 2.0.4

This version of the I2C Controller System integrates a master-slave communication system with configurable clock stretching. The clock stretching feature is controlled via the Testbench (TB) module, allowing testing of master-slave communication under different clock delays.

## Overview
The system consists of three major modules:
1. **i2c_master**: Controls the master-side behavior of I2C communication.
2. **i2c_slave**: Handles the slave-side behavior, receiving data or responding to commands from the master.
3. **top**: Integrates both the master and slave modules, allowing communication via shared SDA and SCL lines.
4. **Testbench (i2c_controller_tb)**: Simulates and tests the I2C communication by adjusting the clock stretch delay and triggering communication cycles.

## Modules and Their Functions

### i2c_master
The `i2c_master` module simulates the behavior of an I2C master, managing the I2C bus and controlling the transmission and reception of data. Key components and behavior include:

- **Inputs**:
    - `clk`: Clock input (used for generating the clock signal for the master and controlling state transitions).
    - `rst`: Reset signal to initialize the master’s state machine.
    - `addr`: 7-bit address to identify the slave device.
    - `data_in`: 8-bit data to be transmitted to the slave.
    - `enable`: Signal to enable communication.
    - `rw`: Read/Write signal (0 = Write, 1 = Read).
    - `clock_stretch_delay`: Adjustable clock stretch delay in cycles (increased or decreased for testing).
  
- **Outputs**:
    - `data_out`: 8-bit data received from the slave during a read operation.
    - `ready`: Indicates whether the master is ready to start a new operation.
    - `i2c_sda`: Bi-directional data line (SDA) for I2C communication.
    - `i2c_scl`: Clock line (SCL) for I2C communication.

- **Key Functionalities**:
    - The master handles starting the communication, addressing the slave, sending or receiving data, and handling ACK/NACK signals.
    - Clock stretching is controlled via `clock_stretch_delay`, which adjusts the duration of SCL high periods, forcing the master to wait for the slave to process or prepare data.
    - The state machine inside the master controls transitions based on the current phase of the communication (e.g., addressing, sending data, receiving data).

### i2c_slave
The `i2c_slave` module simulates the behavior of the I2C slave. It listens for communication from the master, processes the data, and responds accordingly. Key components and behavior include:

- **Inputs**:
    - `addr_in`: 7-bit address of the slave device, which the master must match during communication.
    - `sda`: The bi-directional data line (SDA) shared between master and slave.
    - `scl`: The clock line (SCL) shared between master and slave.
  
- **Outputs**:
    - `sda`: Bi-directional data line used by the slave for reading and writing data to/from the master.

- **Key Functionalities**:
    - The slave listens to the SDA line for communication initiated by the master.
    - It first receives the address from the master and compares it to its own `addr_in`. If they match, it either prepares to send data or receive data depending on the `rw` signal from the master.
    - The slave handles acknowledging (ACK) or not acknowledging (NACK) based on address matching and readiness for data transfer.

### top
The `top` module integrates the `i2c_master` and `i2c_slave` modules, making it the central hub for I2C communication. It routes signals between the master and slave and allows external inputs for address, data, and control.

- **Inputs**:
    - `clk`: Global clock signal.
    - `rst`: Global reset signal.
    - `addr`: Address to be checked by the master during communication.
    - `data_in`: Data to be transmitted from the master to the slave.
    - `enable`: Enables the communication process.
    - `rw`: Read/Write signal from the master (0 = Write, 1 = Read).
    - `clock_stretch_delay`: Configurable clock stretch delay for master.

- **Outputs**:
    - `data_out`: Data received by the master (only in read operations).
    - `ready`: Indicates if the master is ready to start a new operation.
    - `i2c_sda`: Shared I2C data line.
    - `i2c_scl`: Shared I2C clock line.

- **Functionality**:
    - The `top` module connects the master and slave and controls the overall operation of the I2C communication system.
    - It initializes the slave with a predefined address (though this can be adjusted in real use cases) and passes communication signals between the slave and master.
    - The `top` module also handles the configuration of clock stretching by passing the `clock_stretch_delay` value from the Testbench to the master module.

### i2c_controller_tb (Testbench)
The Testbench (`i2c_controller_tb`) simulates the master-slave communication process, verifying that the system behaves as expected under different clock stretch delays. It allows dynamic control of the `clock_stretch_delay` input, which is passed to the `top` module.

- **Testbench Inputs**:
    - `clk`: Clock signal for the simulation.
    - `rst`: Reset signal for the simulation.
    - `addr`: Address to be used by the master to communicate with the slave.
    - `data_in`: Data for the master to send to the slave.
    - `enable`: Enable signal to initiate the communication.
    - `rw`: Read/Write signal.
    - `clock_stretch_delay`: Configurable delay value for clock stretching.

- **Testbench Outputs**:
    - `data_out`: Data received from the slave by the master during read operations.
    - `ready`: Signals when the master is ready for the next operation.

- **Key Functionality**:
    - The Testbench initializes the simulation and generates the clock signal.
    - It tests the I2C communication system by toggling the `enable` signal and adjusting the `clock_stretch_delay` to observe how the system behaves under different timing conditions.
    - Multiple communication cycles are run with different clock stretch delays to evaluate the master-slave interaction under various scenarios.

### Key Features of Version 2.0.4
1. **Clock Stretching**: 
   - The clock stretching functionality is controlled dynamically via the Testbench. The delay is applied by the master to pause the clock while the slave prepares data or responds.
   - The `clock_stretch_delay` input allows simulation of different I2C timing scenarios, useful for testing real-world devices with varying response times.
  
2. **Flexible Testbench**:
   - The Testbench provides a configurable environment where the `clock_stretch_delay` can be adjusted to simulate different slave timing characteristics.
   - It also runs multiple test cases with varying delays to ensure robustness and flexibility in master-slave communication.

## System Flow

1. **Master Initialization**:
   - The master waits for the `enable` signal and then starts communication, addressing the slave and sending data based on the `rw` signal (Write or Read).
   - If clock stretching is required, the master will hold the clock low for the configured `clock_stretch_delay` cycles.

2. **Slave Response**:
   - The slave receives the address and checks it against its predefined address (`addr_in`).
   - If the address matches and the `rw` signal indicates a write, the slave prepares to receive data; if `rw` indicates a read, the slave sends the requested data.

3. **Clock Stretching**:
   - The master adjusts its clock based on the `clock_stretch_delay`. This simulates how the slave may require extra time to prepare data or process requests.
  
4. **Testbench Simulation**:
   - The Testbench simulates the entire communication by controlling the timing and clock stretching dynamically.
   - The master performs read/write operations, and the clock stretch delay is adjusted at runtime to test different scenarios.


