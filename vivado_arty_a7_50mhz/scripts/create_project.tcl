# Auto-generated project Tcl file

# Standalone workspace execution context.
set workspace_root [file normalize [file join [file dirname [info script]] ".."]]
cd $workspace_root

foreach required_file {
    src/local_safety_riscv_safety_riscv_soc_arty_a7_0.1/safety_riscv_soc_arty_a7.v
    src/local_safety_riscv_safety_riscv_soc_arty_a7_0.1/safety_riscv_soc_stage4f.v
    constraints/arty_a7_100t_pins.xdc
    constraints/clock_50mhz.xdc
    data/stage5_battery_monitor.vmem
} {
    if {![file exists $required_file]} {
        error "Required workspace file is missing: $required_file"
    }
}




# Standalone Arty A7 50 MHz project.
# Refuse to overwrite an existing project.
set project_dir [file normalize "build/project"]
set project_file [file join $project_dir "arty_a7_50mhz.xpr"]

if {[file exists $project_file]} {
    error "Project already exists: $project_file. Archive or remove it explicitly before recreating."
}

file mkdir $project_dir
create_project arty_a7_50mhz $project_dir -part xc7a100tcsg324-1


set_property part xc7a100tcsg324-1 [current_project]




set_property verilog_define {FPGA_XILINX=1 } [get_filesets sources_1]
read_verilog -sv {src/lowrisc_ibex_ibex_pkg_0.1/rtl/ibex_pkg.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_pkg_0.1/rtl/ibex_cheriot_pkg.sv}
read_verilog -sv {src/lowrisc_prim_cipher_pkg_0.1/rtl/prim_cipher_pkg.sv}
read_verilog -sv {src/lowrisc_prim_generic_ram_1p_pkg_0/rtl/prim_ram_1p_pkg.sv}
read_verilog -sv {src/lowrisc_prim_generic_ram_2p_pkg_0/rtl/prim_ram_2p_pkg.sv}
read_verilog -sv {src/lowrisc_prim_generic_rom_pkg_0/rtl/prim_rom_pkg.sv}
read_verilog -sv {src/lowrisc_prim_generic_usb_diff_rx_0/rtl/prim_usb_diff_rx.sv}
read_verilog -sv {src/lowrisc_prim_pad_wrapper_pkg_0/rtl/prim_pad_wrapper_pkg.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_pkg.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_22_16_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_22_16_enc.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_28_22_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_28_22_enc.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_39_32_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_39_32_enc.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_64_57_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_64_57_enc.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_72_64_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_72_64_enc.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_hamming_22_16_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_hamming_22_16_enc.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_hamming_39_32_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_hamming_39_32_enc.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_hamming_72_64_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_hamming_72_64_enc.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_hamming_76_68_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_hamming_76_68_enc.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_22_16_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_22_16_enc.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_28_22_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_28_22_enc.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_39_32_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_39_32_enc.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_64_57_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_64_57_enc.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_72_64_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_72_64_enc.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_hamming_22_16_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_hamming_22_16_enc.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_hamming_39_32_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_hamming_39_32_enc.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_hamming_72_64_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_hamming_72_64_enc.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_hamming_76_68_dec.sv}
read_verilog -sv {src/lowrisc_prim_secded_0.1/rtl/prim_secded_inv_hamming_76_68_enc.sv}
read_verilog -sv {src/lowrisc_prim_xilinx_and2_0/rtl/prim_and2.sv}
read_verilog -sv {src/lowrisc_prim_xilinx_buf_0/rtl/prim_buf.sv}
read_verilog -sv {src/lowrisc_prim_xilinx_clock_buf_0/rtl/prim_clock_buf.sv}
read_verilog -sv {src/lowrisc_prim_xilinx_clock_gating_0/rtl/prim_clock_gating.sv}
read_verilog -sv {src/lowrisc_prim_xilinx_clock_mux2_0/rtl/prim_clock_mux2.sv}
read_verilog -sv {src/lowrisc_prim_xilinx_flop_0/rtl/prim_flop.sv}
read_verilog -sv {src/lowrisc_prim_xilinx_flop_en_0/rtl/prim_flop_en.sv}
read_verilog -sv {src/lowrisc_prim_xilinx_prim_pkg_0/rtl/prim_pkg.sv}
read_verilog -sv {src/lowrisc_prim_xilinx_prim_xilinx_default_pkg_0/rtl/prim_xilinx_pkg.sv}
read_verilog -sv {src/lowrisc_prim_xilinx_xnor2_0/rtl/prim_xnor2.sv}
read_verilog -sv {src/lowrisc_prim_xilinx_xor2_0/rtl/prim_xor2.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_icache_0.1/rtl/ibex_icache.sv}
read_verilog -sv {src/lowrisc_prim_cdc_rand_delay_0/rtl/prim_cdc_rand_delay.sv}
read_verilog -sv {src/lowrisc_prim_cipher_0/rtl/prim_subst_perm.sv}
read_verilog -sv {src/lowrisc_prim_cipher_0/rtl/prim_present.sv}
read_verilog -sv {src/lowrisc_prim_cipher_0/rtl/prim_prince.sv}
read_verilog -sv {src/lowrisc_prim_count_0/rtl/prim_count_pkg.sv}
read_verilog -sv {src/lowrisc_prim_count_0/rtl/prim_count.sv}
read_verilog -sv {src/lowrisc_prim_generic_clock_inv_0/rtl/prim_clock_inv.sv}
read_verilog -sv {src/lowrisc_prim_generic_ram_1r1w_pkg_0/rtl/prim_ram_1r1w_pkg.sv}
read_verilog -sv {src/lowrisc_prim_generic_ram_2p_0/rtl/prim_ram_2p.sv}
read_verilog -sv {src/lowrisc_prim_lfsr_0.1/rtl/prim_lfsr.sv}
read_verilog -sv {src/lowrisc_prim_mubi_pkg_0.1/rtl/prim_mubi_pkg.sv}
read_verilog -sv {src/lowrisc_prim_util_0.1/rtl/prim_util_pkg.sv}
read_verilog -sv {src/lowrisc_prim_xilinx_pad_attr_0/rtl/prim_pad_attr.sv}
read_verilog -sv {src/lowrisc_prim_xilinx_pad_wrapper_0/rtl/prim_pad_wrapper.sv}
read_verilog -sv {src/lowrisc_prim_xilinx_ram_1p_0/rtl/prim_ram_1p.sv}
read_verilog -sv {src/lowrisc_prim_xilinx_rom_0/rtl/prim_xilinx_rom.sv}
read_verilog -sv {src/pulp-platform_common_cells_common_cells_0.1/pulp_common_cells/rtl/stream_fork.sv}
read_verilog -sv {src/pulp-platform_common_cells_common_cells_0.1/pulp_common_cells/rtl/stream_join_dynamic.sv}
read_verilog -sv {src/lowrisc_ibex_fpga_xilinx_shared_0/rtl/fpga/xilinx/clkgen_xil7series.sv}
read_verilog -sv {src/lowrisc_ibex_fpga_xilinx_shared_0/rtl/ram_2p.sv}
read_verilog -sv {src/lowrisc_prim_generic_clock_div_0/rtl/prim_clock_div.sv}
read_verilog -sv {src/lowrisc_prim_generic_flop_2sync_0/rtl/prim_flop_2sync.sv}
read_verilog -sv {src/lowrisc_prim_generic_ram_1r1w_0/rtl/prim_ram_1r1w.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi4_sender.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi4_sync.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi4_dec.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi8_sender.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi8_sync.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi8_dec.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi12_sender.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi12_sync.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi12_dec.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi16_sender.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi16_sync.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi16_dec.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi20_sender.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi20_sync.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi20_dec.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi24_sender.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi24_sync.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi24_dec.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi28_sender.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi28_sync.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi28_dec.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi32_sender.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi32_sync.sv}
read_verilog -sv {src/lowrisc_prim_mubi_0.1/rtl/prim_mubi32_dec.sv}
read_verilog -sv {src/lowrisc_prim_onehot_0/rtl/prim_onehot_enc.sv}
read_verilog -sv {src/lowrisc_prim_onehot_0/rtl/prim_onehot_mux.sv}
read_verilog -sv {src/lowrisc_prim_ram_1p_adv_0.1/rtl/prim_ram_1p_adv.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_cheriot_ex.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_alu.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_branch_predict.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_compressed_decoder.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_controller.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_cs_registers.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_csr.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_counter.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_decoder.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_ex_block.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_fetch_fifo.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_id_stage.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_if_stage.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_load_store_unit.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_multdiv_fast.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_multdiv_slow.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_prefetch_buffer.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_pmp.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_wb_stage.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_dummy_instr.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_core_0.1/rtl/ibex_core.sv}
read_verilog -sv {src/lowrisc_prim_fifo_0/rtl/prim_fifo_async_sram_adapter.sv}
read_verilog -sv {src/lowrisc_prim_fifo_0/rtl/prim_fifo_async_simple.sv}
read_verilog -sv {src/lowrisc_prim_fifo_0/rtl/prim_fifo_async.sv}
read_verilog -sv {src/lowrisc_prim_fifo_0/rtl/prim_fifo_sync.sv}
read_verilog -sv {src/lowrisc_prim_fifo_0/rtl/prim_fifo_sync_cnt.sv}
read_verilog -sv {src/lowrisc_prim_generic_rst_sync_0/rtl/prim_rst_sync.sv}
read_verilog -sv {src/lowrisc_prim_ram_1p_scr_0.1/rtl/prim_ram_1p_scr.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_top_0.1/rtl/ibex_register_file_ff.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_top_0.1/rtl/ibex_register_file_fpga.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_top_0.1/rtl/ibex_register_file_latch.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_top_0.1/rtl/ibex_trvk.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_top_0.1/rtl/ibex_lockstep.sv}
read_verilog -sv {src/lowrisc_ibex_ibex_top_0.1/rtl/ibex_top.sv}
read_verilog -sv {src/local_safety_riscv_safety_riscv_soc_arty_a7_0.1/safety_riscv_soc_stage1_mmio.v}
read_verilog -sv {src/local_safety_riscv_safety_riscv_soc_arty_a7_0.1/safety_riscv_soc_stage4f.v}
read_verilog -sv {src/local_safety_riscv_safety_riscv_soc_arty_a7_0.1/safety_riscv_soc_arty_a7.v}
read_verilog -sv {src/local_safety_riscv_safety_riscv_soc_arty_a7_0.1/../safety/dcls_comparator.v}
read_verilog -sv {src/local_safety_riscv_safety_riscv_soc_arty_a7_0.1/../safety/dcls_paired_data_capture_stage.v}
read_verilog -sv {src/local_safety_riscv_safety_riscv_soc_arty_a7_0.1/../safety/dcls_response_error_monitor.v}
read_verilog -sv {src/local_safety_riscv_safety_riscv_soc_arty_a7_0.1/../safety/dcls_fault_injector.v}
read_verilog -sv {src/local_safety_riscv_safety_riscv_soc_arty_a7_0.1/../safety/core_response_fault_injector.v}
read_verilog -sv {src/local_safety_riscv_safety_riscv_soc_arty_a7_0.1/../safety/safety_fault_manager_stage4f.v}
read_verilog -sv {src/local_safety_riscv_safety_riscv_soc_arty_a7_0.1/../safety/safety_mmio_config_stage4f.v}
read_verilog -sv {src/local_safety_riscv_safety_riscv_soc_arty_a7_0.1/../safety/safety_execution_supervisor.v}
read_xdc {constraints/arty_a7_100t_pins.xdc}
read_xdc {constraints/clock_50mhz.xdc}

set_property include_dirs [list src/lowrisc_dv_dv_fcov_macros_0 src/lowrisc_prim_assert_0.1/rtl src/lowrisc_prim_secded_0.1/rtl src/lowrisc_prim_util_get_scramble_params_0/rtl src/lowrisc_prim_util_memload_0/rtl src/lowrisc_prim_fifo_0/rtl .] [get_filesets sources_1]
set_property top safety_riscv_soc_arty_a7 [current_fileset]
set_property source_mgmt_mode None [current_project]


