import math
import os
import sys
from pathlib import Path

import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_factory_core_assets as g

# This builder intentionally uses explicit hard-surface subassemblies rather than
# primitive silhouettes. It emits source GLBs that are atlas-merged/decimated in
# the existing Roblox optimization pipeline.


def beam(name, loc, dims, mat=g.CHAR, bevel=0.025, rot=(0, 0, 0)):
    return g.box(name, loc, dims, mat, bevel, rot)


def bolt(name, loc, mat=g.GALV, r=0.045, depth=0.06, rot=(0, 0, 0)):
    return g.cyl(name, loc, r, depth, mat, rot=rot, vertices=10, bevel=0.008)


def wheel(name, x, y, z, radius=0.58, width=0.34):
    tire = g.cyl(name + "_Tire", (x, y, z), radius, width, g.RUBBER,
                 rot=(math.radians(90), 0, 0), vertices=20, bevel=0.025)
    g.cyl(name + "_Rim", (x, y - math.copysign(width * 0.52, y), z), radius * 0.55, width * 0.18,
          g.GALV, rot=(math.radians(90), 0, 0), vertices=16, bevel=0.012)
    g.cyl(name + "_Hub", (x, y - math.copysign(width * 0.62, y), z), radius * 0.19, width * 0.22,
          g.CHAR, rot=(math.radians(90), 0, 0), vertices=12, bevel=0.008)
    return tire


def motor(name, loc, length=1.5, radius=0.42, axis="x"):
    rot = (0, math.radians(90), 0) if axis == "x" else ((math.radians(90), 0, 0) if axis == "y" else (0, 0, 0))
    g.cyl(name + "_Body", loc, radius, length, g.CHAR, rot=rot, vertices=20, bevel=0.02)
    # end bells + cooling fins
    if axis == "x":
        ends = [(loc[0] - length * 0.47, loc[1], loc[2]), (loc[0] + length * 0.47, loc[1], loc[2])]
        fin_axis = 0
    elif axis == "y":
        ends = [(loc[0], loc[1] - length * 0.47, loc[2]), (loc[0], loc[1] + length * 0.47, loc[2])]
        fin_axis = 1
    else:
        ends = [(loc[0], loc[1], loc[2] - length * 0.47), (loc[0], loc[1], loc[2] + length * 0.47)]
        fin_axis = 2
    for i, p in enumerate(ends):
        g.cyl(name + f"_End_{i}", p, radius * 1.04, length * 0.08, g.GALV, rot=rot, vertices=20, bevel=0.015)
    for i in range(6):
        t = -0.35 + i * 0.14
        p = list(loc)
        p[fin_axis] += t * length
        g.cyl(name + f"_Fin_{i}", tuple(p), radius * 1.08, length * 0.035, g.GALV,
              rot=rot, vertices=20, bevel=0.005)


def gearbox(name, loc, dims=(0.8, 0.9, 0.9)):
    g.box(name + "_Housing", loc, dims, g.YELLOW, 0.08)
    g.cyl(name + "_Cap", (loc[0], loc[1] - dims[1] * 0.51, loc[2]), min(dims[0], dims[2]) * 0.27,
          0.10, g.CHAR, rot=(math.radians(90), 0, 0), vertices=16, bevel=0.01)
    for sx in (-1, 1):
        for sz in (-1, 1):
            bolt(name + "_Bolt", (loc[0] + sx * dims[0] * 0.33, loc[1] - dims[1] * 0.515,
                                   loc[2] + sz * dims[2] * 0.33), g.GALV,
                 rot=(math.radians(90), 0, 0))


def support_leg(name, x, y, deck_z, height):
    g.box(name + "_Leg", (x, y, height * 0.5), (0.18, 0.18, height), g.CHAR, 0.02)
    g.box(name + "_Foot", (x, y, 0.045), (0.48, 0.42, 0.09), g.GALV, 0.012)
    g.box(name + "_Gusset", (x, y, deck_z - 0.25), (0.42, 0.42, 0.18), g.YELLOW, 0.02)


