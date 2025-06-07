defmodule TTFonture.Tables.Post do
  @moduledoc """
  Handles the PostScript Table (post) in TrueType font files.

  The Post module reads and interprets the 'post' table, which contains PostScript-specific
  information about the font. This table includes information about italic angle,
  underline position and thickness, and memory usage requirements.

  The primary functions of this module are:

  1. Reading the PostScript data from the 'post' table
  2. Providing structured access to the PostScript-specific font metrics

  ## Table Format

  The 'post' table consists of the following fields:
  - Format: A fixed-point number indicating the format version of the table
  - Italic Angle: A fixed-point number specifying the italic angle in degrees
  - Underline Position: A signed value indicating the suggested position of underlines
  - Underline Thickness: A signed value indicating the suggested thickness of underlines
  - IsFixedPitch: A flag indicating whether the font is monospaced
  - MinMemType42: Minimum memory usage when a TrueType font is downloaded as Type 42
  - MaxMemType42: Maximum memory usage when a TrueType font is downloaded as Type 42
  - MinMemType1: Minimum memory usage when a TrueType font is downloaded as Type 1
  - MaxMemType1: Maximum memory usage when a TrueType font is downloaded as Type 1

  ## Usage Example

  ```elixir
  # First register a font file
  TTFonture.FileRegister.register("fonts/opensans.ttf")

  # Get post table information
  {:ok, post_info} = TTFonture.Tables.Post.read()

  # Access the italic angle
  italic_angle = post_info.italic_angle

  # Work with a specific file handle
  {:ok, file} = File.open("fonts/roboto.ttf", [:binary, :read])
  {:ok, post_info} = TTFonture.Tables.Post.read(file)
  ```
  """

  alias TTFonture.BinaryReader
  alias TTFonture.FileRegister

  @type t() :: %__MODULE__{
          format: float(),
          italic_angle: float(),
          underline_position: integer(),
          underline_thickness: integer(),
          is_fixed_pitch: non_neg_integer(),
          min_mem_type_42: non_neg_integer(),
          max_mem_type_42: non_neg_integer(),
          min_mem_type_1: non_neg_integer(),
          max_mem_type_1: non_neg_integer()
        }
  defstruct format: 0.0,
            italic_angle: 0.0,
            underline_position: 0,
            underline_thickness: 0,
            is_fixed_pitch: 0,
            min_mem_type_42: 0,
            max_mem_type_42: 0,
            min_mem_type_1: 0,
            max_mem_type_1: 0

  @doc """
  Reads the 'post' table from the current font file in FileRegister.

  Uses the current file set in FileRegister to read the PostScript information.

  ## Returns

  A struct containing all the PostScript table information.

  ## Raises

  Raises an error if no file is currently registered in FileRegister.

  ## Example

  ```elixir
  # First register a font file
  TTFonture.FileRegister.register("fonts/opensans.ttf")

  # Then read the post table
  {:ok, post_info} = TTFonture.Tables.Post.read()
  ```
  """
  @spec read() :: {:ok, __MODULE__.t()}
  def read do
    case FileRegister.get_cached("post") do
      {:ok, post_table} ->
        {:ok, post_table}

      {:error, _} ->
        file_info = FileRegister.current()
        {:ok, post_table} = read(file_info)
        FileRegister.cache_table("post", post_table)
        {:ok, post_table}
    end
  end

  @doc """
  Reads the 'post' table from a specified font file.

  This overload accepts a direct file handle and builds the necessary table directory
  information before proceeding with reading the PostScript information.

  ## Parameters

  - `file`: The file handle (pid) to read from

  ## Returns

  A struct containing all the PostScript table information.
  """
  @spec read(pid() | FileRegister.file_info()) :: {:ok, __MODULE__.t()}
  def read(file) when is_pid(file) do
    {:ok, table_directory} = TTFonture.get_table_directory(file)
    file_info = %{pid: file, table_directory: table_directory, tables: %{}}
    read(file_info)
  end

  def read(%{pid: file, table_directory: table_directory}) do
    post_offset = Keyword.get(table_directory["post"], :offset)
    :file.position(file, post_offset)

    {:ok, format} = BinaryReader.read_fixed(file)
    {:ok, italic_angle} = BinaryReader.read_fixed(file)
    {:ok, underline_position} = BinaryReader.read_fword(file)
    {:ok, underline_thickness} = BinaryReader.read_fword(file)
    {:ok, is_fixed_pitch} = BinaryReader.read_uint32(file)
    {:ok, min_mem_type_42} = BinaryReader.read_uint32(file)
    {:ok, max_mem_type_42} = BinaryReader.read_uint32(file)
    {:ok, min_mem_type_1} = BinaryReader.read_uint32(file)
    {:ok, max_mem_type_1} = BinaryReader.read_uint32(file)

    {:ok,
     %__MODULE__{
       format: format,
       italic_angle: italic_angle,
       underline_position: underline_position,
       underline_thickness: underline_thickness,
       is_fixed_pitch: is_fixed_pitch,
       min_mem_type_42: min_mem_type_42,
       max_mem_type_42: max_mem_type_42,
       min_mem_type_1: min_mem_type_1,
       max_mem_type_1: max_mem_type_1
     }}
  end
end
