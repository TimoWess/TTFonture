defmodule TTFonture do
  @moduledoc """
  Core module for TTFonture, an Elixir library for working with TrueType fonts.

  TTFonture provides functionality for parsing and processing TrueType font files (.ttf),
  giving access to font metrics, glyph outlines, and other font data. This module serves as
  the main entry point for interacting with font files.

  TrueType fonts are organized as a collection of tables, each containing specific font data.
  The table directory is the starting point for accessing these tables, and this module
  provides functionality to read and process this directory structure.

  ## Font Structure Overview

  A TrueType font file contains:
  1. A table directory listing all tables in the font
  2. Various tables containing different aspects of font data:
     - 'head' - Font header information
     - 'glyf' - Glyph outline data
     - 'cmap' - Character to glyph mapping
     - 'hhea', 'hmtx' - Horizontal metrics
     - And many others

  ## Usage with FileRegister

  While you can work with file handles directly, TTFonture provides a FileRegister module
  for more convenient file management:

  ```elixir
  # Start the FileRegister (typically in your supervision tree)
  TTFonture.FileRegister.start_link()

  # Register a font file
  file_info = TTFonture.FileRegister.register("path/to/font.ttf")

  # Now you can access the current file and its table directory
  file_pid = TTFonture.FileRegister.current_pid()
  table_directory = TTFonture.FileRegister.current_table_directory()

  # When finished with all files
  TTFonture.FileRegister.close_all()
  ```

  ## Direct Usage

  If you prefer to manage file handles manually:

  ```elixir
  # Open a TTF file
  {:ok, file} = :file.open("path/to/font.ttf", [:read, :binary])

  # Get the table directory
  table_directory = TTFonture.get_table_directory(file)

  # Access specific tables using the directory
  # ...

  # Close the file when done
  :file.close(file)
  ```

  ## Working with Glyphs

  TTFonture supports both simple and compound glyphs:

  - Simple glyphs contain direct outline data with points and contours
  - Compound glyphs reference other glyphs with transformations

  Both types can be read and processed using their respective modules:
  `TTFonture.Glyphs.SimpleGlyph` and `TTFonture.Glyphs.CompoundGlyph`.
  """

  alias TTFonture.Glyphs.CompoundGlyph
  alias TTFonture.Glyphs.SimpleGlyph
  alias TTFonture.BinaryReader

  @type glyph() :: SimpleGlyph.t() | CompoundGlyph.t()
  @type table_directory() :: %{
          binary() => [
            checksum: non_neg_integer(),
            offset: non_neg_integer(),
            length: non_neg_integer()
          ]
        }

  @doc """
  Reads the table directory from a TrueType font file.

  The table directory is the main index into a TrueType font file, containing entries
  for each table in the font. Each entry includes:

  - A 4-byte tag identifying the table (e.g., 'head', 'glyf', 'cmap')
  - A checksum for verifying table integrity
  - The byte offset where the table begins in the file
  - The length of the table in bytes

  This function parses the table directory and returns a map where the keys are the table tags
  and the values are keyword lists containing the table metadata.

  > **Note:** In most cases, you should use `TTFonture.FileRegister` which caches the table
  > directory to avoid repeated reads.

  ## Parameters
    - `file`: A file handle (pid) for an open TTF file

  ## Returns
    - On success: A map of table tags to table metadata (checksum, offset, and length)
    - On error: `{:error, reason}` where reason describes what went wrong

  ## Example

  ```elixir
  # Direct usage:
  {:ok, file} = :file.open("font.ttf", [:read, :binary])
  table_directory = TTFonture.get_table_directory(file)

  # Access the offset of the 'glyf' table
  glyf_table = table_directory["glyf"]
  glyf_offset = Keyword.get(glyf_table, :offset)

  # With FileRegister (preferred):
  TTFonture.FileRegister.register("font.ttf")
  table_directory = TTFonture.FileRegister.current_table_directory()
  glyf_table = table_directory["glyf"]
  glyf_offset = Keyword.get(glyf_table, :offset)
  ```
  """
  @spec get_table_directory(pid()) :: table_directory() | {:error, binary()}
  def get_table_directory(file) when is_pid(file) do
    # Skip scaler type
    :file.position(file, {:bof, 4})

    {:ok, num_tables} = BinaryReader.read_uint16(file)

    # Skip searchRange, entrySelector and rangeShift
    BinaryReader.skip_bytes(file, 6)

    Enum.reduce(1..num_tables, %{}, fn _, acc ->
      with {:ok, tag} <- BinaryReader.read_tag(file),
           {:ok, checksum} <- BinaryReader.read_uint32(file),
           {:ok, offset} <- BinaryReader.read_uint32(file),
           {:ok, length} <- BinaryReader.read_uint32(file) do
        Map.put(acc, tag, checksum: checksum, offset: offset, length: length)
      else
        {:error, reason} -> {:error, reason}
      end
    end)
  end
end
