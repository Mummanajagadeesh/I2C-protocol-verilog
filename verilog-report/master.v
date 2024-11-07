module i2c_master(
    input wire clk,                // System clock
    input wire rst,                // Reset signal
    input wire [6:0] addr,         // 7-bit I2C slave address
    input wire [7:0] data_in,      // Data to send to slave in write mode
    input wire enable,             // Start signal for I2C communication
    input wire rw,                 // Read/Write control (0 for write, 1 for read)
    output reg [7:0] data_out,     // Data received from slave in read mode
    output wire ready,             // Indicates when the master is ready for a new transaction
    inout i2c_sda,                 // I2C data line (SDA) - bidirectional
    inout wire i2c_scl             // I2C clock line (SCL) - bidirectional
);

    // Define states for I2C master FSM
    localparam IDLE = 0;
    localparam START = 1;
    localparam ADDRESS = 2;
    localparam READ_ACK = 3;
    localparam WRITE_DATA = 4;
    localparam WRITE_ACK = 5;
    localparam READ_DATA = 6;
    localparam READ_ACK2 = 7;
    localparam STOP = 8;

    localparam DIVIDE_BY = 4;      // Clock divider to generate I2C clock from system clock

    reg [7:0] state;               // Current state of the FSM
    reg [7:0] saved_addr;          // Stores the 7-bit address and RW bit for the current transaction
    reg [7:0] saved_data;          // Data to be sent in write transactions
    reg [7:0] counter;             // Bit counter for data/address transmission
    reg [7:0] counter2 = 0;        // Divider counter for generating i2c_clk
    reg write_enable;              // Controls whether the master drives SDA line
    reg sda_out;                   // Data to output on SDA line when write_enable is 1
    reg i2c_scl_enable = 0;        // Controls the state of the i2c_scl line (enabled or high)
    reg i2c_clk = 1;               // Internal I2C clock signal

    // Ready signal is high when the master is idle and not in reset
    assign ready = ((rst == 0) && (state == IDLE)) ? 1 : 0;

    // I2C SCL signal: High when i2c_scl_enable is low; otherwise, driven by i2c_clk
    assign i2c_scl = (i2c_scl_enable == 0) ? 1 : i2c_clk;

    // SDA line is driven by sda_out when write_enable is high; otherwise, it's in high-impedance
    assign i2c_sda = (write_enable == 1) ? sda_out : 'bz;

    // I2C clock divider: Divides system clock to generate i2c_clk
    always @(posedge clk) begin
        if (counter2 == (DIVIDE_BY / 2) - 1) begin
            i2c_clk <= ~i2c_clk;    // Toggle i2c_clk when half period is reached
            counter2 <= 0;          // Reset the divider counter
        end else begin
            counter2 <= counter2 + 1; // Increment the divider counter
        end
    end

    // Enable/disable I2C clock based on current state
    always @(negedge i2c_clk or posedge rst) begin
        if (rst == 1) begin
            i2c_scl_enable <= 0;    // Disable SCL on reset
        end else begin
            if ((state == IDLE) || (state == START) || (state == STOP)) begin
                i2c_scl_enable <= 0; // SCL is disabled in IDLE, START, and STOP states
            end else begin
                i2c_scl_enable <= 1; // Enable SCL in other states
            end
        end
    end

    // State machine for controlling the I2C master operation
    always @(posedge i2c_clk or posedge rst) begin
        if (rst == 1) begin
            state <= IDLE;          // Reset state to IDLE on reset
        end else begin
            case (state)
                
                IDLE: begin
                    if (enable) begin
                        state <= START;  // Start I2C transaction when enable is high
                        saved_addr <= {addr, rw};  // Save the 7-bit address and RW bit
                        saved_data <= data_in;     // Save the data to be sent (in write mode)
                    end
                end

                START: begin
                    counter <= 7;          // Initialize bit counter to 7 for 8-bit transmission
                    state <= ADDRESS;      // Move to ADDRESS state
                end

                ADDRESS: begin
                    if (counter == 0) begin 
                        state <= READ_ACK;  // Move to ACK check after sending address and RW bit
                    end else begin
                        counter <= counter - 1;  // Transmit address bits, count down
                    end
                end

                READ_ACK: begin
                    if (i2c_sda == 0) begin  // ACK received (SDA pulled low by slave)
                        counter <= 7;       // Reset bit counter
                        if (saved_addr[0] == 0) state <= WRITE_DATA; // If RW=0, go to write mode
                        else state <= READ_DATA;                     // If RW=1, go to read mode
                    end else begin
                        state <= STOP;      // NACK received, move to STOP state
                    end
                end

                WRITE_DATA: begin
                    if (counter == 0) begin
                        state <= READ_ACK2; // Move to second ACK check after data transmission
                    end else begin
                        counter <= counter - 1; // Transmit data bits, count down
                    end
                end

                READ_ACK2: begin
                    if ((i2c_sda == 0) && (enable == 1)) state <= IDLE; // Return to IDLE on ACK
                    else state <= STOP;  // If NACK received or enable low, go to STOP
                end

                READ_DATA: begin
                    data_out[counter] <= i2c_sda;  // Capture data bit from SDA line
                    if (counter == 0) state <= WRITE_ACK; // After last bit, go to WRITE_ACK
                    else counter <= counter - 1; // Count down for each bit received
                end

                WRITE_ACK: begin
                    state <= STOP;  // Go to STOP after sending ACK
                end

                STOP: begin
                    state <= IDLE;  // Go back to IDLE after STOP condition
                end
            endcase
        end
    end

    // SDA output logic based on the current state
    always @(negedge i2c_clk or posedge rst) begin
        if (rst == 1) begin
            write_enable <= 1;       // Drive SDA high on reset
            sda_out <= 1;
        end else begin
            case (state)
                
                START: begin
                    write_enable <= 1;  // Enable SDA for start condition
                    sda_out <= 0;       // Pull SDA low for start condition
                end
                
                ADDRESS: begin
                    sda_out <= saved_addr[counter]; // Send each bit of the address and RW bit
                end
                
                READ_ACK: begin
                    write_enable <= 0;  // Release SDA to allow slave to drive ACK/NACK
                end
                
                WRITE_DATA: begin 
                    write_enable <= 1;  // Enable SDA for data transmission
                    sda_out <= saved_data[counter]; // Output each bit of data to SDA
                end
                
                WRITE_ACK: begin
                    write_enable <= 1;  // Enable SDA for ACK transmission
                    sda_out <= 0;       // Send ACK by pulling SDA low
                end
                
                READ_DATA: begin
                    write_enable <= 0;  // Release SDA to read data from slave
                end
                
                STOP: begin
                    write_enable <= 1;  // Enable SDA for stop condition
                    sda_out <= 1;       // Release SDA to indicate stop
                end
            endcase
        end
    end

endmodule