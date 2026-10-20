#!/usr/bin/env python3
"""Build an editable, standalone Roblox XML place. No packages or network required."""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
THEMES = [
    ("Noodle Nebula", "NOODLE MODE: ACTIVATED", (255, 116, 207), (120, 96, 255), "noodle"),
    ("Toast Goblin City", "THE FLOOR IS BREAKFAST", (255, 181, 71), (255, 101, 111), "toast"),
    ("Banana Broadcast", "LIVE FROM THE BANANAVERSE", (255, 230, 70), (79, 207, 196), "banana"),
    ("Froggy Frequency", "RIBBIT WITH THE RHYTHM", (121, 249, 142), (65, 169, 255), "frog"),
    ("Capybara Cloud Club", "MAXIMUM CHILL. MINIMUM FLOOR.", (255, 191, 148), (178, 143, 255), "capy"),
    ("Spaghetti Storm", "PASTA LA VISTA, GRAVITY", (255, 115, 88), (255, 205, 80), "noodle"),
    ("Galaxy Gooseworks", "HONK IF YOU CAN LAND", (174, 181, 255), (103, 236, 255), "goose"),
    ("Jellybean Jailbreak", "ESCAPE THE WOBBLE", (255, 109, 174), (161, 255, 216), "jelly"),
    ("Disco Dumpling", "ONE SMALL HOP. ONE BIG VIBE.", (211, 135, 255), (255, 233, 145), "dumpling"),
    ("Cosmic Crown", "THE FINAL BRAIN CELL", (255, 213, 76), (130, 244, 255), "crown"),
]
KINDS = ["stones", "zigzag", "beam", "lava", "spinner", "fade", "conveyor", "spring", "ferry", "choice"]
HINTS = {
    "stones": "Find your rhythm. Small jumps, big brain.",
    "zigzag": "Look where you want to land.",
    "beam": "Slow down. Your brain cell needs balance.",
    "lava": "Pink lava is still lava. Hop over it!",
    "spinner": "Watch the sweep, then jump the laser.",
    "fade": "Mint means solid. Amber means move!",
    "conveyor": "The arrows push. Steer against the drift.",
    "spring": "The cyan spring gives a gentle extra hop.",
    "ferry": "Ride the cloud, or take the side stones.",
    "choice": "Two lanes. Both work. Pick your vibe.",
}

def route(i):
    return (math.sin(i * .15) * 210 + math.sin(i * .38) * 28,
            95 + 40 * math.sin(i * .13) + 22 * math.sin(i * .055) + i * .6,
            i * 29)

def lerp(a, b, t): return tuple(x + (y-x)*t for x, y in zip(a, b))
def plus(a, b): return tuple(x+y for x,y in zip(a,b))

