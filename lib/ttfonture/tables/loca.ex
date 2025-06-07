defmodule TTFonture.Tables.Loca do
  @moduledoc """
  Handles the Location Table (loca) in TrueType font files.

  The Loca module reads and interprets the 'loca' table, which contains offsets to
  each glyph in the 'glyf' table. This module supports both short (16-bit) and long
  (32-bit) format offset entries, choosing the appropriate format based on the
  'indexToLocFormat' field in the font's header.

  The primary functions of this module are:

  1. Reading the raw location offsets from the 'loca' table
  2. Converting these relative offsets to absolute file positions

  ## Table Format

  The 'loca' table consists of an array of offsets, where:
  - Format 0: Each offset is a 16-bit value that must be multiplied by 2
  - Format 1: Each offset is a 32-bit value used directly

  The format is determined by the 'indexToLocFormat' field in the 'head' table.

  ## Usage Example

  ```elixir
  # First register a font file
  TTFonture.FileRegister.register("fonts/opensans.ttf")

  # Get raw location offsets
  loca_offsets = TTFonture.Tables.Loca.read()

  # Get absolute offsets (including glyf table starting position)
  absolute_offsets = TTFonture.Tables.Loca.get_absolute_offsets()

  # Work with a specific file handle
  {:ok, file} = File.open("fonts/roboto.ttf", [:binary, :read])
  absolute_offsets = TTFonture.Tables.Loca.get_absolute_offsets(file)
  ```
  """

  alias TTFonture.FileRegister
  alias TTFonture.BinaryReader

  @type t() :: [offset()]
  @type offset() :: non_neg_integer()

  @doc """
  Reads the 'loca' table from the current font file in FileRegister.

  Uses the current file set in FileRegister to read the location offsets.

  ## Returns

  A list of relative offsets from the start of the 'glyf' table to each glyph.

  ## Raises

  Raises an error if no file is currently registered in FileRegister.

  ## Example

  ```elixir
  # First register a font file
  TTFonture.FileRegister.register("fonts/opensans.ttf")

  # Then read the loca table
  loca_offsets = TTFonture.Tables.Loca.read()
  ```
  """
  @spec read() :: {:ok, __MODULE__.t()}
  def read do
    case FileRegister.get_cached("loca") do
      {:ok, loca_table} ->
        {:ok, loca_table}

      {:error, _} ->
        file_info = FileRegister.current()
        {:ok, loca_table} = read(file_info)
        FileRegister.cache_table("loca", loca_table)
        {:ok, loca_table}
    end
  end

  @doc """
  Reads the 'loca' table from a specified font file.

  This overload accepts a direct file handle and builds the necessary table directory
  information before proceeding with reading the location offsets.

  ## Parameters

  - `file`: The file handle (pid) to read from

  ## Returns

  A list of relative offsets from the start of the 'glyf' table to each glyph.
  """
  @spec read(pid() | FileRegister.file_info()) :: {:ok, __MODULE__.t()}
  def read(file) when is_pid(file) do
    {:ok, table_directory} = TTFonture.get_table_directory(file)
    file_info = %{pid: file, table_directory: table_directory, tables: %{}}
    read(file_info)
  end

  def read(%{pid: file, table_directory: table_directory}) do
    # Skip unused: version
    maxp_offset = Keyword.get(table_directory["maxp"], :offset) + 4

    {:ok, number_of_glyphs} =
      BinaryReader.read_at_offset(file, maxp_offset, &BinaryReader.read_uint16/1)

    head_offset = Keyword.get(table_directory["head"], :offset)
    :file.position(file, head_offset)

    # Skip unused: version, fontRevision, checkSumAdjustment, magicNumber?, flags, unitsPerEm, created, modified, xMin, yMin, xMax, yMax, macStyle, lowestRecPPEM, fontDirectionHint
    BinaryReader.skip_bytes(file, 50)

    {:ok, index_to_loc_format} = BinaryReader.read_int16(file)
    is_two_byte_entry = index_to_loc_format == 0
    offset_length = if is_two_byte_entry, do: 2, else: 4

    location_table_start = Keyword.get(table_directory["loca"], :offset)

    all_glyph_locations =
      Enum.map(0..number_of_glyphs, fn glyph_index ->
        :file.position(file, location_table_start + glyph_index * offset_length)

        if is_two_byte_entry do
          {:ok, gdo} = BinaryReader.read_uint16(file)
          gdo * 2
        else
          {:ok, gdo} = BinaryReader.read_uint32(file)
          gdo
        end
      end)

    {:ok, all_glyph_locations}
  end

  @doc """
  Gets absolute file offsets for all glyphs from the current font file.

  Combines the relative offsets from the 'loca' table with the starting position
  of the 'glyf' table to produce absolute file offsets for each glyph.

  ## Returns

  A list of absolute file offsets pointing to each glyph.

  ## Raises

  Raises an error if no file is currently registered in FileRegister.

  ## Example

  ```elixir
  # First register a font file
  TTFonture.FileRegister.register("fonts/opensans.ttf")

  # Get absolute offsets for all glyphs
  absolute_offsets = TTFonture.Tables.Loca.get_absolute_offsets()
  ```
  """
  @spec get_absolute_offsets() :: {:ok, __MODULE__.t()}
  def get_absolute_offsets do
    file_info = FileRegister.current()
    get_absolute_offsets(file_info)
  end

  @doc """
  Gets absolute file offsets for all glyphs from a specified font file.

  This overload accepts a direct file handle and builds the necessary table directory
  information before calculating absolute offsets.

  ## Parameters

  - `file`: The file handle (pid) to read from

  ## Returns

  A list of absolute file offsets pointing to each glyph.
  """
  @spec get_absolute_offsets(file :: pid()) :: {:ok, __MODULE__.t()}
  def get_absolute_offsets(file) when is_pid(file) do
    table_directory = TTFonture.get_table_directory(file)
    file_info = %{pid: file, table_directory: table_directory}
    get_absolute_offsets(file_info)
  end

  @spec get_absolute_offsets(file_info :: FileRegister.file_info()) :: {:ok, __MODULE__.t()}
  def get_absolute_offsets(file_info = %{table_directory: table_directory}) do
    glyph_table_start = Keyword.get(table_directory["glyf"], :offset)
    {:ok, loca_table_entries} = read(file_info)

    {:ok,
     Enum.map(loca_table_entries, fn relative_offset -> relative_offset + glyph_table_start end)}
  end
end
