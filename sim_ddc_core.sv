`timescale 1ns / 1ps

module sim_ddc_core(
    );
    
    parameter STEP_SYS = 40;
    parameter SIM_LENGTH = 65536;

    // input
    logic [47:0] phase_in;
    logic valid_in;
    logic clk;
    logic [31:0] data_in;

    // Output
    logic valid_out;
    logic [63:0] ddc_out;
    logic [63:0]data_out;

    assign data_out = ddc_out;

    // Feed to DDS compiler
    logic [19:0] pinc;
    logic [19:0] poff;
    logic [19:0] pinc_x4;
    assign pinc_x4 = {pinc[17:0], 2'b0};
    assign phase_in = {4'b0, poff, 4'b0, pinc_x4};

    // Control data
    logic din_on;
    logic din_fin;
    logic write_on;

    // for output convention
    logic [31:0] i_out;
    logic [31:0] q_out;
    assign i_out = data_out[31:0];
    assign q_out = data_out[63:32];

    // write output
    integer fd_din;
    integer fd_dout;
    logic write_ready = 0;
    logic [$clog2(SIM_LENGTH)-1:0] counter = 0;
    logic finish = 0;

    // read setting
    integer fd_p;

    ddc_core dut(.*);

    task clk_gen();
        clk = 0;
        forever #(STEP_SYS/2) clk = ~clk;
    endtask
    
    task rst_gen();
        pinc = 0;
        poff = 0;
        din_on = 0;
        din_fin = 0;
        valid_in = 0;
        write_on = 0;
    endtask
    
    task file_open();
        fd_din = $fopen("./data_in.bin", "r");
        fd_dout = $fopen("./data_out.bin", "w");
        if ((fd_din == 0) | (fd_dout == 0)) begin
            $display("File open error.");
            $finish;
        end else begin
            $display("File open.");
            write_ready = 1;
        end
    endtask
    
    task p_setting_read();
        fd_p = $fopen("./p_setting.bin", "r");
        if (fd_p == 0) begin
            $display("p_setting open error.");
            $finish;
        end else begin
            $fscanf(fd_p, "%b\n", pinc);
            $fscanf(fd_p, "%b\n", poff);
            $fclose(fd_p);
        end
    endtask

    task file_close();
        if (write_ready) begin
            write_ready = 0;
            $fclose(fd_dout);
        end
    endtask
        
    initial begin
        fork
            clk_gen();
            rst_gen();
        join_none
        #(STEP_SYS*10);
        file_open();
        p_setting_read();

        #(STEP_SYS*10);
        @(posedge clk);
        valid_in <= 1;
        @(posedge clk);
        valid_in <= 0;
        repeat(7) @(posedge clk);
        din_on <= 1;
        repeat(7) @(posedge clk);
        write_on <= 1;
        @(posedge clk);
        wait(finish);

        valid_in <= 0;

        #(STEP_SYS*30);
        file_close();
        #(STEP_SYS*30);
        $finish;
    end
        
    always @(posedge clk) begin
        if (write_on && write_ready) begin
            if (~finish) begin
                $fdisplay(fd_dout, "%b", data_out);
                if (counter == (SIM_LENGTH - 1)) begin
                    finish <= 1;
                end else begin
                    counter <= counter + 1;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (din_on & ~din_fin) begin
            $fscanf(fd_din, "%b\n", data_in);
            if($feof(fd_din) != 0) begin
                $display("DIN fin");
                $fclose(fd_din);
                din_fin <= 1'b1;
            end
        end
    end

endmodule
