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
      // Wait 1 cycle for data to latch into bus_rdata (2-cycle latency)
      top->clk = 1;
      top->eval();
      main_time++;
      top->clk = 0;
      top->eval();
      main_time++;

      result = top->bus_rdata;
      success = 1;
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
// Absorb Seed (External Helper)
void absorb_seed(uint32_t *seed, int word_count) {
  if (!top)
    return;

  // Set Rate to 21 (0x15)
  sim_write(0x0010, 21);

  for (int i = 0; i < word_count; i++) {
    // Check if last word
    if (i == word_count - 1) {
      // Set Absorb Last = 1 (Bit 1 of 0x0004) -> 0x00000002
      sim_write(0x0004, 2);
    } else {
      // Ensure Absorb Last = 0
      sim_write(0x0004, 0);
    }

    // Write Data to 0x0014 (Triggers Absorb Go)
    sim_write(0x0014, seed[i]);
  }

  // Clear Absorb Last
  sim_write(0x0004, 0);
}
}
