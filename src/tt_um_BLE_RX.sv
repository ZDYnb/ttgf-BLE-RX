module tt_um_BLE_RX (
// gate-level sim power pin (ignored in RTL sim) (according to)
`ifdef GL_TEST
    input  logic VPWR,
    input  logic VGND,
`endif
    // Tiny Tapeout user interface
    input  logic [7:0] ui_in,    // dedicated inputs
    output logic [7:0] uo_out,   // dedicated outputs
    input  logic [7:0] uio_in,   // bidir inputs
    output logic [7:0] uio_out,  // bidir outputs
    output logic [7:0] uio_oe,   // bidir enables (1=drive)
    input  logic       ena,      // design selected (optional)
    input  logic       clk,      // system clock
    input  logic       rst_n     // active-low reset
);

    // No bidirectional I/O used
    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;


    // Map TT pins to TOP ports
    localparam int DATA_WIDTH = 4;
    logic [DATA_WIDTH-1:0] I_BPF;
    logic [DATA_WIDTH-1:0] Q_BPF;
    assign I_BPF = ui_in[3:0];   // I on low nibble
    assign Q_BPF = ui_in[7:4];   // Q on high nibble

    // Channel from uio_in[5:0]
    logic [5:0] channel = uio_in[5:0]; 

    // Outputs from the BLE CDR top
    logic demod_symbol;
    logic demod_symbol_clk;
    logic packet_detected;

    // Instantiate existing top-level system
ble_cdr #(
        .SAMPLE_RATE(16),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_top (
        .clk              (clk),
        .en               (ena),
        .resetn           (rst_n),

        .i_bpf            (I_BPF),
        .q_bpf            (Q_BPF),

        .demod_symbol     (demod_symbol),
        .demod_symbol_clk (demod_symbol_clk),

        .channel          (channel),
        .packet_detected  (packet_detected)
    );

    // Output mapping: [2]=packet_detected, [1]=symbol_clk, [0]=demod_symbol
    assign uo_out = {5'b0, packet_detected, demod_symbol_clk, demod_symbol};
    // Avoid unused warnings
    logic _unused = &{1'b0, uio_in[7:6]};
endmodule
