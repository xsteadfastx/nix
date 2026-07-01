# Record June Bookings to Memory

This command records the June 2026 booking correction workflow to memory.

## Usage

```
record-june-bookings
```

## Description

Records the June 2026 booking journal review and correction request to the memory MCP server.

## What It Does

1. Creates a `booking-correction` entity for the June 2026 workflow
2. Adds observations about:
   - The missing booking (29.06.2026)
   - The incomplete booking (30.06.2026)  
   - The correction request submitted
3. Creates entities for key dates and times
4. Links the dates to the correction workflow

## Example Output

```
Added to memory:
- Entity: booking-correction (June 2026)
- Observation: "Submitted Depart correction for 29.06.2026 14:30"
- Entity: 29.06.2026
- Entity: 30.06.2026 
- Relation: 29.06.2026 -> refersTo -> booking-correction
```