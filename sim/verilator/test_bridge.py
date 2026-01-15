import ctypes
import os
import sys

# Path to the shared library
lib_path = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "obj_dir", "libkyber_sim.so")
)


def test_bridge():
    print(f"Loading library from: {lib_path}")

    if not os.path.exists(lib_path):
        print("Error: Library file not found! Did you run 'make'?")
        sys.exit(1)

    try:
        # Load the shared library
        kyber_lib = ctypes.CDLL(lib_path)

        # Define argument and return types
        kyber_lib.run_keccak.argtypes = [ctypes.c_int]
        kyber_lib.run_keccak.restype = ctypes.c_int

        # Test Input
        test_val = 0xDEADBEEF
        print(f"Sending value to Hardware: 0x{test_val:X}")

        # Call Hardware
        result = kyber_lib.run_keccak(test_val)

        print(f"Received result from Hardware: 0x{result:X}")

        # Verification (Weak check for now: just ensure it changed)
        if result != test_val and result != 0:
            print("SUCCESS: Hardware returned a permutated result.")
        else:
            print(f"FAILURE: Result 0x{result:X} seems suspicious (unchanged or zero).")

    except Exception as e:
        print(f"Exception occurred: {e}")


if __name__ == "__main__":
    test_bridge()
