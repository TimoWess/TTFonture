defmodule TTFonture.Tables.Name do
  @moduledoc """
  Struct representing the 'name' table in a TrueType/OpenType Font.

  The 'name' table contains human-readable naming information for the font,
  including family names, style names, copyright notices, and other textual metadata.
  This table allows for multiple languages and platform-specific encodings of the same information.
  """

  alias TTFonture.BinaryReader
  alias TTFonture.FileRegister
  alias TTFonture.Tables.Name.NameRecord

  @typedoc """
  Type representing the 'name' table structure.

  Fields:
  * `:format` - Format selector (0 = standard format, 1 = extended format with language tags)
  * `:count` - Number of name records in the table
  * `:string_offset` - Offset to the beginning of the string storage area (from start of the name table)
  * `:name_records` - List of name records containing metadata about each stored string
  """
  @type t :: %__MODULE__{
          format: non_neg_integer(),
          count: non_neg_integer(),
          string_offset: non_neg_integer(),
          name_records: [NameRecord.t()]
        }

  defstruct format: 0, count: 0, string_offset: 0, name_records: []

  @doc """
  Reads the 'name' table from the currently registered font file.

  ## Returns

  Parsed name table structure with all name records and strings.
  """
  @spec read() :: {:ok, __MODULE__.t()} | {:error, String.t()}
  def read do
    case FileRegister.get_cached("name") do
      {:ok, name_table} ->
        {:ok, name_table}

      {:error, _} ->
        file_info = FileRegister.current()
        {:ok, name_table} = read(file_info)
        FileRegister.cache_table("name", name_table)
        {:ok, name_table}
    end
  end

  @doc """
  Reads the 'name' table from the provided font file.

  ## Parameters

  * `file` - Open file handle to the font file

  ## Returns

  * `{:ok, %TTFonture.Tables.Name{}}` - Successfully parsed name table
  * `{:error, reason}` - Error reading the table
  """
  @spec read(pid() | FileRegister.file_info()) :: {:ok, __MODULE__.t()} | {:error, String.t()}
  def read(file) when is_pid(file) do
    {:ok, table_directory} = TTFonture.get_table_directory(file)
    file_info = %{pid: file, table_directory: table_directory, tables: %{}}
    read(file_info)
  end

  def read(%{pid: file, table_directory: table_directory}) do
    name_offset = Keyword.get(table_directory["name"], :offset)
    :file.position(file, name_offset)

    with {:ok, format} <- BinaryReader.read_uint16(file),
         {:ok, count} <- BinaryReader.read_uint16(file),
         {:ok, string_offset} <- BinaryReader.read_uint16(file),
         {:ok, name_records} <- read_name_records(file, count),
         {:ok, final_records} <-
           read_names_of_records(file, name_records, name_offset + string_offset) do
      {:ok,
       %__MODULE__{
         format: format,
         count: count,
         string_offset: string_offset,
         name_records: final_records
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  @spec read_name(name_record :: NameRecord.t(), file :: pid()) ::
          {:ok, String.t()} | {:error, String.t()} | {:incomplete, String.t()}
  defp read_name(record, file) do
    {:ok, data} = :file.read(file, record.length)

    data_string =
      case record.platform_id do
        # Unicode
        0 -> :unicode.characters_to_binary(data, {:utf16, :big}, :utf8)
        # Macintosh
        1 -> data
        # Deprecated
        2 -> :unicode.characters_to_binary(data, {:utf16, :big}, :utf8)
        # Microsoft
        3 -> :unicode.characters_to_binary(data, {:utf16, :big}, :utf8)
      end

    case data_string do
      {:error, partial_data, rest_data} ->
        {:error,
         "Failed to read name string of record: #{record}\nPartial data read: #{partial_data}\nRest data: #{rest_data}"}

      {:incomplete, partial_data, rest_data} ->
        {:incomplete,
         "Binary data incomplete for record: #{record}\nPartial data read: #{partial_data}\nRest data: #{rest_data}"}

      name_string ->
        {:ok, name_string}
    end
  end

  @doc false
  @spec read_name_records(file :: pid(), count :: non_neg_integer()) ::
          {:ok, [NameRecord.t()]} | {:error, String.t()}
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

  @doc false
  defp apply_name_to_record(name, record) do
    %NameRecord{record | name: name}
  end

  @doc false
  @spec read_names_of_records(
          file :: pid(),
          name_records :: [NameRecord.t()],
          base_offset :: non_neg_integer()
        ) :: {:ok, [String.t()]} | {:error, String.t()}
  defp read_names_of_records(file, name_records, base_offset) do
    try do
      res =
        Enum.map(name_records, fn record ->
          :file.position(file, {:bof, base_offset + record.offset})
          {:ok, name} = read_name(record, file)
          apply_name_to_record(name, record)
        end)

      {:ok, res}
    rescue
      e -> {:error, "Failed to read name: #{Exception.format(:error, e, __STACKTRACE__)}"}
    end
  end
end
