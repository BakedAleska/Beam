# BakedAleska: Beam

A lightweight ECS (Entity Component System) framework for Roblox.

## Features

- **Event-Driven** - Priority-based event system with double-buffering
- **Automatic Replication** - Built-in client synchronization via [Replica](https://github.com/MadStudioRoblox/Replica)
- **Memory Safe** - Weak keys for automatic cleanup
- **Type-Safe** - Full Luau type annotations

## Basic Usage

```lua
local World = require(game.ServerScriptService.Beam.World)

-- Initialize world
local world = World.new()

-- Create entity
local entity = World.Craft_Entity()

-- Assign components
World.Assign_Component(entity, "Health", { value = 100 })
World.Assign_Component(entity, "Position", { x = 0, y = 0, z = 0 })

-- Fire events
World.Fire_Event({
    Event = "Damage",
    Entity = entity,
    Priority = 10
})

game.RunService.Heartbeat:Connect(World.Update)
```

## Credits

- **Author** - BakedAleska
- **Replication** - [MadStudio's Replica](https://github.com/MadStudioRoblox/Replica)