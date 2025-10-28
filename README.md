# Procedural floorplans

Building outline maybe on a unit (meter) grid and (internal) wall grid maybe on half a unit (meter)?

## Map types

### Small

**1. Outline gerneration:**

- `3` Initial Verticies
- `0.4` Randomness
- `` Radius
- `` Grid Size

_\> Output: list of points defining the outline poligon._

**2. Room generation (abstract):**

- `n-m` Room Count

_\> Output: list off rooms with:_

- _relative are (`n/1`)_
- _corresponding house zone (public, private or halway)_
- _adjacency and connectivity constraints_

**3. Room generation (layout):**

- Outline Points _(from step 1)_
- Grid Size _(not nescesarryliy the same as in step 1)_
- Room List

_\> Output: idk._

### Normal

**1. Outline gerneration:**

- `6` Initial Verticies
- `0.6` Randomness
- `` Radius
- `` Grid Size

**2. Room generation (abstract):**

- `n-m` Room Count

**3. Room generation (layout):**

### Large

**1. Outline gerneration:**

- `11` Initial Verticies
- `0.9` Randomness
- `` Radius
- `` Grid Size

**2. Room generation (abstract):**

- `n-m` Room Count

**3. Room generation (layout):**
