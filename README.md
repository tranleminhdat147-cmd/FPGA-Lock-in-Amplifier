# FPGA-Lock-in-Amplifier
FPGA-based Digital Lock-in Amplifier
A fully synchronous, hardware-implemented Digital Lock-in Amplifier (DLIA) designed for phase-sensitive detection of weak periodic signals, built entirely in Verilog RTL on a Cyclone IV FPGA (DE0-Nano).
Architecture
The signal chain is implemented as a fully pipelined hardware datapath:

TTL-synchronized phase/frequency tracker locks onto an external reference clock edge for phase alignment
DDS (Direct Digital Synthesis)  generates synchronous sine/cosine reference waveforms
Digital mixer multiplies the incoming signal with the DDS reference (in-phase and quadrature)
Integrate-and-Dump filter performs exact single-period (or multi-period) integration, synchronized to the reference edge for clean rejection of harmonic content
CORDIC core converts the resulting I/Q components into magnitude and phase in real time, entirely on-chip

A dedicated FSM sits between the result FIFO and the UART TX core. When the FIFO holds a new 96-bit result word (magnitude, phase, and sample count) and the UART is idle, the packetizer latches the word, then decomposes it into a 13-byte packet (a fixed header byte followed by 4 bytes each of magnitude, phase, and sample count) and feeds them out one at a time via a start/ready handshake with the UART TX core.

The UART TX core is a standard serial transmitter (start bit → 8 data bits → stop bit) implemented as its own FSM. It exposes a simple byte-oriented handshake accepting one byte at a time on request and asserting a ready flag when free so the packetizer can treat it as a decoupled shift-out engine and burst an entire 13-byte packet per frequency sweep point without needing to manage bit-level timing itself.

Key design points:
Clock-domain crossing between the SPI/ADC sampling domain and the main processing domain is handled with a synchronizer + edge-detector to guarantee single-cycle valid pulses
Sample count (N) is tracked per integration window to support frequency-adaptive normalization
Bit-width and CORDIC scaling are derived analytically from worst-case accumulator bounds, not arbitrarily chosen

Status
Work in progress — core pipeline verified on hardware (SignalTap), with ongoing characterization of phase accuracy across frequency and amplitude.
