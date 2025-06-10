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
  and handles both format 4 and format 12 mappings.

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
      {:ok, glyph_id} -> {:ok, glyph_id}
      {:error, :not_found} -> find_in_format_4(mapping_subtables, char_code)
    end
  end

  @doc """
  Same as char_to_glyph_id/2 but returns the glyph ID directly or nil if not found.
  """
  @spec char_to_glyph_id!(t(), non_neg_integer()) :: non_neg_integer() | nil
  def char_to_glyph_id!(cmap, char_code) do
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

  # Look up character in format 4 segments (more complex algorithm)
  defp lookup_in_format_4_segments(data, char_code) do
    %{
      start_codes: start_codes,
      end_codes: end_codes,
      id_deltas: id_deltas,
      id_range_offsets: id_range_offsets,
      glyph_id_array: glyph_id_array
    } = data

    # Find the segment that contains this character
    segment_index = find_segment_index(end_codes, char_code)

    if segment_index != nil do
      start_code = Enum.at(start_codes, segment_index)

      if char_code >= start_code do
        id_delta = Enum.at(id_deltas, segment_index)
        id_range_offset = Enum.at(id_range_offsets, segment_index)

        glyph_id =
          if id_range_offset == 0 do
            # Simple case: add delta directly
            rem(char_code + id_delta, 65536)
          else
            # Complex case: look up in glyph_id_array
            array_index =
              div(id_range_offset, 2) + (char_code - start_code) -
                (length(id_range_offsets) - segment_index)

            if array_index >= 0 && array_index < length(glyph_id_array) do
              base_glyph_id = Enum.at(glyph_id_array, array_index)

              if base_glyph_id != 0 do
                rem(base_glyph_id + id_delta, 65536)
              else
                0
              end
            else
              0
            end
          end

        {:ok, glyph_id}
      else
        {:error, :not_found}
      end
    else
      {:error, :not_found}
    end
  end

  # Binary search to find the segment containing the character
  defp find_segment_index(end_codes, char_code) do
    Enum.find_index(end_codes, fn end_code -> char_code <= end_code end)
  end
end
