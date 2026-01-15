#include "Vkyber_top.h"
#include <verilated.h>

// Static instance to persist state if needed, though for now we create fresh
// for each call For a chat app, we might want to keep state, but for a simple
// atomic op, this is fine.

extern "C" {

// Run Keccak Permutation
// val is loaded into the first 64-bit word of the state
// Returns the lower 32-bits of the first word of the result state
int run_keccak(int val) {
  // Instantiate model
  Vkyber_top *top = new Vkyber_top;

  // Initialize
  top->clk = 0;
  top->rst_n = 0;
  top->start = 0;
  top->data_in = val;
  top->eval();

  // Reset sequence
  for (int i = 0; i < 10; i++) {
    top->clk = !top->clk;
    top->eval();
  }
  top->rst_n = 1;

  // Start pulse
  top->clk = !top->clk; // 1
  top->start = 1;
  top->eval();
  top->clk = !top->clk; // 0
  top->eval();

  top->clk = !top->clk; // 1
  top->start = 0;
  top->eval();
  top->clk = !top->clk; // 0
  top->eval();

  // Run until done
  int timeout = 100;
  int result = -1;

  while (!top->done && timeout > 0) {
    top->clk = !top->clk;
    top->eval();
    timeout--;
  }

  if (top->done) {
    result = top->data_out;
  }

  // Cleanup
  top->final();
  delete top;

  return result;
}
}
