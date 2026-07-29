`timescale 1ns/1ps
// Taps the HS serial line and the analog serial/byte clocks so the recovery
// monitor can deserialize the transmitted bytes (behavioral analog model).
interface hs_line_if();
    logic bitclk;   // serial bit clock (analog i-phase clock)
    logic byteclk;  // 8:1 byte-boundary clock (clk_div8)
    logic serial;   // HS line, Dp
    logic en;       // serializer enable (burst active)
endinterface
