module safety_riscv_soc_stage2 (
    input clk_i,
    input rst_ni
);

  // Independent redundant execution channels.
  safety_riscv_soc_stage1 core_a (
      .clk_i  (clk_i),
      .rst_ni (rst_ni)
  );

  safety_riscv_soc_stage1 core_b (
      .clk_i  (clk_i),
      .rst_ni (rst_ni)
  );

endmodule
