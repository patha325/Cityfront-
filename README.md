# Cityfront

A shared-city prototype for a multi-mode city-building game.

The city is the common world: build its layout in the city-builder, then use that same map as the basis for RTS and flight modes as the project grows.

## Prototype

Open [prototype/index.html](prototype/index.html) in a modern browser. It runs locally without a server or external libraries.

- Place roads and building types in the 2D top-down map.
- Switch to the isometric view to inspect the same city.
- Save the layout to a JSON file and load it again in either view.
- Right-click a tile or choose Bulldoze to clear it.

Keyboard shortcuts: `R` road, `1` homes, `2` civic, `3` industry, `4` power, `X` bulldoze.

## Shared city format

The prototype exports version 1 JSON with a stable map size and tile records:

```json
{
  "schemaVersion": 1,
  "cityId": "…",
  "name": "New City",
  "width": 24,
  "height": 18,
  "tiles": [
    { "x": 4, "y": 6, "kind": "road" },
    { "x": 5, "y": 6, "kind": "house" }
  ]
}
```

## Scope

This is an early interaction and data-format slice. The isometric renderer is a lightweight canvas preview, not a full 3D renderer. Economy, simulation, terrain, combat, aircraft, and engine integration are future milestones.
