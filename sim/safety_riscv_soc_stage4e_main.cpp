#include <iostream>

#include "Vsafety_riscv_soc_stage4e_tb.h"
#include "verilated.h"

int main(int argc, char **argv) {
    VerilatedContext *contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);

    Vsafety_riscv_soc_stage4e_tb *top =
        new Vsafety_riscv_soc_stage4e_tb{contextp};

    const vluint64_t max_time = 30000000;

    while (!contextp->gotFinish() &&
           !contextp->gotError() &&
           contextp->time() < max_time) {
        top->eval();
        contextp->timeInc(1);
    }

    if (!contextp->gotFinish() && !contextp->gotError()) {
        std::cerr << "Stage 4E C++ simulation timeout" << std::endl;
        delete top;
        delete contextp;
        return 1;
    }

    const bool failed = contextp->gotError();
    delete top;
    delete contextp;

    return failed ? 1 : 0;
}
