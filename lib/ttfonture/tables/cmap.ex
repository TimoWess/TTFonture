defmodule TTFonture.Tables.Cmap do
  alias TTFonture.Tables.Cmap.MappingSubtable
  alias TTFonture.Tables.Cmap.EncodingSubtable
  alias TTFonture.BinaryReader
  alias TTFonture.FileRegister
  alias TTFonture.Tables.Common

  @type t() :: %__MODULE__{
          version: 0,
          number_of_subtables: non_neg_integer(),
          encoding_subtables: [term()],
          mapping_subtables: [term()]
        }
  defstruct version: 0, number_of_subtables: 0, encoding_subtables: [], mapping_subtables: []

  @spec collect_encoding_subtables(file :: pid(), number_of_subtables :: non_neg_integer()) :: [
          EncodingSubtable.t()
        ]
  defp collect_encoding_subtables(_, number_of_subtables) when number_of_subtables <= 0, do: []

  defp collect_encoding_subtables(file, number_of_subtables) do
    Enum.map(1..number_of_subtables, fn _ ->
      {:ok, e_subtable} = EncodingSubtable.read(file)
      e_subtable
    end)
  end

  @spec collect_mapping_subtables(file :: pid(), cmap_offset :: non_neg_integer(), [
          EncodingSubtable.t()
        ]) :: [MappingSubtable.t()]
  defp collect_mapping_subtables(file, cmap_offset, encoding_subtables) do
    Enum.map(encoding_subtables, fn encoding_subtable ->
      {:ok, m_subtable} = MappingSubtable.read(file, cmap_offset, encoding_subtable)
      m_subtable
    end)
  end

  @spec read() :: {:ok, __MODULE__.t()}
  def read do
    Common.read_cached_table("cmap", &read_cmap_table/1)
  end

  @spec read(pid() | FileRegister.file_info()) :: {:ok, __MODULE__.t()}
  def read(file) when is_pid(file) do
    Common.read_table_from_file(file, &read_cmap_table/1)
  end

  def read(%{pid: _file, table_directory: _table_directory} = file_info),
    do: read_cmap_table(file_info)

  @spec read_cmap_table(file_info :: FileRegister.file_info()) :: {:ok, __MODULE__.t()}
  def read_cmap_table(%{pid: file, table_directory: table_directory}) do
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

  @doc """
  Looks up the glyph ID for a given character code.

  This function searches through the mapping subtables to find the glyph ID
  that corresponds to the given character code. It prioritizes Unicode subtables
  and handles both format 4, 6 and format 12 mappings.

  ## Parameters
  - character or char_code: A string of length 1 or Unicode character code

  ## Returns
  - {:ok, glyph_id} if the character is found
  - {:error, :not_found} if the character is not in the font
  """
  def char_to_glyph_id(<<char::utf8>>), do: char_to_glyph_id(char)

  def char_to_glyph_id(char_code) when is_number(char_code) do
    {:ok, cmap_table} = read()
    char_to_glyph_id(cmap_table, char_code)
  end

  @doc """
  Looks up the glyph ID for a given character code.

  This function searches through the mapping subtables to find the glyph ID
  that corresponds to the given character code. It prioritizes Unicode subtables
  and handles both format 4 and format 12 mappings.

  ## Parameters
  - cmap: The cmap table structure returned by read/1
  - char_code: The Unicode character code to look up

  ## Returns
  - {:ok, glyph_id} if the character is found
  - {:error, :not_found} if the character is not in the font
  """
  @spec char_to_glyph_id(t(), non_neg_integer() | binary()) ::
          {:ok, non_neg_integer()} | {:error, :not_found}
  def char_to_glyph_id(%__MODULE__{} = cmap_table, <<char::utf8>>),
    do: char_to_glyph_id(cmap_table, char)

  def char_to_glyph_id(%__MODULE__{mapping_subtables: mapping_subtables}, char_code)
      when is_number(char_code) do
    # Try to find the character in the best available subtable
    # Priority: Format 12 (Unicode full repertoire) > Format 4 (Unicode BMP)

    case find_in_format_12(mapping_subtables, char_code) do
      {:ok, glyph_id} ->
        {:ok, glyph_id}

      {:error, :not_found} ->
        case find_in_format_4(mapping_subtables, char_code) do
          {:ok, glyph_id} -> {:ok, glyph_id}
          {:error, :not_found} -> find_in_format_6(mapping_subtables, char_code)
        end
    end
  end

  @doc """
  Same as char_to_glyph_id/2 but returns the glyph ID directly or nil if not found.
  """
  @spec char_to_glyph_id_or_nil(t(), non_neg_integer()) :: non_neg_integer() | nil
  def char_to_glyph_id_or_nil(cmap, char_code) do
    case char_to_glyph_id(cmap, char_code) do
      {:ok, glyph_id} -> glyph_id
      {:error, :not_found} -> nil
    end
  end

  # Search in format 12 subtables (handles full Unicode range)
  defp find_in_format_12(mapping_subtables, char_code) do
    format_12_subtables = Enum.filter(mapping_subtables, &(&1.format == 12))

    Enum.reduce_while(format_12_subtables, {:error, :not_found}, fn subtable, acc ->
      case lookup_in_format_12_groups(subtable.data.groups, char_code) do
        {:ok, glyph_id} -> {:halt, {:ok, glyph_id}}
        {:error, :not_found} -> {:cont, acc}
      end
    end)
  end

  defp find_in_format_6(mapping_subtables, char_code) do
    format_6_subtables = Enum.filter(mapping_subtables, &(&1.format == 6))

    Enum.reduce_while(format_6_subtables, {:error, :not_found}, fn subtable, acc ->
      case lookup_in_format_6_segments(subtable.data, char_code) do
        {:ok, glyph_id} -> {:halt, {:ok, glyph_id}}
        {:error, :not_found} -> {:cont, acc}
      end
    end)
  end

  # Search in format 4 subtables (handles Unicode BMP - characters 0-65535)
  defp find_in_format_4(mapping_subtables, char_code) when char_code <= 65535 do
    format_4_subtables = Enum.filter(mapping_subtables, &(&1.format == 4))

    Enum.reduce_while(format_4_subtables, {:error, :not_found}, fn subtable, acc ->
      case lookup_in_format_4_segments(subtable.data, char_code) do
        {:ok, glyph_id} -> {:halt, {:ok, glyph_id}}
        {:error, :not_found} -> {:cont, acc}
      end
    end)
  end

  # Character codes above 65535 can't be in format 4 tables
  defp find_in_format_4(_mapping_subtables, _char_code), do: {:error, :not_found}

  # Look up character in format 12 groups (sequential ranges)
  defp lookup_in_format_12_groups(groups, char_code) do
    Enum.reduce_while(groups, {:error, :not_found}, fn group, acc ->
      if char_code >= group.start_char_code && char_code <= group.end_char_code do
        glyph_id = group.start_glyph_code + (char_code - group.start_char_code)
        {:halt, {:ok, glyph_id}}
      else
        {:cont, acc}
      end
    end)
  end

  defp lookup_in_format_6_segments(data, char_code) do
    %{
      first_code: first_code,
      entry_count: entry_count,
      glyph_id_array: glyph_id_array
    } = data

    if char_code >= first_code && char_code < first_code + entry_count do
      case Enum.fetch(glyph_id_array, char_code - first_code) do
        {:ok, glyph_id} -> {:ok, glyph_id}
        :error -> {:error, :not_found}
      end
    else
      {:error, :not_found}
    end
  end

  # Look up character in format 4 segments (more complex algorithm)
  defp lookup_in_format_4_segments(data, char_code) do
    %{
      start_codes: start_codes,
      end_codes: end_codes,
      id_deltas: id_deltas,
      id_range_offsets: id_range_offsets,
      glyph_id_array: glyph_id_array
    } = data

    with {:ok, seg_idx} <- find_segment_index(end_codes, char_code),
         {:ok, start_code} <- Enum.fetch(start_codes, seg_idx),
         true <- char_code >= start_code || {:error, :not_found},
         {:ok, id_delta} <- Enum.fetch(id_deltas, seg_idx),
         {:ok, range_offset} <- Enum.fetch(id_range_offsets, seg_idx),
         {:ok, gid} <-
           glyph_id_for(
             char_code,
             start_code,
             id_delta,
             range_offset,
             seg_idx,
             id_range_offsets,
             glyph_id_array
           ) do
      {:ok, gid}
    else
      _ -> {:error, :not_found}
    end
  end

  # Direct delta path (offset 0)
  defp glyph_id_for(char_code, _start, id_delta, 0, _seg_idx, _offsets, _array) do
    {:ok, rem(char_code + id_delta, 65_536)}
  end

  # Lookup path (offset != 0)
  defp glyph_id_for(
         char_code,
         start_code,
         id_delta,
         range_offset,
         seg_idx,
         id_range_offsets,
         glyph_id_array
       ) do
    array_index =
      div(range_offset, 2) + (char_code - start_code) -
        (length(id_range_offsets) - seg_idx)

    with true <- in_bounds?(array_index, glyph_id_array) || :ok_zero,
         {:ok, base} <- Enum.fetch(glyph_id_array, array_index) do
      if base == 0, do: {:ok, 0}, else: {:ok, rem(base + id_delta, 65_536)}
    else
      # If out of bounds, spec says treat as 0
      :ok_zero -> {:ok, 0}
      _ -> {:ok, 0}
    end
  end

  defp in_bounds?(i, list), do: i >= 0 and i < length(list)

  defp find_segment_index(end_codes, char_code) do
    case Enum.find_index(end_codes, fn end_code -> char_code <= end_code end) do
      nil -> {:error, :not_found}
      index -> {:ok, index}
    end
  end
end
