Tool to benchmark several PQC signing algorithms from NIST

- MAYO
- PQOV
- Falcon

# Building

Run `make` to build the tests. The tool will automatically download the source code for the supported algorithms.

Only linux is supported. Other operating systems may work, but there are no guarentees.

# Testing

Run `make test` to run the tests. It will generate a "results.txt" with the results for each algorithm.

Results will contain:

- Public Key Size
- Private Key Size
- Message Size
- Signature Size
- Signs/s
- Verifies/s

Please note, results vary based on hardware. Results for algorithms can only be compared within the same
results file generated on the same machine.