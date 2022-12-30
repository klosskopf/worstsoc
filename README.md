# worstsoc
Probably the single worst wishbone SoC out there

This is a very stupid and bad wishbone SOC that is tailored to my custo devboard.
All RTL is written in Verilog, to ensure good compatibility and my mental health

- The actual interconnect is in soc.v (At some point I should put it in a sv module)
- The Riscv Core is in a git submodule 'worstrisc', because its the worst hdl code you will ever encounter
- The Peripherals are in the git submodule 'worstcomponents'. I think you get the gist

The whole SOC can be simulated with verilator (god I love that program)
```make test_soc```

The SOC is meant to execute from BOOTROM first. The bootloader can be built with a project I yet have to put on gitlab.
