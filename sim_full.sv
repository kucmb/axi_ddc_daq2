`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
import axi_vip_pkg::*;
import system_axi_vip_0_0_pkg::*;

module sim_full(

    );
    
    parameter STEP_SYS = 100;
    parameter STEP_DEV = 40;
    
    reg clk_100MHz;
    reg reset;
    reg [63:0] data_in;
    reg [13:0] k_in;
    reg valid_in;
    wire [79:0] data_out_0;
    reg dev_clk;
    wire [6:0] index_out_0;
    wire valid_out_0;
    integer fd_plan;
    integer fd_data;
    integer fd_k;
    localparam PLAN_PATH = "./plan_1.bin";
    localparam DATA_PATH = "./data_1.bin";
    localparam K_PATH = "./k_1.bin";
    reg [13:0] k_plan;
    reg [63:0] data_f;
    reg [13:0] k_f;
    
    system_wrapper dut(.*);
    
    system_axi_vip_0_0_mst_t  vip_agent;
    
    
    task clk_gen();
        clk_100MHz = 0;
        forever #(STEP_SYS/2) clk_100MHz = ~clk_100MHz;
    endtask
    
    task clk_gen_dev();
        dev_clk = 0;
        forever #(STEP_DEV/2) dev_clk = ~dev_clk;
    endtask
    
    task rst_gen();
        reset = 1;
        data_in = 0;
        k_in = 0;
        valid_in = 0;
        k_plan = 0;
        #(STEP_SYS*10);
        reset = 0;
    endtask
    
    task file_open();
        fd_plan = $fopen(PLAN_PATH, "r");
        fd_data = $fopen(DATA_PATH, "r");
        fd_k = $fopen(K_PATH, "r");
        if ((fd_plan == 0) | (fd_data == 0) | (fd_k == 0)) begin               
            $display("File Open Error!!!!!");
            $finish;
        end else begin
            $display("File Open OK");
        end
    endtask
    
    axi_transaction wr_transaction;
    axi_transaction rd_transaction;
    
    initial begin : START_system_axi_vip_0_0_MASTER
        fork
            clk_gen();
            clk_gen_dev();
            rst_gen();
            file_open();
        join_none
        
        #(STEP_SYS*100);
    
        vip_agent = new("my VIP master", sim_full.dut.system_i.axi_vip_0.inst.IF);
        vip_agent.start_master();
        #(STEP_SYS*100);
        wr_transaction = vip_agent.wr_driver.create_transaction("write transaction");
        
        for (int i=0; i < 128; i++) begin
            wr_transaction.set_write_cmd(0, XIL_AXI_BURST_TYPE_INCR, 0, 0, xil_axi_size_t'(xil_clog2((32)/8)));
            $fscanf(fd_plan, "%b\n", k_plan);
            wr_transaction.set_data_block({4'b0 , 2'b0, k_plan});
            vip_agent.wr_driver.send(wr_transaction);
            if($feof(fd_plan) != 0)begin
                $display("File End !!");
                break;
            end
        end

        wr_transaction.set_write_cmd(4, XIL_AXI_BURST_TYPE_INCR, 0, 0, xil_axi_size_t'(xil_clog2((32)/8)));
        wr_transaction.set_data_block(32'd1);
        vip_agent.wr_driver.send(wr_transaction);
        
        #(STEP_SYS*500);
        
        // read transaction
        rd_transaction   = vip_agent.rd_driver.create_transaction("read transaction");
        rd_transaction.set_read_cmd(12, XIL_AXI_BURST_TYPE_INCR, 0, 0, xil_axi_size_t'(xil_clog2((32)/8)));
        vip_agent.rd_driver.send(rd_transaction);
        
        #(STEP_SYS*500);
                
        #(STEP_SYS*100);

        wr_transaction.set_write_cmd(16, XIL_AXI_BURST_TYPE_INCR, 0, 0, xil_axi_size_t'(xil_clog2((32)/8)));
        wr_transaction.set_data_block(32'd2);
        vip_agent.wr_driver.send(wr_transaction);


        #(STEP_SYS*100);
        
//        wr_transaction.set_write_cmd(16, XIL_AXI_BURST_TYPE_INCR, 0, 0, xil_axi_size_t'(xil_clog2((32)/8)));
//        wr_transaction.set_data_block(32'd2);
//        vip_agent.wr_driver.send(wr_transaction);

        #(STEP_SYS*10);
        
        rd_transaction.set_read_cmd(16, XIL_AXI_BURST_TYPE_INCR, 0, 0, xil_axi_size_t'(xil_clog2((32)/8)));
        vip_agent.rd_driver.send(rd_transaction);

        #(STEP_SYS*100);
//        for (int i=0; i < 128*64; i++) begin
//            data_in <= {32'b0, i[31:0]};
//            k_in <= i[6:0];
//            valid_in <= 1;
//            #(STEP_DEV);
//        end
       
        forever begin
            $fscanf(fd_data, "%b\n", data_f);
            $fscanf(fd_k, "%b\n", k_f);
            data_in <= data_f;
            k_in <= k_f;
            valid_in <= 1;
            #(STEP_DEV);
            if($feof(fd_data) != 0)begin
                $display("File End !!");
                break;
            end
        end
       
       #(STEP_SYS*1000);
       
        $finish;
    end
endmodule
