# Record Session to Memory

This command records key session activities to the memory MCP server.

## Usage

```
record-session [description]
```

## Description

Records the current session state to memory. The system will:
1. Create entities for key files and concepts 
2. Add observations about what was done
3. Connect related concepts with relationships

## Examples

```
record-session "Fixed isy hub issue in nixos configuration"
```

```
record-session "Analyzed June booking journal for missing punches"
```

## Implementation

This command uses these memory MCP tools:
- `memory_create_entities` to add new concepts
- `memory_add_observations` to record details  
- `memory_create_relations` to connect concepts