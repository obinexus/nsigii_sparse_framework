# NSIGII STALESS (ACTIVE vs PASSIVE Observer to Consumer System)
--------------------------------------------------------
VERIFIABLE QUESTION
--------------------------------------------------------
Does a 2-loop (climb-rotate-dive) un-powered glide trajectory give ≥ 15 % increase in horizontal range versus a flat constant-altitude glide at the same initial speed (Mach 0.25 scale equivalent, Re ≈ 3 × 10⁵) for a 1/10-scale cruise-missile configuration?

--------------------------------------------------------
HYPOTHESIS
--------------------------------------------------------
H₀: ΔR ≤ 0 % (loops do not help)  
H₁: ΔR ≥ 15 % (loops help)

--------------------------------------------------------
TEST ARTICLE SPEC
--------------------------------------------------------
- Span: 0.6 m (2 ft)  
- Length: 0.7 m  
- Wing area: 0.084 m²  
- Mass: 0.9 kg (including ballast to hit Reynolds number)  
- Airfoil: Clark-Y (printed rib + carbon spar)  
- Material: LW-PLA skin, 2 × 10 × 1 mm carbon strip spars  
- STL & OpenSCAD source: supplied in repo → `/cad/`  
- G-code: Prusa MK3S+, 0.2 mm layer, 15 % infill

--------------------------------------------------------
FLIGHT INSTRUMENTATION
--------------------------------------------------------
- Autopilot: Pixhawk 6C Mini (≈ £120)  
- IMU: internal ICM-42688-P (200 Hz)  
- GPS: Ublox M8N w/ antenna (RTK-ready)  
- Air-speed: Eagle Tree Pitot (differential, ±1 m/s)  
- Baro: MS5611 on Pixhawk  
- Battery: 3 S 2200 mAh Li-ion (≈ 45 min logging)  
- SD-card logs: PX4 *.ulg binary (automatic)  
- Telemetry: 915 MHz, 100 mW (AMA legal)

--------------------------------------------------------
OPEN-SOURCE SOFTWARE STACK
--------------------------------------------------------
1. Geometry & mesh: OpenVSP 3.31  
2. CFD: SU2 8.0.0 (compressible, RANS k-ω SST)  
3. Mission planning: QGroundControl 4.3  
4. Flight-stack: PX4 v1.14 (BSD licence)  
5. Post-processing: Python 3.11 + pandas + pyulog

--------------------------------------------------------
CFD WORKFLOW (PRE-FLIGHT)
--------------------------------------------------------
Goal: predict lift-to-drag ratio at Re = 3 × 10⁵ and extract polars for 0–12° α.

1. OpenVSP → export STL  
2. `su2_CFD.py` script supplied in repo → `/cfd/`  
   - Far-field: 10 chord radius, 3 m outer boundary  
   - Mesh: 1.2 M cells, y⁺ ≈ 1  
   - BC: inlet M = 0.25, outlet static 101 325 Pa  
3. Run until residuals < 1 × 10⁻⁶ (≈ 2 h on 8-core laptop)  
4. Post → CL(α), CD(α), CM(α) CSV

--------------------------------------------------------
FLIGHT MISSION PROFILE
--------------------------------------------------------
Launch: bungee cord, 25 m rail, 25 m/s release (Re ≈ 3 × 10⁵)  
Two sorties per test day:

A. “Flat” reference  
   - Climb to 60 m, throttle cut → glide at constant altitude  
   - Log until touchdown or 300 m ground range  

B. “2-loop” candidate  
   - Climb to 60 m, throttle cut → autopilot flies pre-programmed loops:  
     – Loop-1: 30 m radius, 45° climb, 360° rotation  
     – Loop-2: 25 m radius, 30° dive exit  
   – Continue glide to touchdown  

--------------------------------------------------------
AUTO-PILOT WAYPOINT SCRIPT (PX4)
--------------------------------------------------------
Supplied in repo → `/mission/loiter_2loop.plan`  
Key params:
- NAV_LOITER_RAD = 30 m  
- FW_CLMBOUT_DIFF = 5 m  
- FW_GND_SPD_SC = 0.9 (glide speed 18 m/s)  
- FW_T_SPD_DEV = 3 m/s (acceptance band)

--------------------------------------------------------
DATA REDUCTION
--------------------------------------------------------
1. Export `*.ulg` → CSV using `ulog2csv.py`  
2. Fuse GPS + baro with 5-point moving average  
3. Compute ground-range:  
   R = Σ √[(xᵢ₊₁ – xᵢ)² + (yᵢ₊₁ – yᵢ)²]  
4. Normalise by initial altitude to cancel wind bias  
5. ΔR = (R_loop – R_flat) / R_flat × 100 %

--------------------------------------------------------
SUCCESS CRITERION
--------------------------------------------------------
If lower 95 % confidence bound on ΔR ≥ 15 % → accept H₁ (publish)  
Else → accept H₀ (still publish, negative results are results)

--------------------------------------------------------
SCHEDULE & BUDGET
--------------------------------------------------------
Week 1  CAD → 3-D print parts  
Week 2  Carbon spar & surface finish  
Week 3  Avionics install + bench test  
Week 4  CFD mesh + polar extraction  
Week 5  AMA paperwork + range booking  
Week 6  Fly 6 pairs (12 sorties) → data  
Total cash outlay: ≈ £1 140 (parts list spreadsheet in repo)
