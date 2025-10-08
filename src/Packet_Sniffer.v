`timescale 1ns / 1ps
module Packet_Sniffer #(
    parameter PACKET_LEN_MAX = 376,
    parameter PREAMBLE_LEN = 8,
    parameter ACC_ADDR_LEN = 32,
    parameter CRC_POLY = 24'h00065B,
    parameter CRC_INIT = 24'h555555
)(
    input wire symbol_clk, rst, en, symbol_in,
    input wire [ACC_ADDR_LEN-1:0] acc_addr,
    input wire [5:0] channel,

    output reg packet_detected,
    output reg [PACKET_LEN_MAX-PREAMBLE_LEN-1:0] packet_out,
    output reg [8:0] packet_len
);

    // Internal state
    reg [PACKET_LEN_MAX-PREAMBLE_LEN-1:0] rx_buffer;
    reg [ACC_ADDR_LEN-1:0] rx_acc_addr;
    reg state, nextState;
    reg [8:0] bit_counter;
    reg packet_finished;
    wire dewhitened;
    wire crc_pass;
    wire acc_addr_matched;

    // RX buffer update
    always @(negedge symbol_clk or negedge rst) begin
        if (!rst)
            rx_buffer <= 0;
        else
            rx_buffer <= {rx_buffer[PACKET_LEN_MAX-PREAMBLE_LEN-2:0], (state ? dewhitened : symbol_in)};
    end

    // Access address shift register
    always @(posedge symbol_clk or negedge rst) begin
        if (!rst)
            rx_acc_addr <= 0;
        else
            rx_acc_addr <= {rx_acc_addr[ACC_ADDR_LEN-2:0], symbol_in};
    end

    assign acc_addr_matched = (rx_acc_addr == acc_addr);

    // Bit counter logic
    always @(negedge symbol_clk or negedge rst) begin
        if (!rst)
            bit_counter <= 0;
        else if (en) begin
            if (state)
                bit_counter <= bit_counter + 1;
            else
                bit_counter <= 0;
        end
    end

    // Packet finished check
    always @(*) begin
        packet_finished = (bit_counter == PACKET_LEN_MAX - PREAMBLE_LEN - ACC_ADDR_LEN);
        packet_detected = crc_pass && (bit_counter[2:0] == 3'b000);
    end
    
    // Save packet length when detected
    always @(posedge packet_detected or negedge rst) begin
        if (!rst)
            packet_len <= 0;
        else
            packet_len <= bit_counter + PREAMBLE_LEN + ACC_ADDR_LEN;
    end

    // Output mask for valid bits
    wire [PACKET_LEN_MAX-PREAMBLE_LEN-1:0] mask = (1 << packet_len) - 1;

    // Output data when packet is latched
    always @(posedge symbol_clk or negedge rst) begin
        if (!rst)
            packet_out <= 0;
        else if (packet_detected)
            packet_out <= rx_buffer & mask;
    end

    // FSM state logic
    always @(negedge symbol_clk or negedge rst) begin
        if (!rst)
            state <= 0;
        else if (en)
            state <= nextState;
    end

    always @(*) begin
        case (state)
            1'b0: nextState = acc_addr_matched && en;
            1'b1: nextState = ~(packet_detected || packet_finished) && en;
            default: nextState = 1'b0;
        endcase
    end

    // Dewhitening module
    dewhiten dw (
        .symbol_clk(symbol_clk),
        .en(state),
        .symbol_in(symbol_in),
        .dewhiten_init(channel),
        .symbol_out(dewhitened)
    );

    // CRC module
    crc #(.CRC_LEN(24)) chk (
        .symbol_clk(symbol_clk),
        .en(state),
        .dewhitened(dewhitened),
        .crc_pass(crc_pass),
        .crc_init(CRC_INIT),
        .crc_poly(CRC_POLY)
    );

endmodule

// Dewhitening module
module dewhiten (
    input wire symbol_clk, en, symbol_in,
    input wire [5:0] dewhiten_init,
    output reg symbol_out
);
    reg [6:0] lfsr;
    reg [6:0] next_lfsr;

    always @(posedge symbol_clk or negedge en) begin
        if (!en)
            lfsr <= {1'b1, dewhiten_init};
        else begin
            symbol_out <= symbol_in ^ lfsr[0];
            next_lfsr = {lfsr[0], lfsr[6:1]};
            next_lfsr[2] = next_lfsr[2] ^ lfsr[0];
            lfsr <= next_lfsr;
        end
    end
endmodule

// CRC module
module crc #(
    parameter CRC_LEN = 24
)(
    input wire symbol_clk, en,
    input wire dewhitened,
    output reg crc_pass,
    input wire [CRC_LEN-1:0] crc_init,
    input wire [CRC_LEN-1:0] crc_poly
);
    reg [CRC_LEN-1:0] crc_lfsr;
    reg msb, feedback;

    always @(negedge symbol_clk or negedge en) begin
        if (!en)
            crc_lfsr <= crc_init;
        else begin
            msb = crc_lfsr[CRC_LEN-1];
            feedback = msb ^ dewhitened;

            crc_lfsr <= {crc_lfsr[CRC_LEN-2:0], 1'b0};
            if (feedback)
                crc_lfsr <= ({crc_lfsr[CRC_LEN-2:0], 1'b0}) ^ crc_poly;
        end
    end

    always @(*) begin
        crc_pass = (crc_lfsr == 0);
    end
endmodule
