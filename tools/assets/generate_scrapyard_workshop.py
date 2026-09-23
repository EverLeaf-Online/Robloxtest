"""Original Scrap-to-Bot architecture kit. Deterministic; no external assets.
Run with Python 3; emits the runtime blueprint and review geometry on the VM.
Coordinates are Roblox studs (Y up). Collision is explicit, never inferred from art.
"""
import json, math
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/factory/scrapyard_workshop"
P = []
C = dict(ink=[33,45,51], steel=[74,94,101], cream=[224,214,176],
         teal=[43,132,131], rust=[171,83,47], orange=[240,155,51],
         cyan=[98,227,226], ground=[81,91,85], asphalt=[49,62,65],
         rubber=[30,35,39], glass=[117,184,183])

def part(group, name, pos, size, color="steel", material="Metal", collision=False,
         rotation=(0,0,0), shape="Block", text=None):
    P.append(dict(group=group,name=name,pos=pos,size=size,color=C[color],
                  material=material,collision=collision,rotation=rotation,shape=shape,text=text))
def sign(group,name,pos,size,text,color="teal"):
    part(group,name,pos,size,color,text=text)
def beam(group,name,a,b,width,color="steel"):
    # X/Z-plane or Y/Z-plane not needed: explicit XYZ Euler for X/Y diagonal.
    dx,dy,dz=[b[i]-a[i] for i in range(3)]
    assert abs(dz)<1e-6
    length=math.hypot(dx,dy)
    part(group,name,[(a[i]+b[i])/2 for i in range(3)],[length,width,width],color,
         rotation=(0,0,math.degrees(math.atan2(dy,dx))))
def floor(group,name,x,z,w,d,color):
    height = .54 if name == "ReclaimedConcrete" else (.73 if name in ("PedestrianApron", "EntryWalk") else .63)
    part(group,name,[x,height,z],[w,.08,d],color,"Concrete")
def cylinder(group,name,pos,length,diam,color,vertical=False):
    part(group,name,pos,[length,diam,diam],color,rotation=(0,0,90 if vertical else 0),shape="Cylinder")

# Four physically legible departments, with a clear pedestrian apron in front.
floor("FactorySite","ReclaimedConcrete",0,0,234,184,"ground")
floor("FactorySite","ProductionSlab",7,29,150,66,"cream")
floor("FactorySite","ScrapGravel",-90,27,48,75,"rust")
floor("FactorySite","DispatchSlab",93,21,40,78,"teal")
floor("FactorySite","PedestrianApron",0,-16,222,18,"asphalt")
floor("FactorySite","EntryWalk",-86,-47,18,46,"asphalt")
for x in range(-102,108,12):
    part("FactorySite","WalkwayEdge",[x,.8,-25],[7,.08,.4],"orange","SmoothPlastic")
# Direction arrows lead from raw scrap to finished bots, outside machine collision.
for x in [-70,-48,-26,-4,18,40,62,84]:
    beam("ProcessWayfinding","ArrowUpper",(x-2,.76,-5),(x,.76,-5),.4,"orange")
    part("ProcessWayfinding","ArrowWingA",[x,.76,-4.4],[2,.08,.4],"orange",rotation=(0,35,0))
    part("ProcessWayfinding","ArrowWingB",[x,.76,-5.6],[2,.08,.4],"orange",rotation=(0,-35,0))
for x,label,color in [(-91,"01  /  SALVAGE","rust"),(-38,"02  /  SORT + RECOVER","orange"),
                       (37,"03  /  BUILD A BOT","teal"),(96,"04  /  DISPATCH","teal")]:
    sign("ProcessWayfinding","DepartmentSign",[x,10.5,58],[30,4,.6],label,color)

# Cutaway sawtooth workshop: roof only over rear service strip, never above the main camera/play lane.
for x in [-65,-41,-17,7,31,55,79]:
    part("ProductionHall","RearPier",[x,11,62],[1.2,21,1.2],"ink",collision=True)
    part("ProductionHall","PierFoot",[x,1.2,62],[2.6,1.4,2.6],"cream",collision=True)
