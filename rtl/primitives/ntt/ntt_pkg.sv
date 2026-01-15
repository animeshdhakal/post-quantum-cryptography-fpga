package ntt_pkg;
  // Kyber Parameters
  localparam int KYBER_Q = 3329;
  localparam int KYBER_N = 256;

  // Widths
  localparam int COEFF_WIDTH = 12; // Sufficient for 3329 (up to 4095)
  localparam int DATA_WIDTH = 16;  // Standard datapath width

  // Montgomery Constants (for future use in mul)
  // R = 2^16
  // Qinv = -3329^-1 mod 2^16 = 3327 (0xCFF) check?
  // actually qinv = 62209 for 16-bit?
  // Standard Kyber Montgomery: -q^-1 mod 2^16 = 3327 leads to montgomery factor 2285
  // We will define these in the multiplier module or here carefully.

endpackage
