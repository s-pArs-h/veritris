# Veritris
#   make lint        Verilator -Wall
#   make sim         system testbench under Verilator (fast)
#   make sim-icarus  same testbench under Icarus Verilog (slow: several minutes)

SRC = nexys_tetris_top.v clock_gen.v reset_sync.v debouncer.v vga_controller.v \
      tetris_engine.v seven_seg_driver.v

.PHONY: lint sim sim-icarus clean

lint:
	verilator --lint-only -Wall --unroll-count 256 -DSIM $(SRC) --top-module nexys_tetris_top
	@echo "Verilator -Wall: clean"

sim:
	@mkdir -p build
	verilator --binary --timing -DSIM --unroll-count 256 -Wno-fatal -Wno-lint -Wno-style \
	  --top-module tb_top -Mdir build/obj -j 0 sim/tb_top.v $(SRC) > build/verilate.log 2>&1 || (cat build/verilate.log; exit 1)
	build/obj/Vtb_top | tee build/sim.log
	@grep -q "^PASS" build/sim.log

sim-icarus:
	@mkdir -p build
	iverilog -g2012 -DSIM -o build/tb sim/tb_top.v $(SRC)
	vvp -n build/tb | tee build/sim_icarus.log
	@grep -q "^PASS" build/sim_icarus.log

clean:
	rm -rf build
