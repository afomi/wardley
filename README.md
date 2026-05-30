# Wardley.app

A tool for creating and exploring Wardley Maps.

Maps are strategic diagrams that show how components in a value chain evolve over time.
The interesting part isn't drawing a single map — it's what happens when you overlay maps from different people, compare how they frame the same domain, and watch where language converges or stays in tension.

This project is building toward that.

## What it does today

- Interactive map editor with drag-and-drop nodes, dependency edges, and evolution stages
- REST API and MCP server for LLM-assisted mapping
- Compact DSL compatible with Online Wardley Maps syntax
- Cross-map search
- Map fragments for reusable patterns
- Strategy Cycle (OODA/Gameplay) visualization
- GitHub login and API tokens for programmatic access

## Where it's headed

- Overlaying and diffing maps from multiple people on the same domain
- Community-contributed maps that reveal emergent patterns
- Virtual maps — latent structures that appear across many maps but were never explicitly drawn
- Map evolution over time as a first-class concept, not just current-state snapshots

## Running locally

```sh
mix setup
mix phx.server
```

Visit [localhost:4000](http://localhost:4000).

## LLM integration

Wardley.app is designed to work well with LLMs.
See [llms.txt](https://wardley.app/llms.txt) for the machine-readable spec, or [LLM_INTEGRATION.md](LLM_INTEGRATION.md) for the full guide.

The REST API supports bearer token auth.
The MCP server (`mix wardley.mcp`) exposes map operations as tool calls.
A `/wardley` Claude Code skill can map any project from any directory.

## Links

- [wardley.app](https://wardley.app)
- [Simon Wardley's blog](https://blog.gardeviance.org/)
- [Wardley Maps book](https://medium.com/wardleymaps) (free)
