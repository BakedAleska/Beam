# BakedAleska: Beam

A lightweight ECS (Entity Component System) framework for Roblox.

## Features

- **Event-Driven** - Priority-based event system with double-buffering
- **Memory Safe** - Weak keys for automatic cleanup
- **Type-Safe** - Full Luau type annotations

## Documentation
https://bakedaleska.github.io/Beam/

## Basic Usage

```lua
local world = require(game.ServerScriptService.Beam.World)

-- Initialize world
local World = world.new()

-- Create entity
local Entity = World.CraftEntity()

-- Assign components
World.AssignComponent(Entity, "Health", { value = 100 })
World.AssignComponent(Entity, "Position", { x = 0, y = 0, z = 0 })

-- Add systems
World.AddSystem(game.ServerScriptService.Beam.Systems.Movement, 1)

-- Fire events
World.FireEvent({
    Event = "Damage",
    Entity = Entity,
    Priority = 10
})

-- Call update each frame
game.RunService.Heartbeat:Connect(World.Update)
```

## Credits

- **Author** - BakedAleska