part("ProductionHall","RearWall",[7,5,64],[146,9,1],"teal",collision=True)
part("ProductionHall","RearSkirting",[7,1.5,63.3],[146,1.5,.35],"rust")
for x in range(-62,79,4):
    part("ProductionHall","CorrugatedRib",[x,5,63.35],[.22,8,.25],"steel")
for x in [-53,-29,-5,19,43,67]:
    part("ProductionHall","Clerestory",[x,13,64],[21,5,.5],"glass","Glass")
    part("ProductionHall","RoofSlope",[x,21,56],[23.5,.7,18],"teal",rotation=(-12,0,0))
    part("ProductionHall","RoofFascia",[x,19.2,47],[23.5,1,.6],"cream")
    beam("ProductionHall","TrussLeft",(x-11,17.5,48),(x,21.5,48),.65,"orange")
    beam("ProductionHall","TrussRight",(x,21.5,48),(x+11,17.5,48),.65,"orange")
    part("ProductionHall","WorkLamp",[x,17,47],[7,.3,.8],"cream","Neon")
# Landmark: a repurposed robot head over the assembly workshop.
part("BotWorksLandmark","RobotHead",[37,25.5,61],[13,9,3],"orange")
part("BotWorksLandmark","Face",[37,25,59.3],[10,5.8,.5],"ink")
for x in [34.4,39.6]:
    part("BotWorksLandmark","Eye",[x,25.8,58.9],[2,1.8,.3],"cyan","Neon")
part("BotWorksLandmark","Smile",[37,23.5,58.9],[4,.5,.3],"cream")
part("BotWorksLandmark","Antenna",[37,31.2,61],[.5,3,.5],"steel")
cylinder("BotWorksLandmark","AntennaTip",[37,33,61],.5,1.2,"cyan")
sign("BotWorksLandmark","WorkshopName",[37,17,62.6],[32,4,.7],"SCRAP TO BOT","ink")

# Open crane with recognizable suspended electromagnet; all support feet outside salvage nodes.
for x in [-114,-67]:
    for z in [-2,56]:
        part("ScrapGantryCrane","CraneLeg",[x,13,z],[1.5,25,1.5],"orange",collision=True)
        part("ScrapGantryCrane","CraneFoot",[x,1.2,z],[4,1.5,4],"ink",collision=True)
    part("ScrapGantryCrane","Runway",[x,26,27],[2,2,62],"ink")
for z in [15,21]:
    part("ScrapGantryCrane","Bridge",[-90.5,27,z],[49,1.6,1.4],"orange")
part("ScrapGantryCrane","Trolley",[-98,28.5,18],[7,2,8],"teal")
cylinder("ScrapGantryCrane","Cable",[-98,21,18],13,.25,"ink",True)
cylinder("ScrapGantryCrane","Electromagnet",[-98,14,18],2,7,"orange",True)
cylinder("ScrapGantryCrane","MagnetUnderside",[-98,12.9,18],.25,6,"ink",True)
sign("ScrapGantryCrane","CraneBrand",[-90,27,14],[19,2,.25],"RECLAIM / REBUILD","ink")

# Back-of-yard open skips: crooked metal ribs and plates, not random scenery in walking lanes.
for i,(x,z,col) in enumerate([(-105,71,"rust"),(-88,71,"teal"),(-71,77,"orange")]):
    g="ScrapReceivingYard"
    part(g,"SkipFloor",[x,1.5,z],[13,1,10],"ink",collision=True)
    part(g,"SkipBack",[x,4,z+5],[13,5,.6],col,collision=True)
    for side in [-1,1]:
        part(g,"SkipSide",[x+side*6.3,4,z],[.6,5,10],col,collision=True)
    for n in range(5):
        part(g,"SalvagePlate",[x-4+n*2,3+(n%2),z],[3,.35,7],"steel",rotation=(n*7,19*n,12))
    sign(g,"SkipLabel",[x,3,z-5.1],[11,2,.4],["FERROUS","COPPER","ODD PARTS"][i],col)

# Dispatch is a shipping workshop with a partial canopy, distinct from the raw-material yard.
for x in [79,113]:
    part("MaterialWarehouse","DockPost",[x,8,50],[1.4,15,1.4],"ink",collision=True)
