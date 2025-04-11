defmodule TTFonture.Tables.Cmap do
  alias TTFonture.Tables.Cmap.MappingSubtable
  alias TTFonture.Tables.Cmap.EncodingSubtable
  alias TTFonture.BinaryReader
  alias TTFonture.FileRegister

  @type t() :: %__MODULE__{
          version: 0,
          number_of_subtables: non_neg_integer(),
          encoding_subtables: [term()],
          mapping_subtables: [term()]
        }
  defstruct version: 0, number_of_subtables: 0, encoding_subtables: [], mapping_subtables: []

  defp collect_encoding_subtables(_, nus) when nus <= 0, do: []

  defp collect_encoding_subtables(file, number_of_subtables) do
    Enum.map(1..number_of_subtables, fn _ -> EncodingSubtable.read(file) end)
  end

  def collect_mapping_subtables(file, cmap_offset, encoding_subtables) do
    Enum.map(encoding_subtables, fn encoding_subtable ->
      MappingSubtable.read(file, cmap_offset, encoding_subtable)
    end)
  end

  @spec read() :: __MODULE__.t()
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
    cmap_offset = Keyword.get(table_directory["cmap"], :offset)
    :file.position(file, cmap_offset)

    {:ok, version} = BinaryReader.read_uint16(file)
    {:ok, number_of_subtables} = BinaryReader.read_uint16(file)

    encoding_subtables = collect_encoding_subtables(file, number_of_subtables)
    mapping_subtables = collect_mapping_subtables(file, cmap_offset, encoding_subtables)

    {:ok,
     %__MODULE__{
       version: version,
       number_of_subtables: number_of_subtables,
       encoding_subtables: encoding_subtables,
       mapping_subtables: mapping_subtables
     }}
  end
end
