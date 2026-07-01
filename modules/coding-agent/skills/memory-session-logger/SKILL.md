# Memory Session Logger Skill

This skill automatically documents session activities to the memory MCP server. It creates entities for key concepts, creates relations between them, and adds observations when you run commands or use tools.

## Features

- Automatically creates entities when you use new tools or reference key concepts
- Builds a knowledge graph of your session activities  
- Creates connections between related concepts
- Adds detailed observations to entities

## Usage

When you use this skill, it will:
1. Monitor your session for key activities
2. Create entities in the memory graph
3. Link related concepts with relations  
4. Add notes and observations to entities

## Example

When you fix code in `fix-isy-hub.nix`, it will:
- Create an `nixos-configuration` entity 
- Add an `editing` observation to that entity
- Create a `fix-isy-hub.nix` file entity
- Link the file to the configuration with a `refersTo` relation

## Tools Used

- `memory_create_entities` - Create new concepts, files, projects
- `memory_create_relations` - Connect entities with relationships
- `memory_add_observations` - Add notes and details to existing entities

## When This Skill Triggers

This skill is meant to be used in a monitoring loop. When running, it watches for:
- Code changes in key files
- Tool usage
- Commands executed 
- New concepts introduced during session

It will automatically write to the memory graph without requiring manual prompts.