def conveyor_common(name, length, width, deck, outfeed=False, magnetic=False):
    g.clear_scene()
    # C-channel frame and cross-members.
    for y in (-width * 0.5, width * 0.5):
        g.box("MainChannel", (0, y, deck - 0.30), (length, 0.20, 0.42), g.CHAR, 0.035)
        g.box("SideGuard", (0, y, deck + 0.34), (length - 0.12, 0.12, 0.82),
              g.GALV if outfeed else g.YELLOW, 0.025)
    for x in np.linspace(-length / 2 + 0.4, length / 2 - 0.4, 7):
        g.box("CrossMember", (float(x), 0, deck - 0.36), (0.16, width, 0.18), g.CHAR, 0.015)
    # belt and rollers
    g.box("Belt", (0, 0, deck), (length - 0.35, width - 0.46, 0.12), g.RUBBER, 0.018)
    roller_count = max(9, int(length * 1.5))
    for x in np.linspace(-length / 2 + 0.42, length / 2 - 0.42, roller_count):
        g.cyl("Roller", (float(x), 0, deck - 0.10), 0.10, width - 0.32, g.GALV,
              rot=(math.radians(90), 0, 0), vertices=12, bevel=0.008)
    for x in (-length / 2 + 0.35, length / 2 - 0.35):
        g.cyl("EndDrum", (x, 0, deck), 0.25, width - 0.34, g.CHAR,
              rot=(math.radians(90), 0, 0), vertices=18, bevel=0.012)
    # legs and braces
    for x in (-length * 0.34, 0.0, length * 0.34):
        for y in (-width * 0.42, width * 0.42):
            support_leg("Support", x, y, deck, deck - 0.2)
    for y in (-width * 0.43, width * 0.43):
        g.box("LongBrace", (0, y, deck * 0.48), (length * 0.72, 0.10, 0.10), g.YELLOW, 0.012)
    # drive package at discharge end
    motor("DriveMotor", (length / 2 - 0.9, width * 0.72, deck - 0.10), 1.05, 0.31, "y")
    gearbox("DriveGearbox", (length / 2 - 0.9, width * 0.52, deck - 0.10), (0.72, 0.55, 0.68))
    # sensors and e-stop rail
    for x in (-length * 0.30, length * 0.30):
        g.box("SensorPost", (x, -width * 0.58, deck + 0.78), (0.10, 0.10, 0.90), g.CHAR, 0.015)
        g.box("SensorHead", (x, -width * 0.56, deck + 1.16), (0.22, 0.20, 0.22), g.YELLOW, 0.025)
    g.hose("EStopCable", [(-length * 0.46, -width * 0.61, deck + 0.70),
                          (0, -width * 0.61, deck + 0.74),
                          (length * 0.46, -width * 0.61, deck + 0.70)], 0.022)
    if magnetic:
        # independent portal structure rather than a floating box
        for x in (-2.5, 2.5):
            for y in (-width * 0.78, width * 0.78):
                g.box("MagnetPortalPost", (x, y, 2.55), (0.24, 0.24, 3.7), g.CHAR, 0.03)
                g.box("PortalFoot", (x, y, 0.06), (0.60, 0.60, 0.12), g.GALV, 0.015)
            g.box("PortalCross", (x, 0, 4.20), (0.28, width * 1.7, 0.30), g.CHAR, 0.03)
        g.box("MagnetBridge", (0, 0, 4.10), (5.25, 0.34, 0.34), g.CHAR, 0.035)
        g.box("MagnetHousing", (0, 0, 3.48), (3.2, width * 0.72, 0.62), g.YELLOW, 0.09)
        g.box("MagnetLower", (0, 0, 3.17), (2.75, width * 0.64, 0.20), g.CHAR, 0.04)
        for x in (-1.15, -0.38, 0.38, 1.15):
            g.cyl("CoilCore", (x, 0, 3.12), 0.18, width * 0.55, g.GALV,
                  rot=(math.radians(90), 0, 0), vertices=16, bevel=0.01)
        # lift points + cable chains
        for x in (-1.2, 1.2):
            g.cyl("Suspension", (x, 0, 3.84), 0.07, 0.7, g.GALV, vertices=12)
        g.box("MagnetCabinet", (2.7, width * 0.92, 2.35), (0.95, 0.62, 1.65), g.CHAR, 0.06)
        g.hose("MagnetPowerCable", [(2.7, width * 0.82, 3.1), (2.2, width * 0.68, 3.6),
                                    (1.6, width * 0.45, 3.72), (1.1, width * 0.30, 3.55)], 0.045)
        # small maintenance platform
        g.box("ServiceDeck", (2.75, -width * 0.92, 2.25), (1.25, 0.70, 0.12), g.GALV, 0.02)
        for z in (2.65, 3.10):
            g.box("ServiceRail", (2.75, -width * 1.26, z), (1.35, 0.07, 0.07), g.YELLOW, 0.01)
        for x in (2.20, 3.30):
            g.box("ServicePost", (x, -width * 1.26, 2.67), (0.07, 0.07, 0.95), g.YELLOW, 0.01)
    return g.export_asset(name)


