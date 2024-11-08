// Module: i2c_slave
// Description: Implements an I2C Slave device that can receive an address and handle read/write requests.
//              Supports dynamic addressing, acknowledgment, data read, and data write operations.

module i2c_slave(
    input [6:0] addr_in,   // I2C address assigned to the slave device
    inout sda,             // I2C data line (SDA)
    inout scl              // I2C clock line (SCL)
);
    
    // Define states in the I2C state machine
    localparam READ_ADDR = 0;      // State to receive the address from master
    localparam SEND_ACK = 1;       // State to send acknowledgment for address
    localparam READ_DATA = 2;      // State to receive data from master
    localparam WRITE_DATA = 3;     // State to send data to master
    localparam SEND_ACK2 = 4;      // State to send acknowledgment for data

    // Internal registers
    reg [7:0] addr;                // Stores the received 8-bit address and RW bit
    reg [7:0] counter;             // Bit counter for address/data transfer
    reg [7:0] state = 0;           // Current state of the I2C FSM
    reg [7:0] data_in = 0;         // Data received from the master
    reg [7:0] data_out = 8'b11001100; // Data to be sent to the master (preset value for testing)
    reg sda_out = 0;               // Data to be driven on SDA line
    reg sda_in = 0;                // Internal SDA input storage
    reg start = 0;                 // Start condition detection flag
    reg write_enable = 0;          // Controls output direction of SDA line

    // Control SDA line: driven by sda_out when write_enable is set, high impedance otherwise
    assign sda = (write_enable == 1) ? sda_out : 'bz;

    // Detect I2C start condition (falling edge on SDA when SCL is high)
    always @(negedge sda) begin
        if ((start == 0) && (scl == 1)) begin
            start <= 1;            // Indicate start condition
            counter <= 7;          // Initialize counter for address bits
        end
    end

    // Detect stop condition or end of address read (rising edge on SDA when SCL is high)
    always @(posedge sda) begin
        if ((start == 1) && (scl == 1)) begin
            state <= READ_ADDR;    // Move to address read state
            start <= 0;            // Reset start condition
            write_enable <= 0;     // Disable SDA output
        end
    end

    // I2C slave state machine operating on the rising edge of SCL
    always @(posedge scl) begin
        if (start == 1) begin      // Check if start condition is detected
            case(state)
                // READ_ADDR: Receive the 7-bit address and 1-bit read/write control from master
                READ_ADDR: begin
                    addr[counter] <= sda;       // Shift in address bit-by-bit
                    if(counter == 0) 
                        state <= SEND_ACK;      // Move to send ACK after receiving all address bits
                    else 
                        counter <= counter - 1; // Decrement counter for next bit
                end

                // SEND_ACK: Send acknowledgment if address matches or NACK if it doesn't
                SEND_ACK: begin
                    if(addr[7:1] == addr_in) begin // Match check on 7-bit address
                        counter <= 7;           // Reset counter for next data phase
                        if(addr[0] == 0) 
                            state <= READ_DATA;  // If write, move to READ_DATA
                        else 
                            state <= WRITE_DATA; // If read, move to WRITE_DATA
                    end else 
                        state <= READ_ADDR;      // Address mismatch, restart address reading
                end

                // READ_DATA: Receive data byte from master bit-by-bit
                READ_DATA: begin
                    data_in[counter] <= sda;    // Shift in data bit-by-bit
                    if(counter == 0) 
                        state <= SEND_ACK2;     // Move to send ACK after data received
                    else 
                        counter <= counter - 1; // Decrement counter for next bit
                end

                // SEND_ACK2: Acknowledge data reception
                SEND_ACK2: begin
                    state <= READ_ADDR;         // Return to READ_ADDR for next transaction
                end

                // WRITE_DATA: Send data byte to master bit-by-bit
                WRITE_DATA: begin
                    if(counter == 0) 
                        state <= READ_ADDR;     // Move back to READ_ADDR after transmission
                    else 
                        counter <= counter - 1; // Decrement counter for next bit
                end
            endcase
        end
    end

    // Control SDA output based on current state, triggered on the falling edge of SCL
    always @(negedge scl) begin
        case(state)
            // READ_ADDR: Prepare to read address, SDA in high-impedance state
            READ_ADDR: begin
                write_enable <= 0;             // Disable SDA output for address read
            end
            
            // SEND_ACK: Send ACK/NACK based on address match
            SEND_ACK: begin
                sda_out <= (addr[7:1] == addr_in) ? 0 : 1; // Send ACK (low) or NACK (high)
                write_enable <= 1;             // Enable SDA output for ACK/NACK
            end
            
            // READ_DATA: Prepare to read data, SDA in high-impedance state
            READ_DATA: begin
                write_enable <= 0;             // Disable SDA output for data reception
            end
            
            // WRITE_DATA: Transmit data to master
            WRITE_DATA: begin
                sda_out <= data_out[counter];  // Output data bit-by-bit
                write_enable <= 1;             // Enable SDA output for data transmission
            end
            
            // SEND_ACK2: Send acknowledgment for data received
            SEND_ACK2: begin
                sda_out <= 0;                  // Send ACK (low) after data reception
                write_enable <= 1;             // Enable SDA output for ACK
            end
        endcase
    end
endmodule
