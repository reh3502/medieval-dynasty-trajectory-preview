#!/usr/bin/env python3
"""Regression checks for measurement bookkeeping, independent of the game."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

analyzer = Path(__file__).with_name('analyze-shots.py')
point = {'X': 0, 'Y': 0, 'Z': 0}
release = {'time': 1, 'speed': 11000, 'pull': 1,
    'origin': {'X': -300, 'Y': -400, 'Z': -1200},
    'owner_velocity': {'X': 0, 'Y': 0, 'Z': 0}, 'preview': {
    'time': 1, 'result': {'status': 'hit', 'hit': {'position': point},
    'points': [{'time': 0, 'position': point},
               {'time': 1, 'position': {'X': 10, 'Y': 0, 'Z': 0}}]}}}
contact = {'time': 1.01, 'projectile': 'arrow', 'position': point}
flight = {'time': 1.02, 'projectile': 'arrow', 'position': point, 'active': True}
events = [('started', {'version': 'old'}), ('vanilla_release', release),
          ('vanilla_contact', contact), ('flight', flight),
          ('started', {'version': 'new'}), ('vanilla_release', release),
          # Reused name must not inherit a match from the old mod session.
          ('vanilla_contact', contact)]
with tempfile.TemporaryDirectory() as directory:
    log = Path(directory) / 'fixture.log'
    log.write_text('\n'.join('[TrajectoryPreview] '+kind+' '+json.dumps(data)
                             for kind, data in events))
    def run(*extra):
        return json.loads(subprocess.check_output(
            [sys.executable, str(analyzer), str(log), *extra], text=True))
    result = run()
    assert len(result['shots']) == 2
    assert result['shots'][0]['observed_contacts'] == 1
    assert result['shots'][0]['impact_error_cm'] == 0
    assert result['shots'][0]['impact_range_m'] == 13
    assert result['shots'][0]['horizontal_range_m'] == 5
    assert result['shots'][0]['elevation_change_m'] == 12
    assert result['shots'][0]['owner_speed_cm_s'] == 0
    assert result['shots'][1]['observed_contacts'] == 0
    assert len(result['unmatched_contacts']) == 1
    latest = run('--latest-session')
    assert len(latest['shots']) == 1 and latest['shots'][0]['version'] == 'new'
    assert len(latest['unmatched_contacts']) == 1
    assert 'impact_error_cm' not in latest['shots'][0]
    assert 'impact_range_m' not in latest['shots'][0]
    with log.open('a') as stream:
        stream.write('\n[TrajectoryPreview] flight_ended '+json.dumps(
            {'time':1.02,'projectile':'arrow','samples':0}))
    immediate=run('--latest-session')['shots'][0]
    assert immediate['matched_flight_samples']==0
    assert immediate['observed_contacts']==1 and immediate['impact_error_cm']==0, 'Immediate contact was lost despite a matching projectile lifecycle event'
print('PASS early contact retention, session isolation and latest-session selection')
