"""Conservative geometry checks; these are not Roblox physics playtests."""
import importlib.util
import math
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('builder',ROOT/'tools/build_place.py')
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)

def rect(pos,size,yaw):
    c,s=math.cos(yaw),math.sin(yaw)
    return [(pos[0]+x*c+z*s,pos[2]-x*s+z*c) for x,z in [(-size[0]/2,-size[2]/2),(size[0]/2,-size[2]/2),(size[0]/2,size[2]/2),(-size[0]/2,size[2]/2)]]

def point_segment(p,a,b):
    dx,dz=b[0]-a[0],b[1]-a[1]
    t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz)))
    return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dz)

def polygon_gap(a,b):
    # SAT overlap check for two oriented rectangles, then nearest vertex/edge pair.
    separated=False
    for poly in (a,b):
        for i in range(4):
            u,v=poly[i],poly[(i+1)%4];axis=(v[1]-u[1],u[0]-v[0])
            aa=[x*axis[0]+z*axis[1] for x,z in a];bb=[x*axis[0]+z*axis[1] for x,z in b]
            if max(aa)<min(bb) or max(bb)<min(aa):separated=True
    if not separated:return 0
    return min(point_segment(p,poly[i],poly[(i+1)%4]) for points,poly in ((a,b),(b,a)) for p in points for i in range(4))

def can_jump(a,b):
    rise=(b['position'][1]+b['size'][1]/2)-(a['position'][1]+a['size'][1]/2)
    disc=50**2-2*196.2*rise
    if disc<0:return False
    flight=(50+math.sqrt(disc))/196.2
    gap=polygon_gap(rect(a['position'],a['size'],a['yaw']),rect(b['position'],b['size'],b['yaw']))
    # Keep 0.6 studs of landing/launch margin; no coils or springs assumed.
    return gap+.6 <= 16*flight and abs(rise)<6

class MapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.place=builder.Place();cls.root=cls.place.build();cls.stages=cls.place.manifest['stages']

    def test_all_100_stages_and_ten_worlds(self):
        self.assertEqual([s['number'] for s in self.stages],list(range(1,101)))
        self.assertEqual(len(self.place.manifest['themes']),10)
        self.assertEqual(len({s['theme'] for s in self.stages}),10)
        for kind in builder.KINDS:self.assertEqual(sum(s['kind']==kind for s in self.stages),10)

    def test_course_climbs_drops_and_curves(self):
        heights=[s['start'][1] for s in self.stages]
        self.assertGreater(sum(b>a for a,b in zip(heights,heights[1:])),20)
        self.assertGreater(sum(b<a for a,b in zip(heights,heights[1:])),20)
        self.assertGreater(max(heights)-min(heights),65)
        xs=[s['start'][0] for s in self.stages]
        self.assertGreater(max(xs)-min(xs),350)
        self.assertGreater(max(s['yaw'] for s in self.stages)-min(s['yaw'] for s in self.stages),.6)

    def test_each_stage_has_free_default_jump_route(self):
        for stage in self.stages:
            with self.subTest(stage=stage['number'],kind=stage['kind']):
                start={'position':stage['start'],'size':(13,1,10),'yaw':stage['yaw']}
                end={'position':stage['end'],'size':(13,1,10),
                     'yaw':self.stages[stage['number']]['yaw'] if stage['number']<100 else 0}
                tiles=[]
                for tile in stage['tiles']:
                    if tile['name']=='Moving cloud':continue
                    if stage['kind']=='fade' and tile['name']!='Stable side route':continue
                    tiles.append({**tile,'yaw':stage['yaw']})
                nodes=[start]+tiles+[end];seen={0};queue=[0]
                while queue:
                    i=queue.pop()
                    for j,node in enumerate(nodes):
                        if j not in seen and can_jump(nodes[i],node):seen.add(j);queue.append(j)
                self.assertIn(len(nodes)-1,seen,'No conservative free jump route')

    def test_unique_referents_and_valid_instance_parents(self):
        ids=[item.attrib['referent'] for item in self.root.iter('Item')]
        self.assertEqual(len(ids),len(set(ids)))
        for item in self.root.iter('Item'):
            self.assertIsNotNone(item.find('Properties/string[@name="Name"]'))

    def test_no_paid_gates_or_checkpoints(self):
        spawns=[i for i in self.root.iter('Item') if i.attrib['class']=='SpawnLocation']
        self.assertEqual(len(spawns),1)
        for i in self.root.iter('Item'):
            name=i.find('Properties/string[@name="Name"]').text
            self.assertNotIn('Checkpoint',name)
            self.assertNotIn('PaidGate',name)

    def test_hazards_visible_and_side_routes_solid(self):
        hazards=0
        for item in self.root.iter('Item'):
            name=item.find('Properties/string[@name="Name"]').text
            if name in ('Lava ribbon','Sweep laser'):
                hazards+=1
                self.assertEqual(item.find('Properties/float[@name="Transparency"]').text,'0')
                self.assertEqual(item.find('Properties/bool[@name="CanTouch"]').text,'true')
            if name in ('Stable side route','Free side stones'):
                self.assertEqual(item.find('Properties/bool[@name="CanCollide"]').text,'true')
        self.assertEqual(hazards,30)

    def test_deterministic_rebuild(self):
        other=builder.Place();other.build()
        self.assertEqual(ET.tostring(self.root),ET.tostring(other.root))

    def test_original_place_preserved(self):
        original=(ROOT/'obby_Game.rbxl').read_bytes()
        self.assertEqual(len(original),90653)
        self.assertTrue(original.startswith(b'<roblox!'))

if __name__=='__main__':unittest.main(verbosity=2)
