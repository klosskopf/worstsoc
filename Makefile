COMPONENT_DIR = worstcomponents
RISCV_DIR = worstrisc

test_soc: $(COMPONENT_DIR)/src/* $(RISCV_DIR)/src/*.v soc.v tests/* #verilate
	@echo "-- BUILD -------------------"
	verilator -cc --exe --build -j -Os -Wall -DTEST --trace -Itests -I"$(RISCV_DIR)/src" -I"$(COMPONENT_DIR)/src" --coverage --assert tests/tst_soc.v tests/sim_soc.cpp

	@echo "-- RUN ---------------------"
	obj_dir/Vtst_soc

	@echo "-- COVERAGE ----------------"
	verilator_coverage --annotate logs/annotated logs/coverage.dat

soc.json: soc.v $(RISCV_DIR)/src/*.v $(COMPONENT_DIR)/src/*.v firmware.mem #synthesize 
	yosys -p 'synth_ecp5 -top soc -json soc.json' soc.v $(RISCV_DIR)/src/*.v $(COMPONENT_DIR)/src/*.v

soc.config: pin_constrains.lpf soc.json #place and route
	mkdir -p logs
	nextpnr-ecp5 --25k --package CABGA256 --json soc.json --top soc --textcfg soc.config --lpf pin_constrains.lpf --report logs/nextpnr-report.json --lpf-allow-unconstrained

soc.bin soc.svf: soc.config #pack into bitstream
	ecppack soc.config soc.bin --svf soc.svf --spimode qspi
	sed -i '27s/00000000/00001000/' soc.svf

prog: soc.svf #program via usbblaster
	openocd -f interface/altera-usb-blaster.cfg -f LFE5U-25F.cfg -c "transport select jtag; init; svf soc.svf; exit"

show_%: src/*.v $(RISCV_DIR)/src/*.v $(COMPONENT_DIR)/src/*.v
	yosys -p 'hierarchy -top $*; proc; opt; show -colors 42 -stretch $*' src/soc.v

clean:
	-rm -rf obj_dir logs *.log *.dmp *.vpd coverage.dat core *.asc *.rpt *.bin *.json *.svf *.config

.PHONY: all prog clean
