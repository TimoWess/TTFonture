# TTFonture

TTFonture is an Elixir library for parsing and working with TrueType Font (.ttf) files. It provides a clean, typed API for extracting glyph data and font information.

## Features

- Read and parse TrueType Font files
- Extract glyph outlines (both simple and compound glyphs)
- Access font metadata from various TTF tables
- Low-level binary data utilities for TTF format handling

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

### Reading Font Tables

```elixir
# Get the table directory (metadata about all tables in the font)
table_directory = TTFonture.get_table_directory("path/to/font.ttf")

# Access specific tables
head_table = Keyword.get(table_directory["head"], :offset)
```

### Working with Glyphs

```elixir
# Get all glyph data
glyphs = TTFonture.read_all_glyphs("path/to/font.ttf")

# Access a specific glyph
glyph_locations = TTFonture.get_all_glyph_locations("path/to/font.ttf")
File.open("path/to/font.ttf", [:read, :binary], fn file ->
  third_glyph = TTFonture.read_glyph(file, Enum.at(glyph_locations, 2))
end)
```

### Examples

Reading basic font information:

```elixir
File.open("path/to/font.ttf", [:read, :binary], fn file ->
  # Get the table directory
  table_directory = TTFonture.get_table_directory(file)
  
  # Read from the head table
  head_offset = Keyword.get(table_directory["head"], :offset)
  
  # Position at the head table
  :file.position(file, head_offset)
  
  # Skip version
  TTFonture.BinaryReader.skip_bytes(file, 4)
  
  # Read font revision
  {:ok, font_revision} = TTFonture.BinaryReader.read_fixed(file)
  
  IO.puts("Font revision: #{font_revision}")
end)
```

## Module Structure

- `TTFonture` - Main module for high-level font operations
- `TTFonture.Glyphs.SimpleGlyph` - Parser for simple (non-composite) glyphs
- `TTFonture.Glyphs.CompoundGlyph` - Parser for compound glyphs

## Development

### Running Tests

```bash
mix test
```
## License

[MIT License](LICENSE)
