"""Offline geometry checks; does not claim Roblox physics or playtesting."""
import json, math, hashlib, struct, unittest
from collections import deque
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"assets/factory/scrapyard_workshop"
class WorkshopTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.parts=json.loads((OUT/"scene.json").read_text())["parts"]
    def test_budget_and_sizes(self):
        self.assertLessEqual(len(self.parts),300)
        for p in self.parts:
            self.assertTrue(all(math.isfinite(x) and x>0 for x in p["size"]),p["name"])
    def test_player_sightline(self):
        for p in self.parts:
            if p["group"]=="ProductionHall" and p["collision"]:
                self.assertGreaterEqual(p["pos"][2]-p["size"][2]/2,60)
    def test_new_architecture_routes(self):
        # Expanded AABBs are conservative for these axis-aligned new colliders.
        obstacles=[]
        for p in self.parts:
            if p["collision"] and p["pos"][1]-p["size"][1]/2 < 6:
                x,y,z=p["pos"]; w,h,d=p["size"]
                obstacles.append((x-w/2-2.5,x+w/2+2.5,z-d/2-2.5,z+d/2+2.5))
        def free(x,z):
            return -116<x<116 and -90<z<90 and not any(a<=x<=b and c<=z<=d for a,b,c,d in obstacles)
        start=(-86,-47); visited={start}; q=deque([start])
        while q:
            x,z=q.popleft()
            for dx,dz in [(1,0),(-1,0),(0,1),(0,-1)]:
                n=(x+dx,z+dz)
                if n not in visited and free(*n): visited.add(n);q.append(n)
        for target in [(-88,25),(-47,5),(38,5),(70,12),(60,33),(-38,-40),(-25,-40),(-12,-40)]+[(76+c*11,-20+r*10) for c in range(2) for r in range(3)]:
            self.assertIn(target,visited,f"New architecture blocks route to {target}")
    def test_mesh_integrity(self):
        manifest=json.loads((OUT/"manifest.json").read_text())
        self.assertEqual(len(manifest["assets"]),13)
        for a in manifest["assets"]:
            raw=(OUT/a["file"]).read_bytes()
            self.assertEqual(raw[:4],b"glTF")
            self.assertEqual(struct.unpack_from("<I",raw,8)[0],len(raw))
            self.assertEqual(hashlib.sha256(raw).hexdigest(),a["sha256"])
            self.assertLessEqual(a["triangles"],5000)
if __name__=="__main__": unittest.main(verbosity=2)
