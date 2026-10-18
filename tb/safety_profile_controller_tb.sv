`timescale 1ns/1ps

module safety_profile_controller_tb;

  reg  [1:0] profile_i;
  reg        injection_authorize_i;

  wire [1:0] selected_profile_o;
  wire       profile_valid_o;
  wire       dcls_enable_o;
  wire       fault_injection_enable_o;

  integer checks_passed;

  safety_profile_controller dut (
      .profile_i                 (profile_i),
      .injection_authorize_i      (injection_authorize_i),
      .selected_profile_o         (selected_profile_o),
      .profile_valid_o            (profile_valid_o),
      .dcls_enable_o              (dcls_enable_o),
      .fault_injection_enable_o   (fault_injection_enable_o)
  );

  task check_profile;
    input [1:0] profile;
    input       authorize;
    input       expected_valid;
    input       expected_dcls;
    input       expected_injection;
    begin
      profile_i = profile;
      injection_authorize_i = authorize;
      #1;

      if (selected_profile_o !== profile ||
          profile_valid_o !== expected_valid ||
          dcls_enable_o !== expected_dcls ||
          fault_injection_enable_o !== expected_injection) begin
        $fatal(1,
          "Profile check failed: profile=%b auth=%b valid=%b dcls=%b injection=%b",
          profile_i, injection_authorize_i, profile_valid_o,
          dcls_enable_o, fault_injection_enable_o);
      end

      checks_passed = checks_passed + 1;

      $display(
        "PASS: profile=%b auth=%b valid=%b dcls=%b injection=%b",
        profile_i, injection_authorize_i, profile_valid_o,
        dcls_enable_o, fault_injection_enable_o);
    end
  endtask

  initial begin
    checks_passed = 0;
    profile_i = 2'b00;
    injection_authorize_i = 1'b0;

    check_profile(2'b00, 1'b0, 1'b1, 1'b0, 1'b0);
    check_profile(2'b00, 1'b1, 1'b1, 1'b0, 1'b0);

    check_profile(2'b01, 1'b0, 1'b1, 1'b1, 1'b0);
    check_profile(2'b01, 1'b1, 1'b1, 1'b1, 1'b0);

    check_profile(2'b10, 1'b0, 1'b1, 1'b1, 1'b0);
    check_profile(2'b10, 1'b1, 1'b1, 1'b1, 1'b1);

    check_profile(2'b11, 1'b0, 1'b0, 1'b0, 1'b0);
    check_profile(2'b11, 1'b1, 1'b0, 1'b0, 1'b0);

    if (checks_passed != 8)
      $fatal(1, "Expected 8 checks, got %0d", checks_passed);

    $display("");
    $display("SAFETY PROFILE CONTROLLER PASS");
    $display("Checks passed: %0d", checks_passed);
    $finish;
  end

endmodule