class Place:
    def __init__(self):
        self.root = ET.Element("roblox", version="4")
        self.serial = 0
        self.parts = 0
        self.manifest = {"title": "BRAINROT ORBIT", "stage_count": 100, "themes": [], "stages": []}

    def item(self, parent, cls, name):
        self.serial += 1
        el = ET.SubElement(parent, "Item", {"class": cls, "referent": f"RBX{self.serial}"})
        props = ET.SubElement(el, "Properties")
        self.prop(el, "string", "Name", name)
        return el

    def prop(self, item, kind, name, value):
        p = item.find("Properties")
        for previous in list(p):
            if previous.attrib.get('name') == name:p.remove(previous)
        el = ET.SubElement(p, kind, name=name)
        if kind in ("Vector3", "Color3"):
            for key, v in zip(("X", "Y", "Z") if kind == "Vector3" else ("R", "G", "B"), value):
                ET.SubElement(el, key).text = str(v)
        elif kind == "CoordinateFrame":
            pos, yaw = value
            for key,v in zip(("X","Y","Z"),pos): ET.SubElement(el,key).text=str(v)
            c,s=math.cos(yaw),math.sin(yaw)
            for key,v in zip(("R00","R01","R02","R10","R11","R12","R20","R21","R22"),(c,0,s,0,1,0,-s,0,c)):
                ET.SubElement(el,key).text=str(v)
        else: el.text = str(value).lower() if isinstance(value,bool) else str(value)
        return el

    def val(self,parent,name,value):
        cls = "BoolValue" if isinstance(value,bool) else "IntValue" if isinstance(value,int) else "NumberValue" if isinstance(value,float) else "StringValue"
        ob=self.item(parent,cls,name)
        self.prop(ob,"bool" if cls=="BoolValue" else "int" if cls=="IntValue" else "double" if cls=="NumberValue" else "string","Value",value)
        return ob

    def part(self,parent,name,pos,size,color,yaw=0,material="SmoothPlastic",solid=True,shape="Block",alpha=0):
        self.parts += 1
        ob=self.item(parent,"Part",name)
        for kind,key,v in [("bool","Anchored",True),("bool","CanCollide",solid),("bool","CanTouch",solid),
                           ("bool","CastShadow",solid),("Vector3","size",size),("CoordinateFrame","CFrame",(pos,yaw)),
                           ("Color3","Color",tuple(v/255 for v in color)),("float","Transparency",alpha),
                           ("token","Material",{"SmoothPlastic":272,"Neon":288,"Grass":1280,"Glass":1568}[material]),
                           ("token","shape",{"Block":1,"Ball":0,"Cylinder":2}[shape]),
                           ("token","TopSurface",0),("token","BottomSurface",0)]:
            self.prop(ob,kind,key,v)
        return ob

    def text(self,part,text,color=(255,255,255),face=1):
        gui=self.item(part,"SurfaceGui","Sign")
        self.prop(gui,"token","Face",face)
        self.prop(gui,"float","PixelsPerStud",32)
        self.prop(gui,"token","SizingMode",1)
        self.prop(gui,"bool","AlwaysOnTop",False)
        self.prop(gui,"float","LightInfluence",0)
        label=self.item(gui,"TextLabel","Text")
        size=ET.SubElement(label.find('Properties'),'UDim2',name='Size')
        for k,v in [('XS',1),('XO',0),('YS',1),('YO',0)]:ET.SubElement(size,k).text=str(v)
        self.prop(label,"float","BackgroundTransparency",1)
        self.prop(label,"string","Text",text)
        self.prop(label,"bool","TextScaled",True)
        self.prop(label,"bool","TextWrapped",True)
        self.prop(label,"token","Font",20)
        self.prop(label,"Color3","TextColor3",tuple(v/255 for v in color))

    def mascot(self,parent,kind,pos,color,scale=1):
        model=self.item(parent,"Model",kind.title()+" Buddy")
        def p(n,off,size,c=color,shape='Block'):
            return self.part(model,n,plus(pos,tuple(v*scale for v in off)),tuple(v*scale for v in size),c,solid=False,shape=shape)
        body=(7,6,4) if kind=='toast' else (7,5,5)
        p('Body',(0,0,0),body,shape='Ball' if kind in ('frog','jelly','dumpling','capy','noodle') else 'Block')
        p('Muzzle',(0,-.8,-2.6),(4,2,1.6),(255,237,202),shape='Ball')
        for x in (-1.7,1.7):
            p('Eye white',(x,1.2,-2.5),(1.8,1.8,.8),(255,255,255),shape='Ball')
            p('Pupil',(x+.18,1.2,-3),(0.75,1,.4),(31,25,61),shape='Ball')
            p('Feet',(x,-3,-.5),(2,1.2,3),(255,206,84),shape='Ball')
        if kind=='goose':p('Honk beak',(0,-.4,-3.6),(3,1.2,2.8),(255,168,47))
        if kind in ('crown','dumpling'):
            for x in (-2,0,2):p('Crown spike',(x,4,0),(1.5,3 if x==0 else 2,1.5),(255,220,64))
        if kind=='frog':
            for x in (-2.5,2.5):p('Ear bump',(x,2.5,0),(2,2,2),shape='Ball')
        if kind=='banana':
            p('Banana top',(-2,3,0),(2,5,3));p('Banana tip',(-2,6,0),(1.5,1.5,2),(112,74,51))
        if kind=='noodle':
            for i in range(5):p('Noodle tuft',(-2+i,3+(i%2),0),(.6,4,.7),(255,220,100))
        if kind=='capy':
            for x in (-2.5,2.5):p('Capy ear',(x,2.5,0),(1.5,1.5,1.5),shape='Ball')
        return model

    def build(self):
        workspace=self.item(self.root,'Workspace','Workspace')
        self.prop(workspace,'float','Gravity',196.2)
        self.prop(workspace,'float','FallenPartsDestroyHeight',-200)
        self.prop(workspace,'bool','StreamingEnabled',False)
        lighting=self.item(self.root,'Lighting','Lighting')
        for k,n,v in [('float','Brightness',2.5),('float','ClockTime',14),('float','EnvironmentDiffuseScale',.65),('float','EnvironmentSpecularScale',.5),
                       ('Color3','Ambient',(.43,.38,.58)),('Color3','OutdoorAmbient',(.63,.66,.8))]:self.prop(lighting,k,n,v)
        atmos=self.item(lighting,'Atmosphere','Candy Atmosphere')
        self.prop(atmos,'float','Density',.19);self.prop(atmos,'float','Offset',.1)
        self.prop(atmos,'Color3','Color',(.81,.87,1));self.prop(atmos,'Color3','Decay',(.64,.53,.85))
        bloom=self.item(lighting,'BloomEffect','Soft Neon')
        self.prop(bloom,'float','Intensity',.25);self.prop(bloom,'float','Size',24);self.prop(bloom,'float','Threshold',1.5)
        self.item(lighting,'Sky','Sky')
        world=self.item(workspace,'Folder','OrbitWorld')
        lobby=self.item(world,'Model','Lobby')
        first=route(0)
        self.part(lobby,'Lobby island',plus(first,(0,-4,-30)),(74,8,64),(88,68,139))
        self.part(lobby,'Lobby lawn',plus(first,(0,.1,-30)),(72,.5,62),(103,226,176),material='Grass')
        spawn=self.item(lobby,'SpawnLocation','OriginalStart')
        for k,n,v in [('Vector3','size',(8,1,8)),('CoordinateFrame','CFrame',(plus(first,(0,1,-38)),0)),
                      ('bool','Anchored',True),('bool','Neutral',True),('bool','AllowTeamChangeOnTouch',False),('int','Duration',0),
                      ('Color3','Color',(.4,.8,1)),('token','Material',288)]:self.prop(spawn,k,n,v)
        board=self.part(lobby,'Welcome sign',plus(first,(0,12,-54)),(40,13,1),(42,29,75),solid=False)
        self.text(board,'BRAINROT ORBIT\n100 STAGES • ONE RUN\nHOP. HONK. REPEAT.',face=5)
        self.text(board,'BRAINROT ORBIT\n100 STAGES • ONE RUN\nHOP. HONK. REPEAT.',face=2)
        guide=self.part(lobby,'Rules sign',plus(first,(-23,5,-22)),(16,7,1),(49,39,88),solid=False)
        self.text(guide,'NO CHECKPOINTS\nDeath resets your run.\nCoins & cosmetics stay.\nEvery stage is free.',face=5)
        self.text(guide,'NO CHECKPOINTS\nDeath resets your run.\nCoins & cosmetics stay.\nEvery stage is free.',face=2)
        self.mascot(lobby,'frog',plus(first,(25,5,-26)),(123,255,142),1.4)
        for x,z,title,color in ((-25,-42,'COIL CLUB',(255,218,111)),(25,-44,'BUDDY BOUTIQUE',(255,145,211))):
            stand=self.part(lobby,title,plus(first,(x,2,z)),(12,4,7),(74,53,117))
            self.part(lobby,'Kiosk canopy',plus(first,(x,10,z)),(15,1,10),color,solid=False)
            for side in (-6,6):self.part(lobby,'Kiosk pole',plus(first,(x+side,6,z+3)),(.6,8,.6),color,solid=False)
            sign=self.part(lobby,'Kiosk label',plus(first,(x,7,z-1)),(11,3,.3),(39,30,66),solid=False)
            self.text(sign,title,face=5);self.text(sign,title,face=2)
            prompt=self.item(stand,'ProximityPrompt','OpenShop')
            self.prop(prompt,'string','ActionText','Browse shop')
            self.prop(prompt,'string','ObjectText',title)
            self.prop(prompt,'float','MaxActivationDistance',12)
            self.prop(prompt,'bool','RequiresLineOfSight',False)
            self.prop(prompt,'float','HoldDuration',0)
        for j in range(6):
            self.part(lobby,'Lobby path tile',plus(first,(0,.45,-28+j*4)),(11,.25,3),(223,245,255),solid=False)
        for x in (-32,32):
            for z in (-50,-30,-10):
                self.part(lobby,'Candy tree trunk',plus(first,(x,4,z)),(1.5,8,1.5),(179,123,188),solid=False)
                self.part(lobby,'Candy tree',plus(first,(x,10,z)),(9,9,9),(255,150,219),shape='Ball',solid=False)
        stages=self.item(world,'Folder','Stages')
        for i in range(100):self.stage(stages,i)
        end=route(100)
        finish=self.item(world,'Model','VictoryIsland')
        self.part(finish,'Victory island',plus(end,(0,-3,18)),(60,6,54),(93,72,143))
        self.part(finish,'Victory gold',plus(end,(0,.2,18)),(58,.5,52),(255,221,111))
        pad=self.part(finish,'FinishPad',end,(14,1,10),(255,226,95),material='Neon')
        self.val(pad,'Stage',101);self.val(pad,'Safe',True)
        self.mascot(finish,'crown',plus(end,(0,7,25)),(255,193,83),2)
        sign=self.part(finish,'Victory sign',plus(end,(0,17,40)),(42,10,1),(56,35,89),solid=False)
        self.text(sign,'ALL 100. ABSOLUTE LEGEND.\n+100 COINS • +1 WIN\nUse RUN AGAIN to return.',face=5)
        self.text(sign,'ALL 100. ABSOLUTE LEGEND.\n+100 COINS • +1 WIN\nUse RUN AGAIN to return.',face=2)
        # Distant soft cloud clusters; no hidden collision traps.
        for i in range(35):
            p=route(i*3)
            for j in range(3):
                self.part(world,'Marshmallow cloud',plus(p,((-1 if i%2 else 1)*(55+j*8),-16-j*2,0)),(25,9,17),(240,230,255),shape='Ball',solid=False,alpha=.15)
        rep=self.item(self.root,'ReplicatedStorage','ReplicatedStorage')
        shared=self.item(rep,'Folder','OrbitShared')
        for name in ('Config','Rules'):self.script(shared,'ModuleScript',name,ROOT/'src/shared'/f'{name}.luau')
        remotes=self.item(rep,'Folder','OrbitRemotes')
        for name in ('Action','State','Notice'):self.item(remotes,'RemoteEvent',name)
        server=self.item(self.root,'ServerScriptService','ServerScriptService')
        self.script(server,'Script','OrbitServer',ROOT/'src/server/Game.server.luau')
        starter=self.item(self.root,'StarterPlayer','StarterPlayer')
        self.prop(starter,'float','CharacterWalkSpeed',16)
        self.prop(starter,'float','CharacterJumpPower',50)
        scripts=self.item(starter,'StarterPlayerScripts','StarterPlayerScripts')
        self.script(scripts,'LocalScript','OrbitClient',ROOT/'src/client/Game.client.luau')
        self.item(self.root,'StarterGui','StarterGui')
        self.item(self.root,'SoundService','SoundService')
        self.manifest['part_count']=self.parts
        return self.root

    def script(self,parent,cls,name,path):
        item=self.item(parent,cls,name)
        self.prop(item,'ProtectedString','Source',path.read_text())
        return item

    def stage(self,parent,i):
        num=i+1;zone=i//10;name,motto,primary,secondary,mascot=THEMES[zone]
        a,b=route(i),route(i+1)
        dx,dz=b[0]-a[0],b[2]-a[2];yaw=math.atan2(dx,dz)
        right=(math.cos(yaw),0,-math.sin(yaw))
        def point(t,side=0,up=0):return plus(lerp(a,b,t),(right[0]*side,up,right[2]*side))
        model=self.item(parent,'Model',f'Stage{num:03d}')
        self.val(model,'Stage',num);self.val(model,'Theme',name)
        kind=KINDS[i%10]
        self.val(model,'Kind',kind)
        pad=self.part(model,'SafePad',a,(13,1,10),primary,yaw,material='Neon')
        self.val(pad,'Stage',num);self.val(pad,'Safe',True)
        self.text(pad,f'{num:02d}  /  100\n{name.upper()}',(35,27,62))
        self.part(model,'Island underside',plus(a,(0,-2.2,0)),(14,3.5,11),secondary,yaw)
        # A visible bright side marker makes the direction of travel unmistakable.
        self.part(model,'Direction marker',point(.16,0,.15),(1,.25,2), (255,255,255),yaw,material='Neon',solid=False)
        tiles=[]
        def tile(t,side=0,width=7,depth=4.2,up=0,label='Tile',c=secondary):
            pos=point(t,side,up)
            ob=self.part(model,label,pos,(width,.8,depth),c,yaw)
            tiles.append({'position':pos,'size':(width,.8,depth),'t':t,'side':side,'name':label})
            # Side-edge icing is decorative; the collision surface stays predictable.
            for edge in (-1,1):
                stripe=plus(pos,(right[0]*edge*(width/2-.2),-.15,right[2]*edge*(width/2-.2)))
                self.part(model,'Candy edge',stripe,(.18,.25,depth),primary,yaw,material='Neon',solid=False)
            return ob
        if kind in ('stones','zigzag','conveyor','spring','fade'):
            for j,t in enumerate((.23,.37,.51,.65,.79)):
                side=((-1)**j)*2 if kind=='zigzag' else 0
                ob=tile(t,side,width=7 if zone<5 else 6,up=math.sin(t*math.pi)*1 if kind=='spring' else 0)
                if kind=='conveyor':
                    self.val(ob,'Conveyor',(-1 if j%2 else 1)*5.0)
                    if j==0:
                        self.val(ob,'SpeedBoost',True)
                        self.prop(ob,'Color3','Color',(1,.85,.3))
                        self.text(ob,'ZOOM',(35,27,62))
                if kind=='spring' and j==1:
                    self.val(ob,'Spring',True)
                    self.prop(ob,'Color3','Color',(0.2,1,1))
                    self.text(ob,'BOING',(20,45,80))
                if kind=='fade':
                    self.val(ob,'Fade',float(j*.8))
                    self.prop(ob,'Color3','Color',(.45,1,.78))
            if kind=='fade':
                # Stable bypass keeps every course beat completable without precise network timing.
                for t in (.23,.37,.51,.65,.79):tile(t,side=8,width=4,label='Stable side route',c=primary)
        elif kind=='beam':
            for t in (.23,.37,.51,.65,.79):tile(t,width=3.5 if zone>3 else 4.5,depth=5.4,label='Balance beam')
        elif kind in ('lava','spinner'):
            for t in (.23,.37,.51,.65,.79):tile(t,width=10,depth=5.5,label='Runway')
            if kind=='lava':
                for t in (.35,.63):
                    ob=self.part(model,'Lava ribbon',point(t,0,.7),(10,.6,.65),(255,62,126),yaw,material='Neon')
                    self.val(ob,'Hazard',True)
            else:
                ob=self.part(model,'Sweep laser',point(.51,0,1.1),(15,.7,.7),(255,62,126),yaw,material='Neon',solid=False)
                self.prop(ob,'bool','CanTouch',True)
                self.val(ob,'Spinner',float(1+zone*.05));self.val(ob,'Hazard',True)
        elif kind=='ferry':
            ferry=tile(.51,width=9,depth=8,label='Moving cloud',c=(190,240,255))
            self.val(ferry,'MoveDistance',3.0);self.val(ferry,'MovePeriod',4.0)
            for t in (.23,.37,.51,.65,.79):tile(t,side=8,width=4.5,label='Free side stones',c=primary)
            tile(.23,width=8);tile(.79,width=8)
        elif kind=='choice':
            for side in (-4,4):
                for t in (.23,.37,.51,.65,.79):tile(t,side,width=5,label='Left lane' if side<0 else 'Right lane',c=primary if side<0 else secondary)
        if i%10==0:
            self.manifest['themes'].append({'name':name,'motto':motto,'first_stage':num})
            # Theme arch is decorative and leaves the jumping corridor clear.
            for side in (-10,10):self.part(model,'Portal pillar',point(0,side,6),(2,13,2),secondary,yaw,material='Neon',solid=False)
            self.part(model,'Portal crown',point(0,0,13),(22,2,2),primary,yaw,material='Neon',solid=False)
            sign=self.part(model,'World banner',point(0,0,17),(30,5,1),(43,31,76),yaw,solid=False)
            self.text(sign,name.upper()+'\n'+motto,face=5);self.text(sign,name.upper()+'\n'+motto,face=2)
            self.mascot(model,mascot,point(.4,23,5),primary,1.3)
            self.part(model,'Mascot pedestal',point(.4,23,0),(16,2,14),secondary,yaw,solid=False)
        if i%3==0:
            for side in (-1,1):
                for k in range(3):
                    self.part(model,'Orbit confetti',point(.5,side*(14+k*2),3+k*2),(.8,1.8,.8),primary,yaw+k*.5,material='Neon',solid=False)
        # Every world has a distinct skyline and several original meme companions.
        side=1 if i%2==0 else -1
        if i%3==1:
            self.mascot(model,mascot,point(.5,side*27,4),primary,.9)
            self.part(model,'Buddy cloud island',point(.5,side*27,-1),(16,6,14),secondary,shape='Ball',solid=False)
        if i%2==0:
            for k in range(3):
                offset=side*(23+k*5)
                height=6+(k+zone)%3*3
                if mascot in ('toast','banana'):
                    self.part(model,'Goofy skyline',point(.6,offset,height/2-4),(4,height,5),primary,yaw,solid=False)
                    for level in range(2):
                        self.part(model,'Window glow',point(.6,offset,level*2-1),(2,.8,5.1),(255,245,181),yaw,material='Neon',solid=False)
                else:
                    self.part(model,'Candy moon',point(.6,offset,height+4),(4+k,4+k,4+k),primary if k%2 else secondary,shape='Ball',solid=False)
                    self.part(model,'Moon ribbon',point(.6,offset,height/2),( .2,height+2,.2),secondary,solid=False)
        if i%10 in (3,7):
            board=self.part(model,'Brain cell broadcast',point(.2,-side*23,9),(14,5,.6),(45,30,73),yaw,solid=False)
            self.text(board,('BRAIN CELL LOADING...' if i%10==3 else motto),face=5)
            self.text(board,('BRAIN CELL LOADING...' if i%10==3 else motto),face=2)
        self.manifest['stages'].append({'number':num,'theme':name,'kind':kind,'hint':HINTS[kind],
            'start':a,'end':b,'yaw':yaw,'tiles':tiles,'length':math.dist(a,b)})

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=ROOT/'dist/BrainrotOrbit.rbxlx')
    args=parser.parse_args();place=Place();root=place.build()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    ET.indent(root)
    # Roblox format sniffers expect the <roblox header as the first bytes.
    ET.ElementTree(root).write(args.output,encoding='utf-8',xml_declaration=False)
    (args.output.parent/'map-manifest.json').write_text(json.dumps(place.manifest,indent=2)+'\n')
    print(f'Built {args.output}: 100 stages, {place.parts} parts, {place.serial} objects')

if __name__=='__main__':main()