def build_baler():
    g.clear_scene()
    # skid, chamber and structural cage
    g.box("Skid", (0, 0, 0.16), (5.8, 3.5, 0.32), g.CHAR, 0.05)
    g.box("ChamberFloor", (-0.35, 0, 0.72), (4.2, 2.62, 0.22), g.GALV, 0.03)
    for x in (-2.55, 1.85):
        for y in (-1.45, 1.45):
            g.box("FramePost", (x, y, 2.05), (0.28, 0.28, 3.75), g.CHAR, 0.035)
    for y in (-1.45, 1.45):
        g.box("TopLongBeam", (-0.35, y, 3.84), (4.65, 0.28, 0.32), g.CHAR, 0.035)
        g.box("BottomLongBeam", (-0.35, y, 0.53), (4.65, 0.24, 0.25), g.CHAR, 0.03)
    g.box("RearWall", (1.76, 0, 2.02), (0.22, 2.60, 2.60), g.GALV, 0.04)
    for y in (-1.30, 1.30):
        g.box("ChamberSide", (-0.35, y, 2.00), (4.0, 0.18, 2.55), g.GALV, 0.035)
        for x in (-1.7, -0.6, 0.5, 1.4):
            g.box("SideRib", (x, y + (-0.11 if y < 0 else 0.11), 2.0), (0.14, 0.14, 2.72), g.CHAR, 0.02)
    # reinforced service door
    g.box("Door", (-2.12, 0, 2.0), (0.20, 2.55, 2.55), g.YELLOW, 0.045)
    for z in (1.12, 2.0, 2.88):
        g.box("DoorBrace", (-2.24, 0, z), (0.12, 2.35, 0.14), g.CHAR, 0.018)
    for y in (-0.95, 0.95):
        g.cyl("DoorHinge", (-2.28, y, 2.0), 0.11, 0.55, g.CHAR, vertices=14, bevel=0.01)
    g.box("DoorLock", (-2.31, 0, 2.0), (0.14, 0.55, 0.85), g.CHAR, 0.025)
    # ram plate and twin hydraulic cylinders
    g.box("RamPlate", (0.75, 0, 2.0), (0.30, 2.32, 2.22), g.CHAR, 0.04)
    for y in (-0.62, 0.62):
        g.cyl("HydraulicCylinder", (2.70, y, 2.0), 0.28, 2.0, g.YELLOW,
              rot=(0, math.radians(90), 0), vertices=20, bevel=0.02)
        g.cyl("HydraulicRod", (1.55, y, 2.0), 0.14, 1.15, g.GALV,
              rot=(0, math.radians(90), 0), vertices=16, bevel=0.012)
    g.box("CylinderBridge", (2.82, 0, 2.0), (0.38, 2.15, 2.8), g.CHAR, 0.045)
    # power pack
    g.box("PowerSkid", (2.25, -1.85, 0.32), (2.35, 0.95, 0.24), g.CHAR, 0.03)
    g.box("OilTank", (2.35, -1.85, 0.90), (1.65, 0.82, 0.95), g.GALV, 0.06)
    motor("PumpMotor", (1.75, -1.85, 1.58), 1.15, 0.34, "x")
    gearbox("PumpBlock", (2.65, -1.85, 1.58), (0.58, 0.72, 0.58))
    for z in (1.22, 1.55, 1.88):
        g.cyl("ManifoldPort", (3.28, -1.84, z), 0.08, 0.10, g.GALV,
              rot=(math.radians(90), 0, 0), vertices=12)
    g.hose("PressureA", [(3.2, -1.75, 1.8), (3.6, -1.35, 2.4), (3.5, -0.8, 2.75), (3.2, -0.58, 2.6)], 0.05)
    g.hose("PressureB", [(3.1, -1.75, 1.45), (3.45, -1.35, 1.1), (3.45, -0.78, 1.25), (3.2, 0.40, 1.55)], 0.05)
    # control pedestal with protected buttons
    g.box("ControlPedestal", (-1.35, 1.82, 1.25), (0.80, 0.58, 2.15), g.CHAR, 0.055)
    g.box("ControlFace", (-1.35, 1.53, 1.52), (0.66, 0.05, 1.05), g.GALV, 0.025)
    for x, z, mat in ((-1.55, 1.72, g.YELLOW), (-1.35, 1.72, g.GALV), (-1.15, 1.72, g.RUST)):
        g.cyl("ControlButton", (x, 1.49, z), 0.07, 0.05, mat, rot=(math.radians(90), 0, 0), vertices=12)
    return g.export_asset("hydraulic_scrap_baler")


