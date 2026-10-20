#!/usr/bin/env python3
"""Optional offline design preview. This is NOT a Roblox screenshot or playtest."""
from pathlib import Path
import os
import math
import xml.etree.ElementTree as ET
os.environ.setdefault('MPLCONFIGDIR','/tmp/obby-matplotlib')
os.environ.setdefault('XDG_CACHE_HOME','/tmp/obby-preview-cache')
Path(os.environ['XDG_CACHE_HOME']).mkdir(parents=True,exist_ok=True)
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
import json

ROOT=Path(__file__).resolve().parents[1]
INK='#19152f';WHITE='#fbf7ff';MUTED='#bdb4d3'

def cuboid(pos,size,yaw):
    points=[];c,s=math.cos(yaw),math.sin(yaw)
    for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]:
        x*=size[0]/2;y*=size[1]/2;z*=size[2]/2
        points.append((pos[0]+x*c+z*s,pos[2]-x*s+z*c,pos[1]+y))
    return [[points[k] for k in face] for face in ((0,1,2,3),(4,5,6,7),(0,1,5,4),(2,3,7,6),(0,3,7,4),(1,2,6,5))]

def render():
    data=json.loads((ROOT/'dist/map-manifest.json').read_text())
    root=ET.parse(ROOT/'dist/BrainrotOrbit.rbxlx').getroot()
    stages={}
    for item in root.iter('Item'):
        name=item.find('Properties/string[@name="Name"]').text
        if name.startswith('Stage') and name[5:].isdigit():stages[int(name[5:])]=item
    fig=plt.figure(figsize=(20,13),facecolor=INK)
    fig.text(.045,.95,'BRAINROT ORBIT',fontsize=39,fontweight='bold',color=WHITE)
    fig.text(.047,.914,'100 STAGES  /  10 ORIGINAL WORLDS  /  ONE GLORIOUS BRAIN CELL',fontsize=13,color='#7bf5d0')
    fig.text(.047,.885,'Offline geometry preview • generated from the delivered place • not a Roblox screenshot',fontsize=10,color=MUTED)
    for index,(start,title) in enumerate(((1,'01  NOODLE NEBULA'),(31,'04  FROGGY FREQUENCY'),(81,'09  DISCO DUMPLING'))):
        ax=fig.add_axes((.025+index*.325,.39,.325,.46),projection='3d',facecolor=INK)
        allpos=[]
        for i in range(start,start+10):
            for part in stages[i].iter('Item'):
                if part.attrib['class']!='Part':continue
                props=part.find('Properties');cf=props.find('CoordinateFrame');sz=props.find('Vector3[@name="size"]');col=props.find('Color3[@name="Color"]')
                pos=[float(cf.find(k).text) for k in ('X','Y','Z')]
                size=[float(sz.find(k).text) for k in ('X','Y','Z')]
                color=tuple(float(col.find(k).text) for k in ('R','G','B'))
                yaw=math.atan2(float(cf.find('R02').text),float(cf.find('R00').text))
                faces=cuboid(pos,size,yaw)
                shades=[tuple(v*factor for v in color) for factor in (.72,.9,.76,1,.82,.97)]
                mesh=Poly3DCollection(faces,facecolors=shades,edgecolors='none',linewidths=0,zsort='average')
                ax.add_collection3d(mesh);allpos.append(pos)
        xs,ys,zs=zip(*allpos)
        ax.set_xlim(min(xs)-15,max(xs)+15);ax.set_ylim(min(zs)-15,max(zs)+15);ax.set_zlim(min(ys)-15,max(ys)+20)
        ax.set_box_aspect((max(xs)-min(xs)+30,max(zs)-min(zs)+30,(max(ys)-min(ys)+35)*1.5))
        ax.view_init(elev=35,azim=-72);ax.set_axis_off()
        fig.text(.05+index*.325,.41,title,fontsize=13,color=WHITE,fontweight='bold')
        fig.text(.05+index*.325,.385,'Stepping stones • beams • hazards • moving clouds',fontsize=9,color=MUTED)
    ax=fig.add_axes((.39,.12,.26,.18),facecolor=INK)
    ss=data['stages'];z=[s['start'][2] for s in ss];y=[s['start'][1] for s in ss]
    ax.fill_between(z,y,50,color='#46336c');ax.plot(z,y,color='#7bf5d0',lw=3)
    ax.set_title('CLIMBS & DESCENTS',loc='left',color=WHITE,fontweight='bold',fontsize=13,pad=18)
    ax.set_xlabel('Distance along the course (studs)',color=MUTED);ax.set_ylabel('Height',color=MUTED)
    ax.tick_params(colors=MUTED);ax.spines[['top','right']].set_visible(False)
    for s in ax.spines.values():s.set_color('#514368')
    plan=fig.add_axes((.06,.12,.26,.18),facecolor=INK)
    plan.plot(z,[s['start'][0] for s in ss],color='#ff8bcd',lw=3)
    plan.set_title('THE COURSE KEEPS CURVING',loc='left',color=WHITE,fontweight='bold',fontsize=13,pad=18)
    plan.set_xlabel('Distance along the course (studs)',color=MUTED);plan.set_ylabel('Sideways position',color=MUTED)
    plan.tick_params(colors=MUTED);plan.spines[['top','right']].set_visible(False)
    for spine in plan.spines.values():spine.set_color('#514368')
    fig.text(.71,.285,'FREE BY DESIGN',fontsize=15,color='#ffd777',fontweight='bold')
    fig.text(.71,.256,'Default-jump routes through all stages.\nNo permanent checkpoints.\nEarn colourful character cosmetics.\nOptional purchases never gate the course.',fontsize=11,color=MUTED,linespacing=1.9,va='top')
    fig.text(.05,.045,'MAP DATA VERIFIED  •  ROBLOX GAMEPLAY REMAINS UNVERIFIED',fontsize=10,color=MUTED)
    dest=ROOT/'docs/course-preview.png';fig.savefig(dest,dpi=120,facecolor=INK);plt.close(fig)
    print(dest)

if __name__=='__main__':render()
