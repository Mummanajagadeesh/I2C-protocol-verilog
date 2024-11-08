// i2c_slave.v
// I2C Slave Module
// This module implements an I2C slave that can read an address, receive data from the master,
// and respond with data when requested. It also handles ACK/NACK responses based on the 
// address match and supports both reading and writing operations from the master.

module i2c_slave(
    input [6:0] addr_in,  // Slave address (configured dynamically)
    inout sda,            // I2C data line (bi-directional)
    inout scl             // I2C clock line
);

    // Define state machine states
    localparam READ_ADDR = 0;   // State for reading the address from master
    localparam SEND_ACK = 1;    // State for sending ACK after address match
    localparam READ_DATA = 2;   // State for receiving data from master
    localparam WRITE_DATA = 3;  // State for sending data to master
    localparam SEND_ACK2 = 4;   // State for sending ACK after data reception

    // Internal registers and signals
    reg [7:0] addr;             // Internal register for received address
    reg [7:0] counter;          // Bit counter for address and data transfer
    reg [7:0] state = 0;        // Current state of the FSM
    reg [7:0] data_in = 0;      // Register to store received data from master
    reg [7:0] data_out = 8'b11001100; // Default data to send to master
    reg sda_out = 0;            // SDA output value
    reg sda_in = 0;             // Captured SDA input value
    reg start = 0;              // Start condition detected flag
    reg write_enable = 0;       // Control SDA direction (1 = output, 0 = input)

    // Assign SDA line based on write_enable signal
    assign sda = (write_enable == 1) ? sda_out : 'bz;

    // Detect START condition: SDA goes low while SCL is high
    always @(negedge sda) begin
        if ((start == 0) && (scl == 1)) begin
            start <= 1;         // START condition detected
            counter <= 7;       // Reset counter for address reading
        end
    end

    // Detect STOP condition: SDA goes high while SCL is high
    always @(posedge sda) begin
        if ((start == 1) && (scl == 1)) begin
            state <= READ_ADDR; // Move to READ_ADDR to prepare for the next communication
            start <= 0;         // Clear start flag
            write_enable <= 0;  // Release SDA for input
        end
    end

    // Main FSM to handle different I2C operations
    always @(posedge scl) begin
        if (start == 1) begin   // Execute only if START condition was detected
            case(state)

                // READ_ADDR: Receive address from master
                READ_ADDR: begin
                    addr[counter] <= sda; // Capture address bit by bit
                    if (counter == 0) state <= SEND_ACK; // Complete address, move to ACK state
                    else counter <= counter - 1;         // Decrement bit counter
                end

                // SEND_ACK: Send ACK/NACK based on address match
                SEND_ACK: begin
                    if (addr[7:1] == addr_in) begin      // Address match
                        counter <= 7;                    // Reset counter for data transfer
                        if (addr[0] == 0) begin 
                            state <= READ_DATA;          // If RW bit is 0, prepare to read data from master
                        end else begin
                            state <= WRITE_DATA;         // If RW bit is 1, prepare to send data to master
                        end
                    end else begin
                        state <= READ_ADDR;              // Address mismatch, restart to read next address
                    end
                end

                // READ_DATA: Receive data byte from master
                READ_DATA: begin
                    data_in[counter] <= sda;             // Capture data bit by bit
                    if (counter == 0) state <= SEND_ACK2; // Complete data, move to second ACK state
                    else counter <= counter - 1;
                end

                // SEND_ACK2: Send ACK after data reception
                SEND_ACK2: begin
                    state <= READ_ADDR;                  // Return to READ_ADDR after ACK
                end

                // WRITE_DATA: Transmit data byte to master
                WRITE_DATA: begin
                    if (counter == 0) state <= READ_ADDR; // Complete data transmission, go to READ_ADDR
                    else counter <= counter - 1;
                end
                
            endcase
        end
    end

    // Control SDA output based on current FSM state
    always @(negedge scl) begin
        case(state)
            
            // READ_ADDR: Release SDA for receiving address
            READ_ADDR: begin
                write_enable <= 0;            
            end
            
            // SEND_ACK: Send ACK/NACK after address match
            SEND_ACK: begin
                sda_out <= (addr[7:1] == addr_in) ? 0 : 1; // ACK if match, NACK if mismatch
                write_enable <= 1;           // Enable SDA output for ACK/NACK
            end
            
            // READ_DATA: Release SDA for receiving data
            READ_DATA: begin
                write_enable <= 0;
            end
            
            // WRITE_DATA: Send data bit by bit to master
            WRITE_DATA: begin
                sda_out <= data_out[counter]; // Output data bit
                write_enable <= 1;           // Enable SDA output
            end
            
            // SEND_ACK2: Send ACK after data reception
            SEND_ACK2: begin
                sda_out <= 0;                // Send ACK bit
                write_enable <= 1;           // Enable SDA output
            end

        endcase
    end
endmodule
