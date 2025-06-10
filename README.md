# TTFonture

[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

A comprehensive Elixir library for parsing and analyzing TrueType font files (.ttf). TTFonture provides a clean, functional API for accessing font metadata, glyph data, and typography information from TrueType fonts.

## Features

- **Complete TrueType Support**: Parse all major TrueType tables (head, name, glyf, cmap, etc.)
- **Glyph Processing**: Handle both simple and compound glyphs with full outline data
- **Smart Caching**: Automatic table caching for improved performance
- **Type Safety**: Comprehensive type specifications and structured data
- **Memory Efficient**: Lazy loading with intelligent resource management
- **Well Documented**: Extensive documentation with practical examples

## Installation

Add `ttfonture` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ttfonture, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
# Start the FileRegister (typically in your supervision tree)
TTFonture.FileRegister.start_link()

# Register and work with a font file
TTFonture.FileRegister.register("fonts/opensans.ttf")

# Read font metadata
{:ok, head_table} = TTFonture.Tables.Head.read()
{:ok, name_table} = TTFonture.Tables.Name.read()

# Get font metrics
{:ok, hhea_table} = TTFonture.Tables.Hhea.read()
ascent = hhea_table.ascent
descent = hhea_table.descent

# Read glyph data
{:ok, glyphs} = TTFonture.Tables.Glyf.read()

# Clean up when done
TTFonture.FileRegister.close_all()
```

## Architecture

TTFonture is organized into several key modules:

### Core Modules

- **`TTFonture`** - Main module with table directory parsing
- **`TTFonture.FileRegister`** - Centralized file and cache management
- **`TTFonture.BinaryReader`** - Low-level binary data reading utilities

### Table Modules

TTFonture supports all major TrueType tables:

- **`TTFonture.Tables.Head`** - Font header information
- **`TTFonture.Tables.Name`** - Font naming information
- **`TTFonture.Tables.Maxp`** - Memory requirements and glyph count
- **`TTFonture.Tables.Loca`** - Glyph location data
- **`TTFonture.Tables.Glyf`** - Glyph outline data
- **`TTFonture.Tables.Cmap`** - Character to glyph mapping
- **`TTFonture.Tables.Hhea`** - Horizontal metrics header
- **`TTFonture.Tables.Hmtx`** - Horizontal metrics data
- **`TTFonture.Tables.Post`** - PostScript information
- **`TTFonture.Tables.OS2`** - OS/2 and Windows metrics

### Glyph Processing

- **`TTFonture.Glyphs.SimpleGlyph`** - Simple glyph outline processing
- **`TTFonture.Glyphs.CompoundGlyph`** - Compound glyph component handling

## Usage Examples

### Font Information Extraction

```elixir
# Register a font
TTFonture.FileRegister.register("fonts/arial.ttf")

# Get basic font information
{:ok, head} = TTFonture.Tables.Head.read()
units_per_em = head.units_per_em
font_bbox = {head.x_min, head.y_min, head.x_max, head.y_max}

# Get font names
{:ok, name_table} = TTFonture.Tables.Name.read()
font_names = Enum.map(name_table.name_records, fn record ->
  {record.name_id, record.name}
end)

# Get font metrics
{:ok, hhea} = TTFonture.Tables.Hhea.read()
line_height = hhea.ascent - hhea.descent + hhea.line_gap
```

### Get the offset of a specific Glyph

```elixir
# Get all glyph locations
{:ok, locations} = TTFonture.Tables.Loca.get_absolute_offsets()

# Get a specific glyph
{:ok, glyph_id} = TTFonture.Tables.Cmap.char_to_glyph_id("A")
glyph_offset = Enum.at(locations, glyph_offset)

{:ok, glyph_list} = TTFonture.Tables.Glyf.read()
glyph_A = Enum.at(glyph_list, glyph_id)

# Process simple vs compound glyphs
case glyph_A do
  %TTFonture.Glyphs.SimpleGlyph{} = simple ->
    IO.puts("Simple glyph with #{simple.number_of_contours} contours")

  %TTFonture.Glyphs.CompoundGlyph{} = compound ->
    IO.puts("Compound glyph with #{length(compound.components)} components")
end
```

### Font Metrics and Typography

```elixir
# Get horizontal metrics
{:ok, hmtx} = TTFonture.Tables.Hmtx.read()

# Access advance widths and side bearings
Enum.each(hmtx.h_metrics, fn metric ->
  IO.puts("Advance: #{metric.advance_width}, LSB: #{metric.left_side_bearing}")
end)

# Get OS/2 table for additional metrics
{:ok, os2} = TTFonture.Tables.OS2.read()

# Check font style properties
style_flags = TTFonture.Tables.OS2.style_flags(os2)
is_bold = style_flags.bold
is_italic = style_flags.italic

# Get weight class
weight = TTFonture.Tables.OS2.weight_class(os2.us_weight_class)
```

### Working with Multiple Fonts

```elixir
# FileRegister can manage multiple fonts
TTFonture.FileRegister.register("fonts/arial.ttf")
{:ok, arial_head} = TTFonture.Tables.Head.read()

TTFonture.FileRegister.register("fonts/helvetica.ttf")
{:ok, helvetica_head} = TTFonture.Tables.Head.read()

# Check cache statistics
stats = TTFonture.FileRegister.cache_stats()
IO.puts("Cached tables: #{Enum.join(stats.cached_tables, ", ")}")

# Close specific font
TTFonture.FileRegister.close("fonts/arial.ttf")
```

### Direct File Access (Without FileRegister)

```elixir
# For more control, work directly with file handles
{:ok, file} = File.open("fonts/roboto.ttf", [:binary, :read])

# Get table directory
{:ok, table_directory} = TTFonture.get_table_directory(file)

# Read specific tables
{:ok, head_table} = TTFonture.Tables.Head.read(file)
{:ok, name_table} = TTFonture.Tables.Name.read(file)

# Clean up
File.close(file)
```

## Performance Considerations

### Caching Strategy

TTFonture uses intelligent caching to optimize performance:

```elixir
# First read parses and caches the table
{:ok, head} = TTFonture.Tables.Head.read()  # Reads from file

# Subsequent reads use cached data
{:ok, head} = TTFonture.Tables.Head.read()  # Returns cached version

# Check what's cached
cached_tables = TTFonture.FileRegister.cache_stats()

# Clear cache if needed
TTFonture.FileRegister.clear_cache()
```

### Memory Management

- Tables are loaded lazily - only when requested
- FileRegister automatically manages file handles
- Use `close_all/0` or `close/1` to free resources

```elixir
# Clean shutdown
TTFonture.FileRegister.close_all()

# Or close specific files
TTFonture.FileRegister.close("path/to/font.ttf")
```

## Error Handling

TTFonture follows Elixir conventions for error handling:

```elixir
case TTFonture.Tables.Head.read() do
  {:ok, head_table} ->
    # Process successful result
    IO.puts("Font units per em: #{head_table.units_per_em}")

  {:error, reason} ->
    # Handle error
    IO.puts("Failed to read head table: #{reason}")
end
```

Common error scenarios:
- File not found or inaccessible
- Corrupted font data
- Unsupported font formats
- No file registered in FileRegister (This will raise if you are trying to use the automatic read functions)

## Supervision Tree Integration

Add TTFonture to your application's supervision tree:

```elixir
# In your application.ex
def start(_type, _args) do
  children = [
    # ... your other workers
    TTFonture.FileRegister
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

Or start it manually:

```elixir
{:ok, _pid} = TTFonture.FileRegister.start_link()
```

## Data Types and Structures

TTFonture provides structured access to font data through well-defined types:

```elixir
# Head table information
%TTFonture.Tables.Head{
  version: 1.0,
  units_per_em: 2048,
  x_min: -123,
  y_min: -456,
  x_max: 2000,
  y_max: 1800,
  # ... more fields
}

# Simple glyph with outline data
%TTFonture.Glyphs.SimpleGlyph{
  number_of_contours: 2,
  x_min: 100,
  y_min: 0,
  x_max: 900,
  y_max: 700,
  contour_end_points: [15, 31],
  coords_x: [100, 200, 300, ...],
  coords_y: [0, 100, 200, ...],
  flags: [1, 1, 0, 1, ...]
}
```

## Limitations

Current limitations of TTFonture:

- **TrueType Only**: Does not support OpenType CFF fonts
- **Read Only**: No font modification or creation capabilities
- **Basic Hinting**: Glyph instructions are read but not interpreted
- **No Rasterization**: Outline data only, no bitmap generation

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup

```bash
# Clone the repository
git clone https://github.com/TimoWess/TTFonture.git
cd TTFonture

# Install dependencies
mix deps.get

# Generate documentation
mix docs
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [TrueType Font Specification](https://docs.microsoft.com/en-us/typography/opentype/spec/) by Microsoft
- [Apple TrueType Reference Manual](https://developer.apple.com/fonts/TrueType-Reference-Manual/)
- The Elixir community for excellent documentation and tools

---

**TTFonture** - Bringing the power of font parsing to the Elixir ecosystem.
