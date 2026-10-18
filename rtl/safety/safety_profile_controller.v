`timescale 1ns/1ps

module safety_profile_controller (
    input  wire       [1:0] profile_i,
    input  wire             injection_authorize_i,

    output wire       [1:0] selected_profile_o,
    output wire             profile_valid_o,
    output wire             dcls_enable_o,
    output wire             fault_injection_enable_o
);

  localparam [1:0] PROFILE_BASIC      = 2'b00;
  localparam [1:0] PROFILE_SAFETY     = 2'b01;
  localparam [1:0] PROFILE_DIAGNOSTIC = 2'b10;
  localparam [1:0] PROFILE_RESERVED   = 2'b11;

  assign selected_profile_o = profile_i;

  assign profile_valid_o =
      (profile_i != PROFILE_RESERVED);

  assign dcls_enable_o =
      profile_valid_o &&
      ((profile_i == PROFILE_SAFETY) ||
       (profile_i == PROFILE_DIAGNOSTIC));

  assign fault_injection_enable_o =
      (profile_i == PROFILE_DIAGNOSTIC) &&
      injection_authorize_i &&
      profile_valid_o;

endmodule