part("MaterialWarehouse","WarehouseWall",[96,6,55],[36,11,1],"teal",collision=True)
part("MaterialWarehouse","Canopy",[96,16,48],[37,.7,15],"orange",rotation=(-6,0,0))
for x in [83,96,109]:
    part("MaterialWarehouse","DispatchPallet",[x,1.1,39],[10,1,9],"rust",collision=True)
    part("MaterialWarehouse","ShippingCrate",[x,4,39],[7,5,6],"cream",collision=True)
    for dx in [-2.6,2.6]:
        part("MaterialWarehouse","CrateBand",[x+dx,4,35.9],[.35,5,.2],"teal")
    sign("MaterialWarehouse","CrateFace",[x,4.2,35.7],[4,2,.2],"BOT","teal")
sign("MaterialWarehouse","DockBanner",[96,13,54],[30,3,.5],"READY FOR WORK","ink")
# Charging frames follow the six existing gameplay pads (relocated as a coherent bay).
for idx in range(6):
    x,z=76+(idx%2)*11,-20+(idx//2)*10
    part("WorkerChargingBay","ChargerBack",[x,3.5,z+4.5],[7,5.5,.7],"teal")
    part("WorkerChargingBay","ChargeRail",[x,5,z+4],[5,.3,.25],"cyan","Neon")
    sign("WorkerChargingBay","SocketNumber",[x,3.6,z+4],[3,1,.25],f"{idx+1:02d}","ink")

# A small reclaimed-container office beside (not around) the main pedestrian route.
g="WorkshopOffice"
part(g,"BackWall",[-25,5,-49],[38,9,.6],"rust",collision=True)
for x in [-44,-6]:
    part(g,"SideWall",[x,5,-43],[.6,9,12],"rust",collision=True)
part(g,"OfficeRoof",[-25,10,-43],[40,.6,14],"teal")
sign(g,"OfficeSign",[-25,8,-36],[34,3,.5],"FACTORY CONTROL","ink")
for x in [-39,-25,-11]:
    part(g,"OfficeWindow",[x,4.6,-49.4],[9,4,.2],"glass","Glass")
# No office front wall: controls and avatar remain visible.

# Utility silhouette at rear: twin tanks, bent extraction pipes, restrained warning bands.
for x in [88,104]:
    cylinder("UtilityYard","RecoveryTank",[x,7,77],12,9,"steel",True)
    cylinder("UtilityYard","TankBand",[x,10,77],.6,9.3,"orange",True)
    cylinder("UtilityYard","VentStack",[x,17,77],8,3,"rust",True)
    part("UtilityYard","VentCap",[x,21,77],[5,.7,5],"ink")

# Circuit annex remains accessible over the existing bridge.
floor("CircuitBridgeApproach","BridgePaint",-94,-104.5,11,19,"teal")
for x in [-102,-86]:
    part("CircuitBridgeApproach","GatePost",[x,6,-115],[1,11,1],"teal")
sign("CircuitBridgeApproach","RecoveryGate",[-94,12,-115],[19,3,.6],"CIRCUIT RECOVERY","ink")
part("CircuitAnnex","RearWall",[-94,7,-164],[80,13,.8],"teal",collision=True)
for x in [-128,-111,-94,-77,-60]:
    part("CircuitAnnex","RecoveryCabinet",[x,5,-159],[9,8,4],"steel",collision=True)
    part("CircuitAnnex","CabinetStatus",[x,7,-161.1],[5,.3,.2],"cyan","Neon")


# Parked reclaim truck makes the receiving apron read as a working scrap business.
# Keep the prop under the architecture part budget while preserving a real truck silhouette.
g="SalvageTruck"

# Frame, bumper and grille establish the road-truck proportions.
part(g,"ChassisRail",[-53.5,2.8,-70],[31,1.0,4.8],"ink",collision=True)
part(g,"FrontBumper",[-32.9,3.2,-70],[.9,1.2,8.6],"cream",collision=True)
part(g,"FrontGrille",[-33.35,4.8,-70],[.35,2.8,5.9],"ink")

# A long two-piece hood reads much more naturally than the old rectangular nose.
part(g,"HoodLower",[-36.2,4.65,-70],[5.8,2.5,7.7],"orange",collision=True)
part(g,"HoodTop",[-37.4,5.9,-70],[4.1,1.05,7.3],"orange",rotation=(0,0,-8),collision=True)

# Cab shell and greenhouse.
part(g,"CabLower",[-42.0,5.7,-70],[6.8,4.9,7.9],"orange",collision=True)
part(g,"CabUpper",[-42.25,8.3,-70],[5.6,3.25,7.45],"orange",rotation=(0,0,-3),collision=True)
part(g,"CabRoof",[-42.35,10.05,-70],[6.5,.65,8.05],"cream")
part(g,"Windshield",[-39.45,8.35,-70],[.22,2.7,6.4],"glass","Glass",rotation=(0,0,-14))
for z in [-74.02,-65.98]:
    part(g,"SideWindow",[-42.45,8.35,z],[2.75,2.45,.18],"glass","Glass")
    part(g,"Mirror",[-39.95,8.85,z + (-.7 if z < -70 else .7)],[.2,1.05,.85],"glass","Glass")

# Truck-specific utility details.
part(g,"FuelTank",[-47.0,3.55,-73.8],[4.5,1.55,1.55],"steel",shape="Cylinder",rotation=(0,90,0))
part(g,"ExhaustStack",[-46.1,8.0,-66.5],[.55,6.3,.55],"ink")

# Deep salvage bed with a separate headboard, side walls and tailgate.
part(g,"BedFloor",[-58.2,4.15,-70],[18.2,.9,8.8],"rust",collision=True)
part(g,"BedHeadboard",[-49.35,7.0,-70],[.7,5.9,8.4],"teal",collision=True)
for z in [-74.15,-65.85]:
    part(g,"BedSide",[-58.25,6.95,z],[17.5,5.4,.7],"teal",collision=True)
part(g,"Tailgate",[-67.1,6.85,-70],[.7,5.1,8.2],"teal",collision=True)

# A small irregular load keeps the bed from reading as an empty box.
for i,(x,y,z,r) in enumerate((
    (-54.5,6.35,-71.3,18),
    (-59.1,6.75,-68.7,-23),
    (-63.2,6.55,-71.0,37),
)):
    part(g,"BedScrap",[x,y,z],[4.0,.7,2.1],"steel" if i else "cream",rotation=(8*(i%2),r,12))

# Front steer axle plus tandem rear axles.
for x in [-41.0,-58.3,-63.9]:
    for z in [-74.55,-65.45]:
        part(g,"Tire",[x,2.3,z],[1.7,4.6,4.6],"rubber",shape="Cylinder",rotation=(0,90,0),collision=True)

# Front fenders visually tie the steer wheels into the cab.
for z in [-74.18,-65.82]:
    part(g,"FrontFender",[-41.0,4.0,z],[4.9,1.35,.65],"orange",collision=True)

for z in [-72.55,-67.45]:
    part(g,"Headlight",[-33.52,4.75,z],[.28,1.15,1.2],"cream","Neon")
for z in [-72.5,-67.5]:
    part(g,"TailLamp",[-67.47,5.5,z],[.24,1.0,1.0],"orange","Neon")

sign(g,"TruckIdentity",[-58.2,7.0,-74.52],[11.5,2.0,.2],"SALVAGE CO.","ink")

def lua(v):
    if isinstance(v,dict): return "{" + ", ".join(k+" = "+lua(x) for k,x in v.items() if x is not None) + "}"
    if isinstance(v,(list,tuple)): return "{"+", ".join(lua(x) for x in v)+"}"
    if isinstance(v,bool): return "true" if v else "false"
    return json.dumps(v)
OUT.mkdir(parents=True,exist_ok=True)
(OUT/"scene.json").write_text(json.dumps(dict(schema=1,parts=P,palette=C),indent=2)+"\n")
runtime=ROOT/"src/server/Content/ScrapyardWorkshopKit.lua"
runtime.write_text("--!strict\n-- Generated by tools/assets/generate_scrapyard_workshop.py; edit the source generator.\nreturn table.freeze({\n"+"\n".join("\t"+lua(p)+"," for p in P)+"\n})\n")
print(json.dumps(dict(parts=len(P),groups=sorted(set(p["group"] for p in P)),colliders=sum(p["collision"] for p in P))))
