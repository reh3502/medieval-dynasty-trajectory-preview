#!/usr/bin/env python3
"""Compare observed flight to the actual last preview, without fitting either."""
import argparse,json,math,statistics
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('log',type=Path)
parser.add_argument('--output',type=Path)
parser.add_argument('--latest-session',action='store_true',help='Analyze only the last mod load')
args=parser.parse_args()
events=[]
for line in args.log.read_text(errors='replace').splitlines():
    marker='[TrajectoryPreview] '
    if marker not in line:continue
    kind,_,payload=line.split(marker,1)[1].partition(' ')
    try:data=json.loads(payload)
    except json.JSONDecodeError:continue
    events.append((kind,data))
if args.latest_session:
    starts=[i for i,(kind,_) in enumerate(events) if kind=='started']
    if starts:events=events[starts[-1]:]
shots=[];current=None;owners={};pending={};unmatched=[]
session=0;version='unknown'
for kind,data in events:
    if kind=='started':
        unmatched.extend(row for rows in pending.values() for row in rows)
        current=None;owners={};pending={};session+=1;version=data.get('version','unknown')
    elif kind=='vanilla_release':
        current={'release':data,'flight':[],'contacts':[],'session':session,'version':version};shots.append(current)
    elif kind in ('flight','flight_ended'):
        name=data['projectile']
        if name not in owners and current and 0<=data['time']-current['release']['time']<1:
            owners[name]=current
            current['contacts'].extend(pending.pop(name,[]))
        if name in owners and kind=='flight':owners[name]['flight'].append(data)
    elif kind=='vanilla_contact':
        shot=owners.get(data['projectile'])
        if shot:shot['contacts'].append(data)
        else:pending.setdefault(data['projectile'],[]).append(data)
unmatched.extend(row for rows in pending.values() for row in rows)
def distance(a,b):return math.sqrt(sum((a[k]-b[k])**2 for k in 'XYZ'))
def nearest_path(points,position):
    best=math.inf
    for a,b in zip(points,points[1:]):
        a,b=a['position'],b['position']
        delta={k:b[k]-a[k] for k in 'XYZ'}
        length2=sum(v*v for v in delta.values())
        t=0 if length2==0 else max(0,min(1,sum((position[k]-a[k])*delta[k] for k in 'XYZ')/length2))
        best=min(best,distance(position,{k:a[k]+t*delta[k] for k in 'XYZ'}))
    return best

def interpolate(points,t):
    for a,b in zip(points,points[1:]):
        if a['time']<=t<=b['time']:
            f=(t-a['time'])/(b['time']-a['time'])
            return {k:a['position'][k]+f*(b['position'][k]-a['position'][k]) for k in 'XYZ'}
report=[]
for shot in shots:
    release=shot['release'];preview=release.get('preview')
    if not preview:continue
    result=preview['result'];raw=result['points']
    points=[raw[k] for k in sorted(raw,key=int)] if isinstance(raw,dict) else raw
    errors=[];spatial_errors=[]
    for row in shot['flight']:
        if not row.get('active'):continue
        point=interpolate(points,row['time']-release['time'])
        if point is not None:
            errors.append(distance(point,row['position']))
            spatial_errors.append(nearest_path(points,row['position']))
    item={'session':shot['session'],'version':shot['version'],
        'association':'projectile flight/lifecycle event within one second of preceding local release (heuristic)',
        'preview_basis':release.get('preview_basis','current_frame'),
        'release_time':release['time'],'speed':release['speed'],'pull':release['pull'],
        'preview_age_seconds':release['time']-preview['time'],'preview_status':result['status'],
        'matched_flight_samples':len(errors),'observed_contacts':len(shot['contacts'])}
    if errors:
        ordered=sorted(errors)
        item.update(median_path_error_cm=statistics.median(errors),p95_path_error_cm=ordered[math.ceil(len(ordered)*.95)-1],worst_path_error_cm=max(errors))
    if spatial_errors:
        item['median_distance_to_curve_cm']=statistics.median(spatial_errors)
        item['worst_distance_to_curve_cm']=max(spatial_errors)
    if shot['contacts'] and release.get('origin'):
        origin=release['origin'];contact=shot['contacts'][0]['position']
        item['impact_range_m']=distance(origin,contact)/100
        item['horizontal_range_m']=math.hypot(contact['X']-origin['X'],contact['Y']-origin['Y'])/100
        item['elevation_change_m']=(contact['Z']-origin['Z'])/100
    if shot['contacts']:
        item['observed_actor']=shot['contacts'][0].get('actor')
        item['observed_component']=shot['contacts'][0].get('component')
    if result.get('hit'):
        item['predicted_actor']=result['hit'].get('actor')
        item['predicted_component']=result['hit'].get('component')
    if release.get('owner_velocity'):
        item['owner_speed_cm_s']=distance(release['owner_velocity'],dict.fromkeys('XYZ',0))
    if result.get('hit') and shot['contacts']:
        item['impact_error_cm']=distance(result['hit']['position'],shot['contacts'][0]['position'])
    elif shot['contacts']:item['impact_comparison']='No predicted hit to compare; investigate collision query/filter/horizon.'
    report.append(item)
output={'method':'Unfitted last-preview positions interpolated at time since observed release; sway and sampling delay retained. Small development sample, not gate acceptance.','shots':report,
    'unmatched_contacts':unmatched,
    'releases_without_preview':sum(not shot['release'].get('preview') for shot in shots)}
text=json.dumps(output,indent=2)
if args.output:
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(text+'\n')
print(text)
