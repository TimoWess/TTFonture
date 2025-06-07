defmodule TTFonture.Tables.Maxp do
  @moduledoc """
  Struct representing the 'maxp' table in a TrueType Font.

  The 'maxp' table establishes the memory requirements for a font.
  """

  alias TTFonture.FileRegister
  alias TTFonture.BinaryReader
  alias TTFonture.Tables.Common

  @typedoc """
  Type representing the 'maxp' table structure.

  Fields:
  * `:version` - Fixed 32-bit value: 0x00010000 for version 1.0
  * `:num_glyphs` - Number of glyphs in the font
  * `:max_points` - Maximum points in a non-compound glyph
  * `:max_contours` - Maximum contours in a non-compound glyph
  * `:max_component_points` - Maximum points in a compound glyph
  * `:max_component_contours` - Maximum contours in a compound glyph
  * `:max_zones` - Set to 2
  * `:max_twilight_points` - Points used in Twilight Zone (Z0)
  * `:max_storage` - Number of Storage Area locations
  * `:max_function_defs` - Number of FDEFs (Function Definitions)
  * `:max_instruction_defs` - Number of IDEFs (Instruction Definitions)
  * `:max_stack_elements` - Maximum stack depth
  * `:max_size_of_instructions` - Byte count for glyph instructions
  * `:max_component_elements` - Number of glyphs referenced at top level
  """
  @type t :: %__MODULE__{
          version: float(),
          num_glyphs: non_neg_integer(),
          max_points: non_neg_integer(),
          max_contours: non_neg_integer(),
          max_component_points: non_neg_integer(),
          max_component_contours: non_neg_integer(),
          max_zones: non_neg_integer(),
          max_twilight_points: non_neg_integer(),
          max_storage: non_neg_integer(),
          max_function_defs: non_neg_integer(),
          max_instruction_defs: non_neg_integer(),
          max_stack_elements: non_neg_integer(),
          max_size_of_instructions: non_neg_integer(),
          max_component_elements: non_neg_integer(),
          max_component_depth: non_neg_integer()
        }

  defstruct version: 0x00010000,
            num_glyphs: 0,
            max_points: 0,
            max_contours: 0,
            max_component_points: 0,
            max_component_contours: 0,
            max_zones: 2,
            max_twilight_points: 0,
            max_storage: 0,
            max_function_defs: 0,
            max_instruction_defs: 0,
            max_stack_elements: 0,
            max_size_of_instructions: 0,
            max_component_elements: 0,
            max_component_depth: 0

  @spec read() :: {:ok, __MODULE__.t()}
  def read do
    Common.read_cached_table("maxp", &read_maxp_table/1)
  end

  @spec read(pid() | FileRegister.file_info()) :: {:ok, __MODULE__.t()}
  def read(file) when is_pid(file) do
    Common.read_table_from_file(file, &read_maxp_table/1)
  end

  def read(%{pid: _file, table_directory: _table_directory} = file_info),
    do: read_maxp_table(file_info)

  def read_maxp_table(%{pid: file, table_directory: table_directory}) do
    maxp_offset = Keyword.get(table_directory["maxp"], :offset)
    :file.position(file, maxp_offset)

    with {:ok, version} <- BinaryReader.read_fixed(file),
         {:ok, num_glyphs} <- BinaryReader.read_uint16(file),
         {:ok, max_points} <- BinaryReader.read_uint16(file),
         {:ok, max_contours} <- BinaryReader.read_uint16(file),
         {:ok, max_component_points} <- BinaryReader.read_uint16(file),
         {:ok, max_component_contours} <- BinaryReader.read_uint16(file),
         {:ok, max_zones} <- BinaryReader.read_uint16(file),
         {:ok, max_twilight_points} <- BinaryReader.read_uint16(file),
         {:ok, max_storage} <- BinaryReader.read_uint16(file),
         {:ok, max_function_defs} <- BinaryReader.read_uint16(file),
         {:ok, max_instruction_defs} <- BinaryReader.read_uint16(file),
         {:ok, max_stack_elements} <- BinaryReader.read_uint16(file),
         {:ok, max_size_of_instructions} <- BinaryReader.read_uint16(file),
         {:ok, max_component_elements} <- BinaryReader.read_uint16(file),
         {:ok, max_component_depth} <- BinaryReader.read_uint16(file) do
      {:ok,
       %__MODULE__{
         version: version,
         num_glyphs: num_glyphs,
         max_points: max_points,
         max_contours: max_contours,
         max_component_points: max_component_points,
         max_component_contours: max_component_contours,
         max_zones: max_zones,
         max_twilight_points: max_twilight_points,
         max_storage: max_storage,
         max_function_defs: max_function_defs,
         max_instruction_defs: max_instruction_defs,
         max_stack_elements: max_stack_elements,
         max_size_of_instructions: max_size_of_instructions,
         max_component_elements: max_component_elements,
         max_component_depth: max_component_depth
       }}
    end
  end
end
