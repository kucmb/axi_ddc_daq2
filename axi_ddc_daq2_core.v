
`timescale 1 ns / 1 ps

    module axi_ddc_daq2_core #
    (
        parameter integer C_S_AXI_DATA_WIDTH	= 32,
        parameter integer C_S_AXI_ADDR_WIDTH	= 5
    )
    (
        // Users to add ports here
        input wire dev_clk,
        input wire dev_rst,
        input wire rd_en_first,
        input wire rd_en_second,
        output wire [6:0] index_first,
        output wire [13:0] k_first,
        output wire [6:0] index_second,
        output wire [3:0] k_second,
        output wire bypass_second,

        output wire [31:0] dout_mon,
        // User ports ends

        // Global Clock Signal
        input wire  S_AXI_ACLK,
        input wire  S_AXI_ARESETN,

        input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
        // Write channel Protection type. This signal indicates the
            // privilege and security level of the transaction, and whether
            // the transaction is a data access or an instruction access.
        input wire [2 : 0] S_AXI_AWPROT,
        input wire  S_AXI_AWVALID,
        output wire  S_AXI_AWREADY,
        input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
        input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
        input wire  S_AXI_WVALID,
        output wire  S_AXI_WREADY,

        output wire [1 : 0] S_AXI_BRESP,
        output wire  S_AXI_BVALID,
        input wire  S_AXI_BREADY,
        
        input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
        input wire [2 : 0] S_AXI_ARPROT,
        input wire  S_AXI_ARVALID,
        output wire  S_AXI_ARREADY,
        output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
        output wire [1 : 0] S_AXI_RRESP,
        output wire  S_AXI_RVALID,
        input wire  S_AXI_RREADY
    );

    //////////////////////////////////////////////// Signal definitions
    // AXI4LITE signals
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
    reg                             axi_awready;
    reg                             axi_wready;
    reg [1 : 0]                     axi_bresp;
    reg                             axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
    reg                             axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
    reg [1 : 0]                     axi_rresp;
    reg                             axi_rvalid;

    localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
    localparam integer OPT_MEM_ADDR_BITS = 2;

    reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg0; // Used to fill the ring buffer for frequency selectors
    reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg1; // Address for random access to the blockram in the ring buffer
    // reg2 does not exist
    // reg3 does not exist
    // reg4 does not exist
    reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg5;
    reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg6;
    reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg7;
    wire                            slv_reg_rden;
    wire                            slv_reg_wren;
    reg [C_S_AXI_DATA_WIDTH-1:0]    reg_data_out;
    integer                         byte_index;

    ////////////////////////////////////////////// User signals
    reg                             aw_en_org;  // Original aw_en that appears in the template
    wire                            aw_en;      // Expanded aw_en that waits user_wbusy deasserted
    wire                            user_wbusy;
    wire                            user_rbusy;
    wire [7:0]                      ring_count;
    reg [31:0]                      rr_data_buf; // Used in bram random access logic
    wire [31:0]                     user_status;
    reg                             soft_reset;

    /////////////// status registers
    reg                             bypass_second_reg;
    assign dout_mon = {dout_second, 2'b00, dout_first};
    

    //////////////////////////////////////////////// AXI logics
    assign S_AXI_AWREADY    = axi_awready;
    assign S_AXI_WREADY     = axi_wready;
    assign S_AXI_BRESP      = axi_bresp;
    assign S_AXI_BVALID     = axi_bvalid;
    assign S_AXI_ARREADY    = axi_arready;
    assign S_AXI_RDATA      = axi_rdata;
    assign S_AXI_RRESP      = axi_rresp;
    assign S_AXI_RVALID     = axi_rvalid;

    ////////////////////// WRITE
    always @( posedge S_AXI_ACLK )
    begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_awready <= 1'b0;
        end else begin
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
                axi_awready <= 1'b1;
            else if (S_AXI_BREADY && axi_bvalid)
               axi_awready <= 1'b0;
            else
               axi_awready <= 1'b0;
        end
    end

    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            aw_en_org <= 1'b1;
        end else begin
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
                aw_en_org <= 1'b0;
            else if (S_AXI_BREADY && axi_bvalid)
                aw_en_org <= 1'b1;
        end
    end

    // Deactivate write transaction if the user logic is busy
    assign aw_en = aw_en_org & (~user_wbusy);

    // axi_awaddr latching
    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 )
            axi_awaddr <= 0;
        else begin
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) 
                axi_awaddr <= S_AXI_AWADDR;
        end
    end

    // axi_wready generation
    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 )
            axi_wready <= 1'b0;
        else begin
            if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
                axi_wready <= 1'b1;
            else
                axi_wready <= 1'b0;
        end 
    end

    assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            slv_reg0 <= 0;
            slv_reg1 <= 0;
            bypass_second_reg <= 0;
            soft_reset <= 0;
            slv_reg5 <= 0;
            slv_reg6 <= 0;
            slv_reg7 <= 0;
        end else begin
            if (slv_reg_wren) begin
                case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
                3'h0:
                    for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                        if ( S_AXI_WSTRB[byte_index] == 1 )
                            slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                3'h1:
                    for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                        if ( S_AXI_WSTRB[byte_index] == 1 )
                            slv_reg1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                3'h4:
                    if ( S_AXI_WSTRB[0] == 1) begin // first 8 bits
                        if ( S_AXI_WDATA[0] == 1 ) begin // software reset
                            soft_reset <= 1;
                        end else begin
                            bypass_second_reg <= S_AXI_WDATA[1];
                        end
                    end
                3'h5:
                    for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                        if ( S_AXI_WSTRB[byte_index] == 1 )
                            slv_reg5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                3'h6:
                    for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                        if ( S_AXI_WSTRB[byte_index] == 1 )
                            slv_reg6[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                3'h7:
                    for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                        if ( S_AXI_WSTRB[byte_index] == 1 )
                            slv_reg7[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                default : begin
                    slv_reg0 <= slv_reg0;
                    slv_reg1 <= slv_reg1;
                    bypass_second_reg <= bypass_second_reg;
                    soft_reset <= 0;
                    slv_reg5 <= slv_reg5;
                    slv_reg6 <= slv_reg6;
                    slv_reg7 <= slv_reg7;
                end
                endcase
            end else begin
                soft_reset <= 0;
            end
        end
    end

    // write response logic generation
    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_bvalid  <= 0;
            axi_bresp   <= 2'b0;
        end else begin
            if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
                // indicates a valid write response is available
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b0; // 'OKAY' response 
            end else begin
                if (S_AXI_BREADY && axi_bvalid) 
                    axi_bvalid <= 1'b0; 
            end
        end
    end   

    ////////////////////// READ
    // axi_arready generation
    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_arready <= 1'b0;
            axi_araddr  <= 32'b0;
        end else begin    
            if (~axi_arready && S_AXI_ARVALID && ~user_rbusy) begin
                axi_arready <= 1'b1;
                axi_araddr  <= S_AXI_ARADDR;
            end else begin
                axi_arready <= 1'b0;
            end
        end
    end

    // axi_arvalid generation
    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            axi_rvalid <= 0;
            axi_rresp  <= 0;
        end else begin    
            if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp  <= 2'b0;
            end else if (axi_rvalid && S_AXI_RREADY)
                axi_rvalid <= 1'b0;
        end
    end

    assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
    always @(*) begin
        case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
            3'h0   : reg_data_out <= slv_reg0;
            3'h1   : reg_data_out <= slv_reg1;
            3'h2   : reg_data_out <= rr_data_buf;
            3'h3   : reg_data_out <= ring_count;
            3'h4   : reg_data_out <= user_status;
            3'h5   : reg_data_out <= slv_reg5;
            3'h6   : reg_data_out <= slv_reg6;
            3'h7   : reg_data_out <= slv_reg7;
            default : reg_data_out <= 0;
        endcase
    end

    // Output register or memory read data
    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 )
            axi_rdata  <= 0;
        else begin if (slv_reg_rden)
            axi_rdata <= reg_data_out;
        end
    end

    /////////////////////////////////////////////////////////////////// User logic
    wire [13:0] din_first;
    wire [3:0]  din_second;
    wire [13:0] dout_first;
    wire [3:0] dout_second;
    wire wr_en_ring;
    wire ready_ring;
    wire [6:0] rand_rd_addr;
    wire rand_rd_en;
    wire rand_rd_valid;

    wire index_busy;	
    reg index_busy_reg; // S_AXI_ACLK
    wire rr_busy;
    reg rr_busy_reg;
    wire soft_reset_dev;
    wire sr_busy;

    wire [OPT_MEM_ADDR_BITS:0] wch = axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB];
    //////////// reg0: index register
     // buffering
    wire index_written = (wch == 0) & axi_bvalid;
    wire iw_pos_edge;
    reg iw_buf_0;
    reg iw_buf_1;
    reg iw_fin;
    
    assign user_wbusy = index_busy | rr_busy | sr_busy;
    assign user_rbusy = index_busy | rr_busy | sr_busy;
    
    always @(posedge S_AXI_ACLK) begin
       if ( S_AXI_ARESETN == 1'b0 ) begin
           index_busy_reg <= 1'b0;
       end else begin
           if (index_written)
               index_busy_reg <= 1'b1;
           else if (iw_fin)
               index_busy_reg <= 1'b0;
       end
    end
    assign index_busy = (index_written) | index_busy_reg;
    
    // change detection
    always @(posedge dev_clk) begin
       if (dev_rst) begin
           iw_buf_0 <= 0;
           iw_buf_1 <= 0;
       end else begin
           iw_buf_0 <= index_written;
           iw_buf_1 <= iw_buf_0;
       end
    end

    always @(posedge dev_clk) begin
       if (dev_rst) begin
           iw_fin <= 1'b0;
       end else begin
           if (index_busy) begin
               if (iw_pos_edge) begin
                   iw_fin <= 1'b1;
               end else
                   iw_fin <= iw_fin;
           end else
               iw_fin <= 1'b0;
       end
    end

    assign iw_pos_edge = (iw_buf_0 == 1'b1) & (iw_buf_1 == 1'b0);
    assign wr_en_ring = iw_pos_edge;
    assign din_first    = slv_reg0[13:0];
    assign din_second   = slv_reg0[19:16];

    //////////// reg1: random access address
    wire rr_addr_written = (wch == 1) & axi_bvalid;
    wire rr_fin;
    
    
    reg [6:0] rr_addr_buf;
    reg [2:0] rr_counter;

    // random read busy
    always @(posedge S_AXI_ACLK) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            rr_busy_reg <= 1'b0;
        end else begin
            if (rr_addr_written)
                rr_busy_reg <= 1'b1;
            else if (rr_fin)
                rr_busy_reg <= 1'b0;
        end
    end

    assign rr_busy = rr_addr_written | rr_busy_reg;

    // random read stage
    assign rr_fin = (rr_counter == 3'd5);
    always @(posedge dev_clk) begin
        if (dev_rst) begin
            rr_counter <= 3'b0;
        end else begin
            if (rr_busy_reg) begin
                if (rr_counter != 3'd5)
                    rr_counter <= rr_counter + 3'b1;
                else
                    rr_counter <= rr_counter;
            end else
                rr_counter <= 3'b0;
        end
    end

    always @(posedge dev_clk) begin
        if (dev_rst) begin
            rr_addr_buf <= 7'b0;
        end else begin
            rr_addr_buf <= slv_reg1;
        end
    end

    assign rand_rd_addr = rr_addr_buf;

    always @(posedge dev_clk) begin
        if (dev_rst) begin
            rr_data_buf <= 32'b0;
        end else begin
            if (rr_counter == 3'd4) begin
                rr_data_buf <= {dout_second, 2'b0, dout_first};
            end
        end
    end

    assign rand_rd_en = (rr_counter == 3'd1);

    //////////// reg2: random access data (read only)
    // Read access to BASE_ADDR + 0x08 

    //////////// reg3: number of data in the ring buffer (read only)
    // Read access to BASE_ADDR + 0x0C

    //////////// reg4: status
    // software reset of ring buffers
    reg sr_busy_reg;
    wire sr_dev_edge;
    wire sr_fin;
    reg sr_dev_buf_0;
    reg sr_dev_buf_1;
    assign sr_busy = soft_reset | sr_busy_reg;

    always @(posedge S_AXI_ACLK) begin
        if ( S_AXI_ARESETN == 1'b0 ) begin
            sr_busy_reg <= 0;
        end else begin
            if (soft_reset) begin
                sr_busy_reg <= 1;
            end else if (sr_fin) begin
                sr_busy_reg <= 0;
            end
        end
    end

    always @(posedge dev_clk) begin
        if (dev_rst) begin
            sr_dev_buf_0 <= 0;
            sr_dev_buf_1 <= 0;
        end else begin
            sr_dev_buf_0 <= sr_busy;
            sr_dev_buf_1 <= sr_dev_buf_0;
        end
    end

    assign sr_dev_edge = (sr_dev_buf_0 == 1) && (sr_dev_buf_1 == 0);
    assign sr_fin = (sr_dev_buf_1 == 1);
    assign soft_reset_dev = sr_dev_edge;
    assign bypass_second = bypass_second_reg;
    assign user_status = {29'b0, ready_ring, bypass_second_reg, 1'b0};


    ring_rand ring_first(
        .clk(dev_clk),
        .rst(dev_rst | soft_reset_dev),
        .din(din_first),
        .wr_en(wr_en_ring),
        .dout(dout_first),
        .rd_en(rd_en_first),
        .ready(ready_ring),
        .index(index_first),
        .count(ring_count),
        // random access
        .rand_rd_addr(rand_rd_addr),
        .rand_rd_en(rand_rd_en),
        .rand_rd_valid(rand_rd_valid)
    );

    ring_rand_second ring_second(
        .clk(dev_clk),
        .rst(dev_rst | soft_reset_dev),
        .din(din_second),
        .wr_en(wr_en_ring),
        .dout(dout_second),
        .rd_en(rd_en_second),
        .index(index_second),
        .rand_rd_addr(rand_rd_addr),
        .rand_rd_en(rand_rd_en)
    );

    assign k_first = dout_first;
    assign k_second = dout_second;

    // User logic ends

    endmodule
