// For std::unique_ptr
#include <memory>
#include <verilated.h>
#include "../obj_dir/Vtst_soc.h"

double sc_time_stamp() { return 0; }

int main(int argc, char** argv, char** env)
{
    // Prevent unused variable warnings
    if (false && argc && argv && env) {}
    
    Verilated::mkdir("logs");
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->randReset(2);// Randomization reset policy
    contextp->traceEverOn(true);
    contextp->commandArgs(argc, argv);

    const std::unique_ptr<Vtst_soc> soc{new Vtst_soc{contextp.get(), "SOC"}};

    //reset
    soc->rst_i = 0;
    soc->eval();
    soc->rst_i = 1;
    soc->eval();
    
    while (!contextp->gotFinish() && contextp->time() < 100000)
    {
        if (contextp->time() == 1) soc->rst_i = 0;

        soc->flashMiso_i = soc->flashMosi_o;
        soc->uartRx_i = soc->uartTx_o;

        soc->clk_i ^= 1;
        soc->eval();
        contextp->timeInc(1);  
    }

    soc->final();

    // Coverage analysis (calling write only after the test is known to pass)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    contextp->coveragep()->write("logs/coverage.dat");
#endif
}
