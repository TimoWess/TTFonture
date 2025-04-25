# TTFonture

TTFonture is an Elixir library for parsing and working with TrueType Font (.ttf) files. It provides a clean, typed API for extracting glyph data and font information with strong performance characteristics.

## Features

- **Robust file handling** with automatic resource management via `FileRegister`
- **Table-oriented API** for accessing specific font structures (head, cmap, glyf, etc.)
- **Complete glyph extraction** for both simple and compound glyphs
- **High-level font metadata** access through strongly-typed table structures
- **Low-level binary utilities** for efficient TTF format parsing
- **Configurable usage patterns** - use FileRegister for convenience or direct file handles for control

## Installation

Add `ttfonture` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ttfonture, "~> 0.1.0"}
  ]
end
```

## Usage

TTFonture offers two main usage patterns: using the `FileRegister` for managed file operations or working directly with file handles.

### Using FileRegister (Recommended)

The `FileRegister` provides centralized font file management with automatic table directory caching:

```elixir
# Start the FileRegister (typically in your supervision tree)
TTFonture.FileRegister.start_link()

# Register a font file (becomes the current file)
TTFonture.FileRegister.register("path/to/font.ttf")

# Read tables from the current font
{:ok, head_table} = TTFonture.Tables.Head.read()

# Work with the head table information
IO.puts("Font units per em: #{head_table.units_per_em}")
IO.puts("Font bounding box: #{head_table.x_min},#{head_table.y_min} to #{head_table.x_max},#{head_table.y_max}")

# When finished with all fonts
TTFonture.FileRegister.close_all()
```

### Using Direct File Handles

For more control or one-off operations:

```elixir
File.open("path/to/font.ttf", [:binary, :read], fn file ->
  # Read a specific table directly
  {:ok, head_table} = TTFonture.Tables.Head.read(file)
  
  # Work with table data
  if head_table.index_to_loc_format == 0 do
    IO.puts("Font uses short format for glyph locations")
  else
    IO.puts("Font uses long format for glyph locations")
  end
end)
```

### Working with Multiple Fonts

`FileRegister` makes it easy to work with multiple fonts concurrently:

```elixir
# Register fonts
TTFonture.FileRegister.register("fonts/first.ttf")
{:ok, head1} = TTFonture.Tables.Head.read()

TTFonture.FileRegister.register("fonts/second.ttf") 
{:ok, head2} = TTFonture.Tables.Head.read()

# Compare properties
if head1.units_per_em != head2.units_per_em do
  IO.puts("Fonts have different coordinate systems!")
end
```

### Reading Font Tables

Tables are organized as modules that match the standard TTF table structure:

```elixir
# Read the 'head' table that contains global font information
{:ok, head} = TTFonture.Tables.Head.read()

# Access information from the table
IO.puts("Created: #{DateTime.from_unix(head.created - 2082844800)}")

# Check if the font has a specific flag set
baseline_at_y0 = (head.flags &&& 1) == 1
```

## Architecture

TTFonture is structured around the standard tables defined in the TrueType specification:

- **High-level modules**:
  - `TTFonture` - Main module for library functions
  - `TTFonture.FileRegister` - File handle management
  - `TTFonture.BinaryReader` - Utilities for binary format parsing

- **Table modules**:
  - `TTFonture.Tables.Head` - Font header information
  - Other table modules following the same pattern

- **Glyph handling**:
  - `TTFonture.Glyphs.SimpleGlyph` - Parser for simple glyphs
  - `TTFonture.Glyphs.CompoundGlyph` - Parser for composite glyphs

## Development

### Running Tests

```bash
mix test
```
## License

[MIT License](LICENSE)
