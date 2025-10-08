
`default_nettype none
module tt_um_BLE_RX (
// gate-level sim power pin (ignored in RTL sim) (according to)
`ifdef GL_TEST
    input  wire VPWR,
    input  wire VGND,
`endif
    // Tiny Tapeout user interface
    input  wire [7:0] ui_in,    // dedicated inputs
    output wire [7:0] uo_out,   // dedicated outputs
    input  wire [7:0] uio_in,   // bidir inputs
    output wire [7:0] uio_out,  // bidir outputs
    output wire [7:0] uio_oe,   // bidir enables (1=drive)
    input  wire       ena,      // design selected (optional)
    input  wire       clk,      // system clock
    input  wire       rst_n     // active-low reset
);
    // Unused bidirectional outputs for now
    assign uio_out = { 2'b00, I_Debug, 2'b00 };      // [7:6]=00, [5:2]=I_Debug, [1:0]=00
    assign uio_oe  = { 2'b00, 4'b1111, 2'b00 };      // enable only bits [5:2]

    wire rst = rst_n;

    // Map TT pins to TOP ports
    wire [1:0] select = uio_in[1:0];  // mode
    wire [3:0] I_BPF  = ui_in[3:0]; // I on low nibble
    wire [3:0] Q_BPF  = ui_in[7:4]; // Q on high nibble


    // Wires for TOP outputs
    wire [2:0] LED;
    wire       update, value, clk_Debug;
    wire [3:0] I_Debug, Q_Debug;
    wire       packet_trigger, packet_detectedLED;

    // Instantiate existing top-level system
    TOP_RX u_top (
        .clk               (clk),
        .select            (select),
        .rst               (rst),
        .I_BPF             (I_BPF),
        .Q_BPF             (Q_BPF),
        .LED               (LED),
        .update            (update),
        .value             (value),
        .clk_Debug         (clk_Debug),
        .I_Debug           (I_Debug),
        .Q_Debug           (Q_Debug),
        .packet_trigger    (packet_trigger),
        .packet_detectedLED(packet_detectedLED)
    );

    // Expose useful status bits on Tiny Tapeout outputs:
    // [7:5]=LED[2:0], [4]=clk_Debug, [3]=update, [2]=value, [1]=packet_trigger, [0]=packet_detectedLED
    assign uo_out = { LED, clk_Debug, update, value, packet_trigger, packet_detectedLED };
    // Avoid unused warnings
    wire _unused = &{ena};
endmodule
