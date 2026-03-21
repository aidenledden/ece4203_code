# ECE4203 Lab 1 — Yosys synthesis script (sky130hd)
#
# Called by the Makefile as:
#   WIDTH=<N> PERIOD=<P> LIBERTY=<path> ABC_PERIOD_PS=<ps> \
#       yosys -l results/yosys_<N>_<P>.log -p "tcl synth/synth.tcl"
#
# Environment variables:
#   WIDTH          — adder bit width (e.g. 8)
#   PERIOD         — clock period in ns (e.g. 4.0) — used for output filename
#   LIBERTY        — path to sky130hd liberty file
#   ABC_PERIOD_PS  — combinational delay budget for ABC in picoseconds
#                    = (PERIOD * 1000) - FF_setup_ps
#                    tells ABC how aggressively to optimise for speed:
#                      tight → larger drive-strength cells, may restructure logic
#                      loose → smaller cells, optimises for area
#
# Outputs:
#   results/netlist_<WIDTH>_<PERIOD>.v   — technology-mapped netlist
#   results/yosys_<WIDTH>_<PERIOD>.log   — full log (written by Makefile -l flag)

yosys -import

# ---- Read RTL ----
read_verilog rtl/registered_adder.v
chparam -set WIDTH $::env(WIDTH)

# ---- Elaborate ----
# -flatten merges hierarchy so ABC sees the full carry cone as one
# logic network and can restructure it freely.
synth -top registered_adder -flatten

# ---- FF mapping ----
# Maps Yosys internal $_DFF_* primitives to sky130hd FF cells
# (e.g. sky130_fd_sc_hd__dfxtp_1).  Must run before abc so ABC
# accounts for FF input capacitance when sizing driver cells.
dfflibmap -liberty $::env(LIBERTY)

# ---- Combinational technology mapping ----
# -D <ps> sets the target combinational delay budget.
#read_liberty -lib $::env(LIBERTY)
#abc9 -D $::env(ABC_PERIOD_PS)

# map -D <ps>   : technology map with delay target
# upsize -D <ps>: promote undersized cells on critical paths
# dnsize -D <ps>: demote oversized cells with positive slack
# stime         : print arrival times to log (visible in yosys_W_P.log)
# Write ABC script to a temp file to avoid quoting/escaping issues
set abc_script_file "/tmp/abc_[pid].abc"
set f [open $abc_script_file w]
puts $f "map -D $::env(ABC_PERIOD_PS)"
puts $f "upsize -D $::env(ABC_PERIOD_PS)"
puts $f "dnsize -D $::env(ABC_PERIOD_PS)"
puts $f "stime"
close $f

abc -liberty $::env(LIBERTY) -script $abc_script_file

# ---- Area / cell report ----
# Captured to results/yosys_<WIDTH>_<PERIOD>.log by the -l flag.
stat -liberty $::env(LIBERTY)

# ---- Write mapped netlist ----
# Filename includes both WIDTH and PERIOD so each (WIDTH, PERIOD)
# pair produces a distinct file and runs don't overwrite each other.
write_verilog -noattr results/netlist_$::env(WIDTH)_$::env(PERIOD).v
