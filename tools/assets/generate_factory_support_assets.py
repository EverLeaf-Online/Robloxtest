import math
import random
import sys
from pathlib import Path

import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_factory_core_assets as g

OUT = g.OUT

def export(name):
    g.uv_all()
    g.ground_center()
    d = OUT / "support" / name
    d.mkdir(parents=True, exist_ok=True)
    path = d / f"{name}.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_texcoords=True,
        export_normals=True,
    )
    print("GENERATED", path)
    return path

def small_hopper():
    g.clear_scene()
    g.frustum("SmallHopper", 0.75, 1.75, 2.5, 2.5, 1.0, 1.0, g.GALV, True)
    for x in (-0.9,0.9):
        for y in (-0.9,0.9):
            g.box("Leg",(x,y,0.38),(0.16,0.16,0.75),g.CHAR)
            g.box("Foot",(x,y,0.04),(0.32,0.32,0.08),g.GALV,0.01)
    g.box("Gate",(0,-0.55,0.82),(0.8,0.14,0.55),g.YELLOW)
    return export("small_scrap_hopper")

def chassis_fixture():
    g.clear_scene()
    g.box("Base",(0,0,0.16),(3.8,2.6,0.32),g.CHAR)
    for y in (-0.82,0.82):
        g.box("Rail",(0,y,0.52),(3.2,0.24,0.35),g.GALV)
    for x in (-1.1,0,1.1):
        g.box("LocatorA",(x,-0.82,0.86),(0.26,0.42,0.55),g.YELLOW)
        g.box("LocatorB",(x,0.82,0.86),(0.26,0.42,0.55),g.YELLOW)
    for x in (-1.35,1.35):
        g.cyl("Clamp",(x,0,0.88),0.16,0.8,g.CHAR,rot=(math.radians(90),0,0),vertices=16)
    return export("bot_chassis_fixture")

def parts_rack():
    g.clear_scene()
    width=3.6
    for x in (-1.7,1.7):
        for y in (-0.48,0.48):
            g.box("Post",(x,y,1.8),(0.16,0.16,3.6),g.CHAR)
    for z in (0.45,1.35,2.25,3.15):
        g.box("Shelf",(0,0,z),(3.55,1.15,0.12),g.GALV,0.02)
        for x in (-1.15,-0.38,0.38,1.15):
            g.box("PartsBin",(x,-0.16,z+0.3),(0.58,0.72,0.45),g.YELLOW,0.03)
    return export("parts_feeder_rack")

def pallet_parts():
    g.clear_scene()
    for y in (-0.48,0,0.48):
        g.box("PalletRail",(0,y,0.08),(2.3,0.16,0.16),g.CHAR,0.01)
    for x in (-0.9,0,0.9):
        g.box("PalletCross",(x,0,0.18),(0.16,1.25,0.16),g.CHAR,0.01)
    rng=random.Random(11)
    for i in range(12):
        x=rng.uniform(-0.8,0.8); y=rng.uniform(-0.38,0.38)
        if i%2:
            g.cyl(f"Part_{i}",(x,y,0.52+rng.uniform(0,0.25)),rng.uniform(0.12,0.25),rng.uniform(0.2,0.5),g.GALV,vertices=16)
        else:
            g.box(f"Part_{i}",(x,y,0.45+rng.uniform(0,0.2)),(rng.uniform(0.25,0.55),rng.uniform(0.2,0.5),rng.uniform(0.25,0.55)),g.RUST,0.02,rot=(rng.random()*0.4,rng.random()*0.4,rng.random()*1.2))
    return export("palletized_mechanical_parts")

def scrap_cart():
    g.clear_scene()
    g.box("CartBase",(0,0,0.38),(2.6,1.7,0.18),g.CHAR)
    g.box("CartFloor",(0,0,0.58),(2.45,1.55,0.12),g.GALV)
    g.box("Rear",(1.18,0,1.25),(0.14,1.55,1.35),g.GALV)
    for y in (-0.72,0.72):
        g.box("Side",(0,y,1.05),(2.35,0.14,0.95),g.GALV)
    g.box("Front",(-1.18,0,0.95),(0.14,1.55,0.75),g.YELLOW)
    for x in (-0.88,0.88):
        for y in (-0.78,0.78):
            g.cyl("Wheel",(x,y,0.2),0.22,0.12,g.RUBBER,rot=(math.radians(90),0,0),vertices=16)
    g.box("Handle",(1.55,0,1.2),(0.65,0.10,0.10),g.YELLOW)
    return export("forklift_scrap_cart")

def steel_drum():
    g.clear_scene()
    g.cyl("Drum",(0,0,0.48),0.31,0.96,g.YELLOW,vertices=24,bevel=0.03)
    for z in (0.12,0.48,0.84):
        g.cyl("Ring",(0,0,z),0.325,0.05,g.CHAR,vertices=24,bevel=0.01)
    g.cyl("TopCap",(0,0,0.97),0.27,0.04,g.GALV,vertices=24,bevel=0.01)
    return export("industrial_steel_drum")

