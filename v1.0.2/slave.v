module i2c_slave(
    input [6:0] addr_in,   // Slave address to respond to (dynamic address input)
    inout sda,             // I2C data line (SDA) - bidirectional
    inout scl              // I2C clock line (SCL)
);

    // Define states for the I2C slave FSM
    localparam READ_ADDR = 0;   // State for reading the address from the master
    localparam SEND_ACK = 1;    // State for sending ACK after receiving a matching address
    localparam READ_DATA = 2;   // State for reading data from the master
    localparam WRITE_DATA = 3;  // State for sending data to the master
    localparam SEND_ACK2 = 4;   // State for sending ACK after receiving data from the master

    reg [7:0] addr;             // Register to store the address received from the master
    reg [7:0] counter;          // Bit counter for data/address transmission
    reg [7:0] state = 0;        // Current state of the FSM
    reg [7:0] data_in = 0;      // Register to store data received from the master
    reg [7:0] data_out = 8'b11001100;  // Data to be sent to the master in read mode
    reg sda_out = 0;            // Data to drive onto SDA when write_enable is high
    reg sda_in = 0;             // Register to capture SDA input data
    reg start = 0;              // Flag to indicate the start condition (SDA goes low while SCL is high)
    reg write_enable = 0;       // Controls whether the slave drives the SDA line

    // Tri-state SDA line: driven by sda_out when write_enable is high, otherwise high-impedance
    assign sda = (write_enable == 1) ? sda_out : 'bz;

    // Detect start condition on SDA falling edge when SCL is high
    always @(negedge sda) begin
        if ((start == 0) && (scl == 1)) begin
            start <= 1;           // Set start flag
            counter <= 7;         // Initialize counter to read 8 bits (address or data)
        end
    end

    // Detect stop condition on SDA rising edge when SCL is high
    always @(posedge sda) begin
        if ((start == 1) && (scl == 1)) begin
            state <= READ_ADDR;   // Go to READ_ADDR state to read the address from master
            start <= 0;           // Clear start flag
            write_enable <= 0;    // Release SDA line
        end
    end

    // State machine for I2C slave behavior, triggered on rising edge of SCL
    always @(posedge scl) begin
        if (start == 1) begin     // Only proceed if start condition was detected
            case(state)
                
                READ_ADDR: begin
                    addr[counter] <= sda;      // Capture address bit from SDA
                    if(counter == 0) begin
                        state <= SEND_ACK;     // Move to SEND_ACK after receiving full address
                    end else begin
                        counter <= counter - 1; // Count down to receive 8 bits
                    end
                end
                
                SEND_ACK: begin
                    // Check if received address matches slave address (addr_in)
                    if(addr[7:1] == addr_in) begin
                        counter <= 7;          // Reset bit counter for next data frame
                        // Determine next state based on R/W bit (addr[0])
                        if(addr[0] == 0) begin 
                            state <= READ_DATA; // If R/W=0, master wants to write, go to READ_DATA
                        end else begin
                            state <= WRITE_DATA; // If R/W=1, master wants to read, go to WRITE_DATA
                        end
                    end else begin
                        state <= READ_ADDR;    // Address mismatch, go back to READ_ADDR
                    end
                end
                
                READ_DATA: begin
                    data_in[counter] <= sda;   // Capture data bit from SDA
                    if(counter == 0) begin
                        state <= SEND_ACK2;    // Move to SEND_ACK2 after receiving full byte
                    end else begin
                        counter <= counter - 1; // Count down to receive 8 bits
                    end
                end
                
                SEND_ACK2: begin
                    state <= READ_ADDR;        // Go back to READ_ADDR to listen for next address
                end
                
                WRITE_DATA: begin
                    // Transmit data_out to master one bit at a time
                    if(counter == 0) begin
                        state <= READ_ADDR;    // After last bit, go back to READ_ADDR
                    end else begin
                        counter <= counter - 1; // Count down for each bit sent
                    end
                end
                
            endcase
        end
    end

    // Control SDA output behavior on falling edge of SCL, depending on the state
    always @(negedge scl) begin
        case(state)
            
            READ_ADDR: begin
                write_enable <= 0;           // Release SDA while reading address
            end
            
            SEND_ACK: begin
                sda_out <= (addr[7:1] == addr_in) ? 0 : 1; // Send ACK (low) if address matches, else NACK (high)
                write_enable <= 1;           // Enable SDA to drive ACK/NACK
            end
            
            READ_DATA: begin
                write_enable <= 0;           // Release SDA while reading data
            end
            
            WRITE_DATA: begin
                sda_out <= data_out[counter]; // Send each bit of data_out on SDA
                write_enable <= 1;           // Enable SDA to drive data
            end
            
            SEND_ACK2: begin
                sda_out <= 0;                // Send ACK (low) after receiving data
                write_enable <= 1;           // Enable SDA to drive ACK
            end
        endcase
    end
endmodule
