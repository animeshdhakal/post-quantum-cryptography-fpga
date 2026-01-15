#include "Vkyber_top.h"
#include <iostream>
#include <verilated.h>

// Global persistent simulation instance
static Vkyber_top *top = nullptr;
static vluint64_t main_time = 0;

extern "C" {

// Initialize Simulation
void sim_init() {
  if (top) {
    delete top;
  }
  top = new Vkyber_top;
  main_time = 0;

  // Initial Reset
  top->clk = 0;
  top->rst_n = 0;
  top->bus_enable = 0;
  top->eval();

  // Pulse Reset
  for (int i = 0; i < 10; i++) {
    top->clk = !top->clk;
    top->eval();
    main_time++;
  }
  top->rst_n = 1;
  top->eval();
}

// Step Simulation Logic (Clock cycles)
void sim_step(int cycles) {
  if (!top)
    return;

  for (int i = 0; i < cycles; i++) {
    top->clk = 1;
    top->eval();
    main_time++;

    top->clk = 0;
    top->eval();
    main_time++;
  }
}

// Bus Write (Blocking until Ack or Timeout)
int sim_write(int addr, int data) {
  if (!top)
    return -1;

  // Setup Bus
  top->bus_enable = 1;
  top->bus_write = 1;
  top->bus_addr = addr;
  top->bus_wdata = data;

  int timeout = 100; // Cycles
  int success = 0;

  while (timeout > 0) {
    // Clock
    top->clk = 1;
    top->eval();
    main_time++;

    // Check Ready on Rising Edge? Or async?
    // Our RTL asserts ready combinationally or registered?
    // "if (bus_enable && !bus_ready) bus_ready <= 1" -> Registered ack.
    // So we see ready on logic AFTER posedge.

    if (top->bus_ready) {
      success = 1;
    }

    top->clk = 0;
    top->eval();
    main_time++;

    if (success)
      break;
    timeout--;
  }

  // Clear Bus
  top->bus_enable = 0;
  top->bus_write = 0;
  // Step one more to clear request lines in RTL
  sim_step(1);

  return success ? 0 : -1;
}

// Bus Read (Blocking)
int sim_read(int addr) {
  if (!top)
    return -1;

  // Setup Bus
  top->bus_enable = 1;
  top->bus_write = 0;
  top->bus_addr = addr;

  int timeout = 100;
  int success = 0;
  int result = 0;

  while (timeout > 0) {
    top->clk = 1;
    top->eval();
    main_time++;

    if (top->bus_ready) {
      success = 1;
      result = top->bus_rdata;
    }

    top->clk = 0;
    top->eval();
    main_time++;

    if (success)
      break;
    timeout--;
  }

  top->bus_enable = 0;
  sim_step(1);

  return success ? result : -1;
}

// Cleanup
void sim_close() {
  if (top) {
    top->final();
    delete top;
    top = nullptr;
  }
}
}
