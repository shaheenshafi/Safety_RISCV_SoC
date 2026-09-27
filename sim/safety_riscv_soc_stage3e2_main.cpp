#include <iostream>

#include "Vsafety_riscv_soc_stage3e2_tb.h"
#include "verilated.h"

int main(int argc, char **argv) {
    VerilatedContext *contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);

    Vsafety_riscv_soc_stage3e2_tb *top =
        new Vsafety_riscv_soc_stage3e2_tb{contextp};

    const vluint64_t max_time = 200100;

    while (!contextp->gotFinish() &&
           contextp->time() < max_time) {

        top->eval();
        contextp->timeInc(1);
    }

    if (!contextp->gotFinish()) {
        std::cout << "Simulation timeout" << std::endl;
    }

    delete top;
    delete contextp;

    return 0;
}