def build_hopper():
    g.clear_scene()
    g.frustum("HopperShell", 1.35, 2.75, 4.8, 4.5, 1.8, 1.65, g.GALV, True)
    # top rolled rim and stiffeners
    for x in (-2.18, 2.18):
        g.box("TopRimX", (x, 0, 4.10), (0.20, 4.55, 0.24), g.YELLOW, 0.025)
        for z in (1.95, 2.75, 3.55):
            g.box("SideStiffener", (x * 0.88, 0, z), (0.14, 3.5, 0.14), g.CHAR, 0.018)
    for y in (-2.05, 2.05):
        g.box("TopRimY", (0, y, 4.10), (4.55, 0.20, 0.24), g.YELLOW, 0.025)
    # structural legs + X braces
    for x in (-1.75, 1.75):
        for y in (-1.55, 1.55):
            g.box("HopperLeg", (x, y, 0.68), (0.24, 0.24, 1.36), g.CHAR, 0.025)
            g.box("FootPlate", (x, y, 0.05), (0.58, 0.58, 0.10), g.GALV, 0.012)
    for y in (-1.60, 1.60):
        g.box("LegTie", (0, y, 0.72), (3.7, 0.16, 0.16), g.CHAR, 0.02)
    # discharge throat, gate, actuator
    g.box("DischargeThroat", (0, 0, 1.18), (1.85, 1.72, 0.55), g.CHAR, 0.04)
    g.box("SlideGate", (0, -0.92, 1.18), (1.55, 0.16, 0.92), g.YELLOW, 0.035)
    g.cyl("GateActuator", (1.15, -1.02, 1.2), 0.12, 1.05, g.CHAR,
          rot=(0, math.radians(90), 0), vertices=16)
    g.cyl("GateRod", (0.48, -1.02, 1.2), 0.06, 0.60, g.GALV,
          rot=(0, math.radians(90), 0), vertices=12)
    # ladder
    for z in np.linspace(0.9, 3.6, 7):
        g.box("LadderRung", (-2.5, 1.58, float(z)), (0.62, 0.08, 0.08), g.GALV, 0.01)
    for x in (-2.78, -2.22):
        g.box("LadderRail", (x, 1.58, 2.25), (0.08, 0.08, 3.0), g.CHAR, 0.012)
    return g.export_asset("large_scrap_hopper")


def arm(name, base, direction=1.0):
    bx, by, bz = base
    g.cyl(name + "_Base", (bx, by, bz), 0.48, 0.30, g.CHAR, vertices=20, bevel=0.02)
    g.cyl(name + "_Shoulder", (bx, by, bz + 0.35), 0.28, 0.36, g.YELLOW, vertices=18, bevel=0.02)
    g.box(name + "_Upper", (bx + 0.48 * direction, by, bz + 0.92), (1.25, 0.32, 0.34), g.YELLOW, 0.07,
          rot=(0, math.radians(-38 * direction), 0))
    g.sphere(name + "_Elbow", (bx + 0.90 * direction, by, bz + 1.35), (0.26, 0.26, 0.26), g.CHAR, 16, 8)
    g.box(name + "_Forearm", (bx + 1.18 * direction, by, bz + 1.68), (0.95, 0.26, 0.28), g.GALV, 0.06,
          rot=(0, math.radians(-32 * direction), 0))
    g.sphere(name + "_Wrist", (bx + 1.48 * direction, by, bz + 1.92), (0.20, 0.20, 0.20), g.CHAR, 14, 7)
    g.box(name + "_Tool", (bx + 1.65 * direction, by, bz + 1.98), (0.44, 0.42, 0.28), g.CHAR, 0.04)
    g.hose(name + "_Cable", [(bx, by + 0.18, bz + 0.45), (bx + 0.45 * direction, by + 0.18, bz + 1.0),
                             (bx + 0.95 * direction, by + 0.18, bz + 1.45), (bx + 1.45 * direction, by + 0.18, bz + 1.90)], 0.035)