def stairs():
    g.clear_scene()
    steps=10
    step_w=1.35
    run=2.8
    rise=2.0
    for i in range(steps):
        x=-run/2 + (i+0.5)*run/steps
        z=(i+0.5)*rise/steps
        g.box(f"Step_{i}",(x,0,z),(run/steps+0.03,step_w,0.12),g.GALV,0.01)
    angle=math.atan2(rise,run)
    length=math.hypot(run,rise)
    for y in (-0.68,0.68):
        g.box("Stringer",(0,y,rise/2),(length,0.12,0.16),g.CHAR,0.02,rot=(0,-angle,0))
        for x,z in [(-1.2,0.35),(0,1.15),(1.2,1.9)]:
            g.box("RailPost",(x,y,z+0.55),(0.07,0.07,1.1),g.YELLOW,0.01)
        g.box("Handrail",(0,y,rise/2+0.85),(length,0.07,0.07),g.YELLOW,0.01,rot=(0,-angle,0))
    return export("factory_stairs_2m")

def bollard():
    g.clear_scene()
    g.cyl("Bollard",(0,0,0.62),0.14,1.24,g.YELLOW,vertices=20,bevel=0.02)
    g.cyl("Base",(0,0,0.06),0.32,0.12,g.CHAR,vertices=20,bevel=0.01)
    for x in (-0.18,0.18):
        for y in (-0.18,0.18):
            g.cyl("Anchor",(x,y,0.12),0.035,0.05,g.GALV,vertices=10,bevel=0.005)
    return export("safety_bollard")

def ventilation():
    g.clear_scene()
    g.box("FanFrame",(0,0,1.5),(2.5,0.32,2.5),g.CHAR,0.05)
    g.cyl("Shroud",(0,-0.19,1.5),1.0,0.18,g.GALV,rot=(math.radians(90),0,0),vertices=32,bevel=0.02)
    g.cyl("Hub",(0,-0.32,1.5),0.22,0.24,g.YELLOW,rot=(math.radians(90),0,0),vertices=20)
    for i in range(6):
        a=i*math.tau/6
        x=math.cos(a)*0.47
        z=1.5+math.sin(a)*0.47
        g.box("Blade",(x,-0.36,z),(0.62,0.10,0.20),g.CHAR,0.02,rot=(0,a,0))
    g.box("Duct",(0,0.4,1.5),(2.1,0.7,2.1),g.GALV,0.04)
    return export("ventilation_fan_module")

def pipe_rack():
    g.clear_scene()
    for x in (-1.85,1.85):
        g.box("RackPost",(x,0,1.55),(0.16,0.16,3.1),g.CHAR)
        g.box("Foot",(x,0,0.05),(0.45,0.45,0.1),g.GALV,0.01)
    for z in (1.2,2.0,2.8):
        g.box("CrossBeam",(0,0,z),(3.9,0.16,0.16),g.CHAR)
    for z,r,mat in ((1.3,0.11,g.GALV),(2.1,0.14,g.YELLOW),(2.9,0.09,g.GALV)):
        g.cyl("Pipe",(0,0,z),r,3.7,mat,rot=(0,math.radians(90),0),vertices=16)
    for x in (-1.0,1.0):
        g.cyl("Valve",(x,-0.16,2.1),0.19,0.06,g.CHAR,rot=(math.radians(90),0,0),vertices=16)
    return export("utility_pipe_rack_4m")

def light_fixture():
    g.clear_scene()
    g.box("Housing",(0,0,0.18),(1.4,0.52,0.32),g.CHAR,0.05)
    g.box("Lens",(0,-0.28,0.18),(1.18,0.05,0.18),g.GALV,0.02)
    g.box("Mount",(0,0,0.52),(0.16,0.16,0.7),g.GALV)
    return export("factory_light_fixture")

def floor_grate():
    g.clear_scene()
    g.box("Frame",(0,0,0.06),(2.1,2.1,0.12),g.CHAR,0.02)
    for x in np.linspace(-0.9,0.9,15):
        g.box("Slat",(float(x),0,0.13),(0.055,1.9,0.07),g.GALV,0.005)
    for y in np.linspace(-0.9,0.9,6):
        g.box("Cross",(0,float(y),0.16),(1.9,0.045,0.045),g.CHAR,0.005)
    return export("floor_grate_2m")

def dock_bumper():
    g.clear_scene()
    g.box("BackPlate",(0,0,0.62),(2.7,0.16,1.25),g.GALV,0.03)
    for x in (-0.78,0.78):
        g.box("RubberBumper",(x,-0.22,0.62),(0.48,0.36,0.95),g.RUBBER,0.06)
    for x in (-1.15,1.15):
        for z in (0.25,1.0):
            g.cyl("Bolt",(x,-0.12,z),0.055,0.05,g.CHAR,rot=(math.radians(90),0,0),vertices=12)
    return export("loading_bay_dock_bumper")

