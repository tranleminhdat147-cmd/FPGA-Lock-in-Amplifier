# FPGA-Lock-in-Amplifier
FPGA-based Digital Lock-in Amplifier
A fully synchronous, hardware-implemented Digital Lock-in Amplifier (DLIA) designed for phase-sensitive detection of weak periodic signals, built entirely in Verilog RTL on a Cyclone IV FPGA (DE0-Nano).
Architecture
The signal chain is implemented as a fully pipelined hardware datapath:

TTL-synchronized phase/frequency tracker — locks onto an external reference clock edge for phase alignment
DDS (Direct Digital Synthesis) — generates synchronous sine/cosine reference waveforms
Digital mixer — multiplies the incoming signal with the DDS reference (in-phase and quadrature)
Integrate-and-Dump filter — performs exact single-period (or multi-period) integration, synchronized to the reference edge for clean rejection of harmonic content
CORDIC core — converts the resulting I/Q components into magnitude and phase in real time, entirely on-chip

Key design points

Clock-domain crossing between the SPI/ADC sampling domain and the main processing domain is handled with a synchronizer + edge-detector to guarantee single-cycle valid pulses
Sample count (N) is tracked per integration window to support frequency-adaptive normalization
Bit-width and CORDIC scaling are derived analytically from worst-case accumulator bounds, not arbitrarily chosen

Status
Work in progress — core pipeline verified on hardware (SignalTap), with ongoing characterization of phase accuracy across frequency and amplitude.
