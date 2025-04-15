defmodule TTFonture.Tables.Post do
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

  def read do
    file_info = FileRegister.current()
    read(file_info)
  end

  def read(file) when is_pid(file) do
    table_directory = TTFonture.get_table_directory(file)
    file_info = %{pid: file, table_directory: table_directory}
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