def unlock_button():
    g.clear_scene()
    g.cyl("Base",(0,0,0.12),0.65,0.24,g.CHAR,vertices=28,bevel=0.04)
    g.cyl("YellowRing",(0,0,0.26),0.56,0.18,g.YELLOW,vertices=28,bevel=0.03)
    g.cyl("Button",(0,0,0.40),0.34,0.20,g.GALV,vertices=28,bevel=0.05)
    return export("ground_unlock_button")

def kiosk():
    g.clear_scene()
    g.box("Plinth",(0,0,0.12),(1.25,1.0,0.24),g.CHAR,0.04)
    g.box("Body",(0,0,1.25),(1.05,0.78,2.25),g.CHAR,0.07)
    g.box("FrontPanel",(0,-0.41,1.42),(0.88,0.05,1.38),g.GALV,0.03)
    g.box("Screen",(0,-0.45,1.72),(0.66,0.03,0.48),g.RUBBER,0.02)
    for x in (-0.22,0,0.22):
        g.cyl("Button",(x,-0.46,1.18),0.055,0.04,g.YELLOW if x==0 else g.GALV,rot=(math.radians(90),0,0),vertices=12)
    g.box("TopCap",(0,0,2.42),(1.18,0.9,0.18),g.YELLOW,0.04)
    return export("factory_hub_kiosk")

def charging_station():
    g.clear_scene()
    g.box("Base",(0,0,0.12),(2.6,1.8,0.24),g.CHAR)
    for x in (-0.7,0.7):
        g.box("Dock",(x,0,0.48),(0.88,1.35,0.55),g.GALV,0.04)
        g.box("Contact",(x,-0.71,0.55),(0.48,0.05,0.24),g.YELLOW,0.02)
    g.box("BackTower",(0,0.62,1.45),(2.2,0.38,2.5),g.CHAR,0.05)
    g.box("PowerPanel",(0,0.40,1.75),(1.2,0.05,0.72),g.YELLOW,0.03)
    g.hose("CableA",[(-0.7,0.38,1.55),(-0.9,0.15,1.2),(-0.75,-0.25,0.72)],0.04)
    g.hose("CableB",[(0.7,0.38,1.55),(0.9,0.15,1.2),(0.75,-0.25,0.72)],0.04)
    return export("bot_charging_station")

def storage_rack():
    g.clear_scene()
    for x in (-2.35,2.35):
        for y in (-0.65,0.65):
            g.box("Post",(x,y,2.1),(0.18,0.18,4.2),g.CHAR)
    for z in (0.5,1.65,2.8,3.95):
        g.box("Shelf",(0,0,z),(4.8,1.55,0.14),g.GALV)
    for z in (0.9,2.05,3.2):
        for x in (-1.65,-0.55,0.55,1.65):
            g.box("StorageBin",(x,0,z),(0.9,1.05,0.62),g.YELLOW,0.03)
    return export("expanded_storage_rack")

def smelter():
    g.clear_scene()
    g.cyl("FurnaceBody",(0,0,1.55),1.15,3.1,g.CHAR,vertices=32,bevel=0.05)
    g.cyl("TopRing",(0,0,3.05),1.25,0.24,g.YELLOW,vertices=32,bevel=0.03)
    g.cyl("BaseRing",(0,0,0.18),1.28,0.36,g.GALV,vertices=32,bevel=0.03)
    g.box("ChargeDoor",(0,-1.13,1.85),(1.15,0.14,0.95),g.YELLOW,0.04)
    g.cyl("Exhaust",(0.55,0.2,4.15),0.28,2.1,g.GALV,vertices=20,bevel=0.02)
    g.box("Control",(1.55,-0.3,1.15),(0.75,0.65,1.55),g.CHAR,0.05)
    g.hose("FuelLine",[(1.2,0.5,0.8),(1.5,0.65,1.2),(1.45,0.55,1.8)],0.05)
    return export("scrap_smelter_furnace")

def cooling_conveyor():
    g.clear_scene()
    # Short perforated cooling line with fan housings.
    g.add_frame(4.0,1.8,1.0,leg_z=0.75)
    g.box("Belt",(0,0,1.0),(3.7,1.35,0.12),g.GALV,0.02)
    for x in np.linspace(-1.55,1.55,7):
        g.cyl("Roller",(float(x),0,0.95),0.08,1.4,g.CHAR,rot=(math.radians(90),0,0),vertices=12)
    for x in (-1.0,1.0):
        g.box("FanBox",(x,0,1.75),(0.85,1.55,0.65),g.CHAR,0.04)
        g.cyl("FanHub",(x,-0.82,1.75),0.16,0.08,g.YELLOW,rot=(math.radians(90),0,0),vertices=16)
    return export("cooling_conveyor_4m")

def main():
    for fn in [
        small_hopper, chassis_fixture, parts_rack, pallet_parts, scrap_cart,
        steel_drum, stairs, bollard, ventilation, pipe_rack, light_fixture,
        floor_grate, dock_bumper, unlock_button, kiosk, charging_station,
        storage_rack, smelter, cooling_conveyor
    ]:
        fn()

if __name__ == "__main__":
    main()