def build_assembler():
    g.clear_scene()
    g.box("Foundation", (0, 0, 0.14), (6.4, 4.4, 0.28), g.CHAR, 0.055)
    # grated central turntable
    g.cyl("TurntableBase", (0, 0, 0.48), 1.55, 0.34, g.CHAR, vertices=28, bevel=0.025)
    g.cyl("TurntableDeck", (0, 0, 0.68), 1.38, 0.18, g.GALV, vertices=28, bevel=0.02)
    for a in range(0, 360, 45):
        rad = math.radians(a)
        g.box("FixtureJaw", (math.cos(rad) * 1.02, math.sin(rad) * 1.02, 0.88),
              (0.26, 0.22, 0.38), g.YELLOW, 0.025, rot=(0, 0, rad))
    # gantry frame
    for x in (-2.75, 2.75):
        for y in (-1.85, 1.85):
            g.box("GantryPost", (x, y, 2.15), (0.28, 0.28, 4.0), g.CHAR, 0.03)
            g.box("Foot", (x, y, 0.06), (0.60, 0.60, 0.12), g.GALV, 0.015)
    for y in (-1.85, 1.85):
        g.box("GantryLong", (0, y, 4.05), (5.75, 0.28, 0.32), g.CHAR, 0.035)
    g.box("GantryBridge", (0, 0, 3.88), (0.36, 3.75, 0.34), g.YELLOW, 0.04)
    g.cyl("ZActuator", (0, 0, 3.15), 0.18, 1.18, g.YELLOW, vertices=18)
    g.cyl("Spindle", (0, 0, 2.48), 0.30, 0.42, g.CHAR, vertices=18)
    # two articulated assembly arms
    arm("ArmLeft", (-1.65, -0.95, 0.62), 1.0)
    arm("ArmRight", (1.65, 0.95, 0.62), -1.0)
    # feeder magazines
    for y in (-1.35, 1.35):
        g.box("FeederFrame", (2.55, y, 1.12), (0.82, 0.88, 1.70), g.CHAR, 0.045)
        for z in (0.75, 1.15, 1.55):
            g.box("FeederDrawer", (2.35, y, z), (0.45, 0.72, 0.25), g.GALV, 0.025)
            g.box("DrawerHandle", (2.10, y, z), (0.08, 0.34, 0.08), g.YELLOW, 0.012)
    # control console
    g.box("ControlTower", (-2.45, 2.15, 1.25), (0.90, 0.75, 2.20), g.CHAR, 0.055)
    g.box("ControlScreen", (-2.45, 1.76, 1.60), (0.68, 0.05, 0.62), g.RUBBER, 0.02)
    for x in (-2.65, -2.45, -2.25):
        g.cyl("ControlButton", (x, 1.72, 1.12), 0.06, 0.04, g.YELLOW if x == -2.45 else g.GALV,
              rot=(math.radians(90), 0, 0), vertices=12)
    return g.export_asset("bot_assembler_station")


def build_storage_rack():
    g.clear_scene()
    # upright frames, base plates, cross-bracing
    for x in (-2.45, 2.45):
        for y in (-0.72, 0.72):
            g.box("RackPost", (x, y, 2.25), (0.20, 0.20, 4.5), g.CHAR, 0.025)
            g.box("RackFoot", (x, y, 0.05), (0.50, 0.42, 0.10), g.GALV, 0.012)
    for z in (0.48, 1.68, 2.88, 4.08):
        g.box("ShelfBeamFront", (0, -0.72, z), (4.95, 0.20, 0.20), g.YELLOW, 0.025)
        g.box("ShelfBeamRear", (0, 0.72, z), (4.95, 0.20, 0.20), g.CHAR, 0.025)
        g.box("ShelfDeck", (0, 0, z + 0.08), (4.72, 1.28, 0.10), g.GALV, 0.018)
    # diagonal braces on both end frames
    for x in (-2.45, 2.45):
        g.box("DiagonalBrace", (x, 0, 2.18), (0.10, 1.75, 0.10), g.GALV, 0.012, rot=(math.radians(58), 0, 0))
    # bins with lips and handles
    for level_z in (0.92, 2.12, 3.32):
        for x in (-1.78, -0.60, 0.60, 1.78):
            g.box("StorageBin", (x, 0, level_z), (1.00, 1.08, 0.68), g.YELLOW, 0.035)
            g.box("BinFrontLip", (x, -0.56, level_z + 0.16), (0.88, 0.08, 0.34), g.CHAR, 0.015)
            g.box("BinHandle", (x, -0.61, level_z + 0.12), (0.34, 0.05, 0.08), g.GALV, 0.01)
    return g.export_asset("expanded_storage_rack")


