`timescale 1 ns / 1 ps

module ddc_core(
    input clk,

    // assuming [29:16] Q, [13:0] I
    input [31:0] data_in,
    input valid_in,
    input [47:0] phase_in

    output valid_out,
    // valid width: 29 each. [60:32] Q, [28:0] I
    output [63:0] ddc_out
);

    wire dds_valid;
    wire [31:0] dds_out;

    // Convention
    wire [13:0] cos_dds;
    wire [13:0] sin_dds;
    wire [13:0] cos_data;
    wire [13:0] sin_data;

    // Result of multiplication
    wire [27:0] coscos;
    wire [27:0] cossin;
    wire [27:0] sincos;
    wire [27:0] sinsin;

    // Result of sum
    wire [28:0] out_i;
    wire [28:0] out_q;
    
    // Valid buffering
    reg [5:0] valid_buf;

    assign cos_dds = dds_out[15:0];
    assign sin_dds = dds_out[29:16];
    assign cos_data = data_in[13:0];
    assign sin_data = data_in[29:16];

    assign data_out = {{3{out_q[28]}}, out_q, {3{out_i[28]}}, out_i};

    dds dds_inst(
        .aclk(clk),
        .s_axis_phase_tvalid(valid_in),
        .s_axis_phase_tdata(phase_in), // pinc [19:0], poff [43:24], 48 bit width
        .m_axis_data_tvalid(dds_valid),
        .m_axis_data_tdata(dds_out) // cos [13:0], sin [29:16], 32 bit width
    );

    // Valid
    always @(posedge clk) begin
        valid_buf <= {valid_buf[4:0], dds_valid};
    end
    assign valid_out = valid_buf[5]; 

    // Multiplier 14 x 14 -> 28
    multiplier coscos_mult(
        .clk(clk),
        .a(cos_data),
        .b(cos_dds),
        .p(coscos)
    );

    multiplier cossin_mult(
        .clk(clk),
        .a(cos_data),
        .b(sin_dds),
        .p(cossin)
    );

    multiplier sincos_mult(
        .clk(clk),
        .a(sin_data),
        .b(cos_dds),
        .p(sincos)
    );

    multiplier sinsin_mult(
        .clk(clk),
        .a(sin_data),
        .b(sin_dds),
        .p(sinsin)
    );

    // Adder 28 + 28 -> 29
    adder sum_i(
        .clk(clk),
        .a(coscos),
        .b(sinsin),
        .s(out_i)
    );

    subtracter sub_q(
        .clk(clk),
        .a(sincos),
        .b(cossin),
        .s(out_q)
    );

endmodule