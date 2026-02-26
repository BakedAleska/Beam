# BakedAleska: Beam

A lightweight ECS (Entity Component System) framework for Roblox.

## Features

- **Event-Driven** - Priority-based event system with double-buffering
- **Automatic Replication** - Built-in client synchronization via [Replica](https://github.com/MadStudioRoblox/Replica)
- **Memory Safe** - Weak keys for automatic cleanup
- **Type-Safe** - Full Luau type annotations

## Documentation
https://bakedaleska.github.io/Beam/

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

