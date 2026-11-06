#include <iostream>

#include "Vsafety_riscv_soc_stage2_tb.h"
#include "verilated.h"

int main(int argc, char **argv) {
    VerilatedContext *contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);

    Vsafety_riscv_soc_stage2_tb *top =
        new Vsafety_riscv_soc_stage2_tb{contextp};

    const vluint64_t max_time = 200100;

    while (!contextp->gotFinish() &&
           !contextp->gotError() &&
           contextp->time() < max_time) {
        top->eval();
        contextp->timeInc(1);
    }

    const bool timed_out =
        !contextp->gotFinish() && !contextp->gotError();
    if (timed_out) {
        std::cerr << "Stage 2 simulation timeout" << std::endl;
    }

    const bool failed = contextp->gotError() || timed_out;
    delete top;
    delete contextp;

    return failed ? 1 : 0;
}