def build_control_cabinet():
    g.clear_scene()
    g.box("Plinth", (0, 0, 0.12), (1.55, 0.92, 0.24), g.CHAR, 0.035)
    g.box("CabinetBody", (0, 0, 1.40), (1.40, 0.78, 2.55), g.CHAR, 0.075)
    g.box("DoorInset", (0, -0.415, 1.42), (1.22, 0.05, 2.25), g.GALV, 0.025)
    # hinges and locking handle
    for z in (0.72, 2.12):
        g.cyl("DoorHinge", (-0.58, -0.46, z), 0.055, 0.20, g.CHAR, vertices=12)
    g.box("HandleStem", (0.43, -0.47, 1.42), (0.07, 0.06, 0.42), g.CHAR, 0.012)
    g.box("HandleGrip", (0.50, -0.49, 1.58), (0.24, 0.07, 0.07), g.CHAR, 0.012)
    # louvers
    for z in np.linspace(0.55, 1.02, 7):
        g.box("VentLouver", (-0.23, -0.46, float(z)), (0.52, 0.05, 0.055), g.CHAR, 0.006)
    # status / breaker panel
    g.box("StatusPanel", (0.15, -0.46, 1.92), (0.72, 0.05, 0.58), g.CHAR, 0.022)
    for x in (-0.08, 0.14, 0.36):
        g.cyl("StatusLamp", (x, -0.49, 2.02), 0.055, 0.04,
              g.YELLOW if x == 0.14 else g.GALV, rot=(math.radians(90), 0, 0), vertices=12)
        g.box("Toggle", (x, -0.49, 1.80), (0.08, 0.05, 0.16), g.GALV, 0.01)
    # cable glands and top conduit
    for x in (-0.40, 0, 0.40):
        g.cyl("CableGland", (x, 0.05, 2.72), 0.075, 0.12, g.GALV, vertices=12)
    g.hose("TopConduit", [(-0.40, 0.05, 2.78), (-0.55, 0.12, 3.05), (-0.52, 0.18, 3.40)], 0.055)
    return g.export_asset("electrical_control_cabinet")


def build_material_bin():
    g.clear_scene()
    # tapered skip-like container with open top
    g.frustum("BinBody", 0.34, 1.65, 2.95, 2.55, 2.35, 1.95, g.GALV, True)
    # top rim
    for x in (-1.37, 1.37):
        g.box("TopRim", (x, 0, 2.02), (0.16, 2.56, 0.18), g.YELLOW, 0.02)
    for y in (-1.18, 1.18):
        g.box("TopRim", (0, y, 2.02), (2.72, 0.16, 0.18), g.YELLOW, 0.02)
    # forklift pockets and skids
    for x in (-0.72, 0.72):
        g.box("ForkPocket", (x, -0.98, 0.25), (0.50, 0.34, 0.32), g.CHAR, 0.025)
        g.box("Skid", (x, 0, 0.08), (0.28, 2.18, 0.16), g.CHAR, 0.018)
    # side ribs and lift lugs
    for x in (-0.95, 0, 0.95):
        g.box("FrontRib", (x, -1.08, 1.05), (0.12, 0.12, 1.35), g.CHAR, 0.015)
    for x in (-1.20, 1.20):
        for y in (-1.0, 1.0):
            g.cyl("LiftLug", (x, y, 1.88), 0.09, 0.16, g.CHAR,
                  rot=(math.radians(90), 0, 0), vertices=12)
    return g.export_asset("material_bin")


