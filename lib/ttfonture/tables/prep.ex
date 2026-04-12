defmodule TTFonture.Tables.Prep do
  alias TTFonture.BinaryReader
  alias TTFonture.FileRegister
  alias TTFonture.Tables.Common

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

  @spec read() :: {:ok, __MODULE__.t()}
  def read do
    Common.read_cached_table("prep", &read_prep_table/1)
  end

  @spec read(pid() | FileRegister.file_info()) :: {:ok, __MODULE__.t()}
  def read(file) when is_pid(file) do
    Common.read_table_from_file(file, &read_prep_table/1)
  end

  def read(%{pid: _file, table_directory: _table_directory} = file_info),
    do: read_prep_table(file_info)

  def read_prep_table(%{pid: file, table_directory: table_directory}) do
    prep_offset = Keyword.get(table_directory["prep"], :offset)
    :file.position(file, prep_offset)

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
