`timescale 1 ns / 1 ps

module ddc_quad(
    input clk,

    // assuming [29:16] Q, [13:0] I
    input [31:0] data_in_0,
    input [31:0] data_in_1,
    input [31:0] data_in_2,
    input [31:0] data_in_3,

    input [19:0] pinc,
    input [19:0] poff

);

    wire valid_in_dds = 1'b1;
    wire valid_out_ddc;

    wire [19:0] poff_0;
    wire [19:0] poff_1;
    wire [19:0] poff_2;
    wire [19:0] poff_3;

    wire [31:0] dds_out_0;
    wire [31:0] dds_out_1;
    wire [31:0] dds_out_2;
    wire [31:0] dds_out_3;

    wire [63:0] ddc_out_0;
    wire [63:0] ddc_out_1;
    wire [63:0] ddc_out_2;
    wire [63:0] ddc_out_3;

    wire [19:0] pinc_x4;


    // Phase increment and offset calculation for quad-mode operation
    assign pinc_x4 = {pinc[17:0], 2'b0};
    assign poff_0 = poff;


    // DDC instantiation
    ddc_core ddc_0(
        .clk(clk),
        .data_in(data_in_0),
        .valid_in(valid_in_dds),
        .phase_in({4'b0, poff_0, 4'b0, pinc_x4}),
        .valid_out(valid_out_ddc),
        .ddc_out(ddc_out_0)
    );

    ddc_core ddc_1(
        .clk(clk),
        .data_in(data_in_1),
        .valid_in(valid_in_dds),
        .phase_in({4'b0, poff_1, 4'b0, pinc_x4}),
        .ddc_out(ddc_out_1)
    );

    ddc_core ddc_2(
        .clk(clk),
        .data_in(data_in_2),
        .valid_in(valid_in_dds),
        .phase_in({4'b0, poff_2, 4'b0, pinc_x4}),
        .ddc_out(ddc_out_2)
    );

    ddc_core ddc_0(
        .clk(clk),
        .data_in(data_in_3),
        .valid_in(valid_in_dds),
        .phase_in({4'b0, poff_3, 4'b0, pinc_x4}),
        .ddc_out(ddc_out_3)
    );

endmodule
