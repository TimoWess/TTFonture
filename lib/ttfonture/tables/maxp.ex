defmodule TTFonture.Tables.Maxp do
  alias TTFonture.FileRegister
  alias TTFonture.BinaryReader

  defstruct [
    # Fixed 32-bit value: 0x00010000 for version 1.0
    version: 0x00010000,
    # Number of glyphs in the font
    num_glyphs: 0,
    # Maximum points in a non-compound glyph
    max_points: 0,
    # Maximum contours in a non-compound glyph
    max_contours: 0,
    # Maximum points in a compound glyph
    max_component_points: 0,
    # Maximum contours in a compound glyph
    max_component_contours: 0,
    # Set to 2
    max_zones: 2,
    # Points used in Twilight Zone (Z0)
    max_twilight_points: 0,
    # Number of Storage Area locations
    max_storage: 0,
    # Number of FDEFs (Function Definitions)
    max_function_defs: 0,
    # Number of IDEFs (Instruction Definitions)
    max_instruction_defs: 0,
    # Maximum stack depth
    max_stack_elements: 0,
    # Byte count for glyph instructions
    max_size_of_instructions: 0,
    # Number of glyphs referenced at top level
    max_component_elements: 0,
    # Levels of recursion, set to 0 if font has only simple glyphs
    max_component_depth: 0
  ]

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

  @spec read() :: __MODULE__.t()
  def read do
    file_info = FileRegister.current()
    read(file_info)
  end

  @spec read(file :: pid()) :: __MODULE__.t()
  def read(file) when is_pid(file) do
    table_directory = TTFonture.get_table_directory(file)
    read(%{pid: file, table_directory: table_directory})
  end

  @spec read(file_info :: FileRegister.file_info()) :: __MODULE__.t()
  def read(%{pid: file, table_directory: table_directory}) do
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
      }
    end
  end
end
