# Cityfront

A shared-city game prototype: build the city, develop its economy, then defend it in an RTS battle. The same city state is saved and loaded across play sessions and will later feed the 3D and flight views.

## Run

Open the repository root (`project.godot`) in Godot 4.7.2 or later and press **F6/F5** (or Run Project). The project uses GDScript and Godot's Compatibility renderer.

The browser mockup remains at [`prototype/index.html`](prototype/index.html). It is useful for quick layout previews; the Godot project is now the gameplay implementation.

## Current vertical slice

- 32×20 top-down city grid, with support for loading earlier 24×18 browser layouts
- Build roads, homes, factories, power plants, barracks, and turrets around a headquarters
- Cash, population, steel production, power supply and demand, and automatic tank production
- RTS mode with player tank selection and move orders
- Five enemy raid waves, automatic turret fire, unit combat, and city health
- Save/load JSON that preserves city layout, economy, units, and wave progress
- Imports the earlier version 1 browser JSON layout; new saves use schema version 2

## Controls

- Click a build tool, then click a map tile to place it
- Right-click a tile in City Builder mode to demolish it
- **Tab** switches between City Builder and RTS modes
- In RTS mode, left-click a friendly tank and right-click to give it a move order
- **Space** deploys a tank from a barracks if resources allow
- **Start Raid** begins the next wave immediately; otherwise waves arrive every 45 seconds
- **R**, **1–5**, and **X** select road, homes, factory, power, barracks, turret, and bulldoze tools

## Shared city file

Schema version 2 contains `cityId`, `name`, `width`, `height`, `roads`, `buildings`, `units`, `resources`, and `wave`. Coordinates and object state are serialized independently of rendering, so a future 3D renderer can read the same city model.

## Next milestones

Add deterministic simulation tests, pathfinding and resource/territory nodes; then add 3D rendering against the same city data. The browser isometric view is still a visual mockup, not a full 3D renderer. Flight mode remains a later expansion.
