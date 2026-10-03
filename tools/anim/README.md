# Animation tools

Asta's animations are designed here as data, checked against a model of the
R6 rig, then turned into Luau.

- `rig.py`: forward kinematics for an R6 rig plus Asta's sword. It mirrors
  `PoseAnimator`'s joint math and the sword grip in `Server/Kits/AntiMagic`.
- `design.py`: checks every keyframe and the in-betweens (slerped like
  `CFrame:Lerp`). The blade must stay out of the torso and head, and its tip
  above the floor.
- `asta_anims.py`: the animations. Run it to print blade tip positions and
  any problems.
- `emit.py`: writes `src/client/Kits/AntiMagic/Animations.luau`.

Needs Python 3 with numpy (`pip install numpy`). From the repo root:

```
python3 tools/anim/asta_anims.py
python3 tools/anim/emit.py src/client/Kits/AntiMagic/Animations.luau
stylua src/client/Kits/AntiMagic/Animations.luau
```

The check should end with `ALL CLEAN`. A few cases are allowed on purpose
(see `rules` in `asta_anims.py`): the entrance sword isn't checked before it's
drawn, the entrance slam plants the tip into the floor, and the air chop's tip
grazes it.