def build_salvage_truck():
    g.clear_scene()
    # Conventional heavy-duty 6x4 salvage truck: long hood, separate cab,
    # tandem rear axles and a deep reinforced scrap body.
    for y in (-1.16, 1.16):
        g.box("FrameRail", (0.05, y, 0.86), (9.6, 0.22, 0.34), g.CHAR, 0.035)
    for x in (-3.9, -2.4, -0.6, 1.15, 2.55, 3.75):
        g.box("FrameCrossmember", (x, 0, 0.86), (0.20, 2.46, 0.26), g.CHAR, 0.022)

    for x in (-3.02, 2.05, 3.48):
        g.cyl("Axle", (x, 0, 0.78), 0.16, 2.85, g.CHAR, rot=(math.radians(90), 0, 0), vertices=14, bevel=0.01)
        for y in (-1.50, 1.50):
            wheel("RoadWheel", x, y, 0.80, 0.72, 0.40)

    g.box("FrontBumper", (-4.93, 0, 1.10), (0.34, 2.92, 0.46), g.GALV, 0.055)
    for y in (-0.95, 0.95):
        g.cyl("TowEye", (-5.08, y, 1.04), 0.10, 0.16, g.CHAR, rot=(0, math.radians(90), 0), vertices=14)
    g.box("GrilleSurround", (-4.76, 0, 1.88), (0.18, 2.38, 1.12), g.YELLOW, 0.055)
    g.box("GrilleCore", (-4.87, 0, 1.88), (0.08, 2.05, 0.86), g.CHAR, 0.02)
    for y in np.linspace(-0.84, 0.84, 7):
        g.box("GrilleBar", (-4.93, float(y), 1.88), (0.06, 0.08, 0.78), g.GALV, 0.006)
    for y in (-0.90, 0.90):
        g.cyl("Headlamp", (-4.95, y, 2.34), 0.18, 0.11, g.GALV, rot=(0, math.radians(90), 0), vertices=18, bevel=0.015)
        g.cyl("MarkerLamp", (-4.95, y * 0.80, 1.37), 0.09, 0.08, g.YELLOW, rot=(0, math.radians(90), 0), vertices=14)

    g.box("HoodLower", (-4.02, 0, 1.92), (1.55, 2.62, 1.22), g.YELLOW, 0.12)
    g.box("HoodUpper", (-3.92, 0, 2.56), (1.42, 2.42, 0.34), g.YELLOW, 0.09)
    g.box("HoodCenter", (-3.80, 0, 2.79), (1.08, 2.12, 0.16), g.GALV, 0.055)
    for y in (-1.22, 1.22):
        for x in (-4.28, -3.92, -3.56):
            g.box("HoodLouver", (x, y, 2.16), (0.20, 0.05, 0.42), g.CHAR, 0.01, rot=(0, math.radians(-10), 0))

    g.box("CabLower", (-2.45, 0, 2.08), (1.70, 2.72, 1.92), g.YELLOW, 0.12)
    g.box("CabUpper", (-2.32, 0, 3.37), (1.48, 2.58, 1.18), g.YELLOW, 0.11)
    g.box("CabRoof", (-2.34, 0, 4.05), (1.72, 2.78, 0.24), g.GALV, 0.065)
    g.box("SunVisor", (-3.08, 0, 3.92), (0.20, 2.44, 0.18), g.CHAR, 0.025)
    g.box("Windshield", (-3.08, 0, 3.43), (0.08, 2.18, 0.78), g.RUBBER, 0.018, rot=(0, math.radians(-8), 0))
    for y in (-1.33, 1.33):
        side = -1 if y < 0 else 1
        g.box("SideWindow", (-2.28, y, 3.45), (0.92, 0.06, 0.70), g.RUBBER, 0.016)
        g.box("DoorPanel", (-2.28, y, 2.43), (1.02, 0.07, 1.05), g.YELLOW, 0.025)
        g.box("DoorHandle", (-2.02, y + side * 0.05, 2.72), (0.28, 0.05, 0.06), g.CHAR, 0.01)
        g.box("MirrorArm", (-3.05, y + side * 0.18, 3.36), (0.48, 0.06, 0.06), g.CHAR, 0.01)
        g.box("Mirror", (-3.25, y + side * 0.31, 3.36), (0.18, 0.08, 0.42), g.GALV, 0.028)
        g.box("CabStepUpper", (-2.52, y + side * 0.10, 1.32), (1.18, 0.34, 0.12), g.GALV, 0.015)
        g.box("CabStepLower", (-2.72, y + side * 0.11, 1.07), (0.82, 0.34, 0.11), g.GALV, 0.015)
    for y in (-0.82, -0.41, 0, 0.41, 0.82):
        g.cyl("RoofMarker", (-2.55, y, 4.21), 0.055, 0.08, g.YELLOW, vertices=12)

    for y in (-1.43, 1.43):
        g.box("FrontFenderTop", (-3.02, y, 1.52), (1.70, 0.32, 0.22), g.YELLOW, 0.055)
        g.box("FrontFenderFront", (-3.73, y, 1.25), (0.28, 0.32, 0.64), g.YELLOW, 0.045)
        g.box("FrontFenderRear", (-2.32, y, 1.25), (0.28, 0.32, 0.64), g.YELLOW, 0.045)
        g.box("RearMudguard", (2.76, y, 1.58), (3.10, 0.28, 0.22), g.CHAR, 0.045)

    g.cyl("FuelTank", (-1.16, -1.43, 1.27), 0.43, 1.55, g.GALV, rot=(0, math.radians(90), 0), vertices=20, bevel=0.025)
    for x in (-1.65, -0.68):
        g.cyl("TankBand", (x, -1.43, 1.27), 0.46, 0.08, g.CHAR, rot=(0, math.radians(90), 0), vertices=20, bevel=0.008)
    g.cyl("AirTank", (-1.18, 1.43, 1.22), 0.29, 1.25, g.CHAR, rot=(0, math.radians(90), 0), vertices=18, bevel=0.02)
    g.cyl("ExhaustStack", (-1.22, 1.08, 3.12), 0.11, 3.35, g.CHAR, vertices=14)
    g.cyl("ExhaustHeatShield", (-1.22, 1.08, 3.18), 0.16, 1.05, g.GALV, vertices=14, bevel=0.01)
    g.cyl("ExhaustCap", (-1.22, 1.08, 4.82), 0.18, 0.15, g.GALV, vertices=14)

    bed_cx = 1.75
    g.box("BedSubframe", (bed_cx, 0, 1.24), (5.25, 2.55, 0.28), g.CHAR, 0.035)
    g.box("BedFloor", (bed_cx, 0, 1.54), (5.20, 2.72, 0.24), g.RUST, 0.04)
    g.box("BedHeadboard", (-0.75, 0, 2.72), (0.24, 2.78, 2.55), g.CHAR, 0.045)
    for y in (-1.35, 1.35):
        side = -1 if y < 0 else 1
        g.box("BedSide", (bed_cx, y, 2.67), (5.05, 0.20, 2.28), g.RUST, 0.05)
        g.box("BedTopRail", (bed_cx, y + side * 0.03, 3.84), (5.18, 0.24, 0.18), g.GALV, 0.03)
        for x in (-0.35, 0.62, 1.59, 2.56, 3.53):
            g.box("BedRib", (x, y + side * 0.12, 2.67), (0.15, 0.14, 2.40), g.CHAR, 0.02)
    g.box("Tailgate", (4.30, 0, 2.62), (0.24, 2.76, 2.18), g.RUST, 0.05)
    g.box("TailgateTop", (4.40, 0, 3.75), (0.18, 2.86, 0.20), g.GALV, 0.025)
    for y in (-1.0, 1.0):
        g.cyl("TailgateHinge", (4.42, y, 1.66), 0.10, 0.42, g.CHAR, vertices=12)
        g.box("TailLamp", (4.47, y, 1.95), (0.10, 0.30, 0.32), g.YELLOW, 0.025)
    g.cyl("HoistCylinder", (0.72, 0, 1.05), 0.18, 2.10, g.YELLOW, rot=(0, math.radians(62), 0), vertices=18, bevel=0.015)
    g.cyl("HoistRod", (0.08, 0, 1.73), 0.09, 1.15, g.GALV, rot=(0, math.radians(62), 0), vertices=14, bevel=0.01)
    return g.export_asset("salvage_truck")

def main():
    assets = [
        build_baler(),
        conveyor_common("magnetic_sorting_conveyor", 8.0, 2.25, 1.42, False, True),
        build_hopper(),
        build_assembler(),
        conveyor_common("infeed_conveyor_8m", 8.0, 2.35, 1.38, False, False),
        conveyor_common("outfeed_conveyor_6m", 6.0, 1.95, 1.10, True, False),
        build_storage_rack(),
        build_control_cabinet(),
        build_material_bin(),
        build_salvage_truck(),
    ]
    print("HARDSURFACE_BATCH2_DONE")
    for asset in assets:
        print(asset)


if __name__ == "__main__":
    main()
