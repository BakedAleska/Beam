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

## License

MIT License

Copyright (c) 2026 BakedAleska

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

