defmodule TTFonture.Tables.Glyf do
  @moduledoc """
  Reads and processes glyph data from TrueType font files.

  The Glyf module provides functionality to read individual glyphs or the entire 
  glyph table from a TTF file. It works with both simple and compound glyphs,
  delegating to the appropriate handling module based on the glyph type.

  This module integrates with the FileRegister system to access font files and 
  requires the Loca table to determine glyph locations within the file.

  ## Features

  * Read individual glyphs at specific offsets
  * Read all glyphs from a font file
  * Automatic detection and handling of simple vs. compound glyphs
  * Seamless integration with the FileRegister system

  ## Usage Example

  ```elixir
  # First register a font file
  TTFonture.FileRegister.register("fonts/opensans.ttf")

  # Read all glyphs in the font
  glyphs = TTFonture.Tables.Glyf.read()

  # Or read from a specific file handle
  {:ok, file} = File.open("fonts/roboto.ttf", [:binary, :read])
  glyphs = TTFonture.Tables.Glyf.read(file)

  # Read a single glyph at a specific offset
  glyph = TTFonture.Tables.Glyf.read_glyph(file, offset)
  ```
  """

  alias TTFonture.Tables.Loca
  alias TTFonture.FileRegister
  alias TTFonture.BinaryReader
  alias TTFonture.Glyphs.CompoundGlyph
  alias TTFonture.Glyphs.SimpleGlyph

  @type glyph() :: SimpleGlyph.t() | CompoundGlyph.t()

  @doc """
  Reads a single glyph from a file at the specified offset.

  This function reads the number of contours to determine whether the glyph is simple
  or compound, then delegates to the appropriate module for full parsing.

  ## Parameters

  - `file`: The file handle (pid) to read from
  - `offset`: The byte offset in the file where the glyph data starts

  ## Returns

  A glyph struct (either SimpleGlyph or CompoundGlyph)

  ## Example

  ```elixir
  # Get a specific glyph at a known offset
  glyph = TTFonture.Tables.Glyf.read_glyph(file_pid, 2540)
  ```
  """
  @spec read_glyph(file :: pid(), offset :: non_neg_integer()) :: glyph()
  def read_glyph(file, offset) do
    {:ok, number_of_contours} =
      BinaryReader.read_at_offset(file, offset, &BinaryReader.read_int16/1)

    if number_of_contours >= 0,
      do: SimpleGlyph.read(file, offset),
      else: CompoundGlyph.read(file, offset)
  end

  @doc """
  Reads all glyphs from the current font file in the FileRegister.

  Uses the current file set in FileRegister to read all glyphs in the font.

  ## Returns

  A list of glyph structs (mix of SimpleGlyph and CompoundGlyph)

  ## Raises

  Raises an error if no file is currently registered in FileRegister.

  ## Example

  ```elixir
  # First register a font file
  TTFonture.FileRegister.register("fonts/opensans.ttf")

  # Then read all glyphs
  glyphs = TTFonture.Tables.Glyf.read()
  ```
  """
  def read do
    file_info = FileRegister.current()
    read(file_info)
  end

  @doc """
  Reads all glyphs from a specified font file.

  This overload accepts a direct file handle and builds the necessary table directory
  information before proceeding with glyph reading.

  ## Parameters

  - `file`: The file handle (pid) to read from

  ## Returns

  A list of glyph structs (mix of SimpleGlyph and CompoundGlyph)
  """
  @spec read(file :: pid()) :: [glyph()]
  def read(file) when is_pid(file) do
    table_directory = TTFonture.get_table_directory(file)
    file_info = %{pid: file, table_directory: table_directory}
    read(file_info)
  end

  @spec read(file_info :: FileRegister.file_info()) :: [glyph()]
  def read(file_info) do
    # Last entry only needed to calculate length of the glyph
    all_glyph_locations =
      Loca.get_absolute_offsets(file_info) |> Enum.slice(0..-2//1)

    Enum.map(all_glyph_locations, fn offset ->
      read_glyph(file_info.pid, offset)
    end)
  end
end
