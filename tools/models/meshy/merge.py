# Builds every Meshy character end to end: rig.py (joints + clean weights) then retarget.py (UAL clips) ->
# assets/3d/kahramanmaras/meshy_<name>.glb (one GLB per character, 512 px JPEG texture).
# Run: blender -b --factory-startup --python-exit-code 1 -P tools/models/meshy/merge.py [-- name ...]
# Meshy's own walk/run/idle clips (out/<name>/{walk,run,idle}.glb) are no longer used: they bent the body.
import os, runpy

HERE = os.path.dirname(os.path.abspath(__file__))
runpy.run_path(os.path.join(HERE, "rig.py"), run_name="__main__")
runpy.run_path(os.path.join(HERE, "retarget.py"), run_name="__main__")
