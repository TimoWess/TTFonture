defmodule TTFonture.Tables.Name do
  alias TTFonture.BinaryReader
  alias TTFonture.FileRegister
  alias TTFonture.Tables.Name.NameRecord

  @type t :: %__MODULE__{
          format: non_neg_integer(),
          count: non_neg_integer(),
          string_offset: non_neg_integer(),
          name_records: [NameRecord.t()],
          names: map()
        }

  defstruct format: 0, count: 0, string_offset: 0, name_records: [], names: %{}

  def read do
    file_info = FileRegister.current()
    read(file_info)
  end

  def read(file) when is_pid(file) do
    table_directory = TTFonture.get_table_directory(file)
    read(%{pid: file, table_directory: table_directory})
  end

  def read(%{pid: file, table_directory: table_directory}) do
    name_offset = Keyword.get(table_directory["name"], :offset)
    :file.position(file, name_offset)

    with {:ok, format} <- BinaryReader.read_uint16(file),
         {:ok, count} <- BinaryReader.read_uint16(file),
         {:ok, string_offset} <- BinaryReader.read_uint16(file),
         {:ok, name_records} <- read_name_records(file, count),
         {:ok, names} <- read_names_of_records(file, name_records) do
      {:ok,
       %__MODULE__{
         format: format,
         count: count,
         string_offset: string_offset,
         name_records: name_records,
         names: names
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp read_name(record, file) do
    {:ok, data} = :file.read(file, record.length)
    data_string = :unicode.characters_to_binary(data, :utf16, :utf8)
    IO.inspect(data_string)
    {:ok, data}
  end

  defp read_name_records(file, count) do
    try do
      res =
        Enum.map(1..count, fn _ ->
          {:ok, name_record} = NameRecord.read(file)
          name_record
        end)

      {:ok, res}
    rescue
      e -> {:error, "Failed to read name record: #{Exception.format(:error, e, __STACKTRACE__)}"}
    end
  end

  defp read_names_of_records(file, name_records) do
    try do
      res =
        Enum.map(name_records, fn record ->
          {:ok, name} = read_name(record, file)
          name
        end)

      {:ok, res}
    rescue
      e -> {:error, "Failed to read name: #{Exception.format(:error, e, __STACKTRACE__)}"}
    end
  end
end
