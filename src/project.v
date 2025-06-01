/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs: ui_in[2]=rst, ui_in[1]=M_raw, ui_in[0]=A
    output wire [7:0] uo_out,   // uo_out[1:0] = estado de crédito
    input  wire [7:0] uio_in,   // Not used
    output wire [7:0] uio_out,  // Not used
    output wire [7:0] uio_oe,   // Not used
    input  wire       ena,      // Not used
    input  wire       clk,      // Reloj 100 MHz
    input  wire       rst_n     // Reset asíncrono activo bajo
);

    // ─────────────────────────────────────────────────────────────────────────
    // 1) Debounce de M_raw y detección de su flanco ↑ (un solo pulso)
    // ─────────────────────────────────────────────────────────────────────────
    logic [2:0] M_sync;
    logic       M_db;
    logic       M_db_prev;
    logic       M_edge;

    // reset activo alto para lógica interna
    wire rst_i = ~rst_n;
    wire A_i   = ui_in[0];
    wire M_raw = ui_in[1];

    always_ff @(posedge clk or posedge rst_i) begin
        if (rst_i) begin
            M_sync    <= 3'b000;
            M_db_prev <= 1'b0;
        end else begin
            M_sync    <= {M_sync[1:0], M_raw};
            M_db_prev <= M_db;
        end
    end

    assign M_db   = (M_sync == 3'b111);
    assign M_edge = M_db & ~M_db_prev;

    // ─────────────────────────────────────────────────────────────────────────
    // 2) FSM de crédito
    // ─────────────────────────────────────────────────────────────────────────
    logic [1:0] cs, ns;

    always_comb begin
        ns = cs;
        case (cs)
            2'b00: if (M_edge && !A_i)    ns = 2'b01;
            2'b01: if (M_edge && !A_i)    ns = 2'b10;
                   else if (A_i)          ns = 2'b00;
            2'b10: if (M_edge && !A_i)    ns = 2'b11;
                   else if (A_i)          ns = 2'b00;
            2'b11: if (A_i)               ns = 2'b00;
            default:                      ns = 2'b00;
        endcase
    end

    always_ff @(posedge clk or posedge rst_i) begin
        if (rst_i)
            cs <= 2'b00;
        else
            cs <= ns;
    end

    // ─────────────────────────────────────────────────────────────────────────
    // 3) Salida del estado (crédito) a uo_out[1:0]
    // ─────────────────────────────────────────────────────────────────────────
    assign uo_out  = {6'b000000, cs};  // Salida solo usa bits 1:0
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // ─────────────────────────────────────────────────────────────────────────
    // Prevención de advertencias
    // ─────────────────────────────────────────────────────────────────────────
    wire _unused = &{ena, uio_in};

endmodule
