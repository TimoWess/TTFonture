defmodule TTFonture.Tables.Cmap.MappingSubtable do
  alias TTFonture.Tables.Cmap.EncodingSubtable
  alias TTFonture.BinaryReader

  @type t() :: %__MODULE__{format: non_neg_integer(), data: map()}
  defstruct format: 0, data: %{}

  @spec collect_n_uint16(file :: pid(), n :: non_neg_integer()) :: {:ok, [non_neg_integer()]}
  defp collect_n_uint16(_file, n) when n <= 0, do: []

  defp collect_n_uint16(file, n) do
    {:ok,
     Enum.map(1..n, fn _ ->
       {:ok, val} = BinaryReader.read_uint16(file)
       val
     end)}
  end

  @spec collect_groups(file :: pid(), n_groups :: non_neg_integer()) ::
          {:ok,
           [
             %{
               start_char_code: non_neg_integer(),
               end_char_code: non_neg_integer(),
               start_glyph_code: non_neg_integer()
             }
           ]}
  defp collect_groups(_file, n_groups) when n_groups <= 0, do: []

  defp collect_groups(file, n_groups) do
    {:ok,
     Enum.map(1..n_groups, fn _ ->
       {:ok, start_char_code} = BinaryReader.read_uint32(file)
       {:ok, end_char_code} = BinaryReader.read_uint32(file)
       {:ok, start_glyph_code} = BinaryReader.read_uint32(file)

       %{
         start_char_code: start_char_code,
         end_char_code: end_char_code,
         start_glyph_code: start_glyph_code
       }
     end)}
  end

  @spec read(file :: pid, cmap_offset :: non_neg_integer(), EncodingSubtable.t()) ::
          {:ok, __MODULE__.t()}
  def read(file, cmap_offset, %EncodingSubtable{offset: es_offset}) do
    :file.position(file, cmap_offset + es_offset)
    {:ok, format} = BinaryReader.read_uint16(file)
    read_by_format(file, format)
  end

  @spec read_by_format(file :: pid(), format :: non_neg_integer()) :: {:ok, __MODULE__.t()}
  defp read_by_format(file, 4) do
    {:ok, length} = BinaryReader.read_uint16(file)
    {:ok, language} = BinaryReader.read_uint16(file)
    {:ok, seg_count_x2} = BinaryReader.read_uint16(file)
    {:ok, search_range} = BinaryReader.read_uint16(file)
    {:ok, entry_selector} = BinaryReader.read_uint16(file)
    {:ok, range_shift} = BinaryReader.read_uint16(file)

    seg_count = trunc(seg_count_x2 / 2)

    {:ok, end_codes} = collect_n_uint16(file, seg_count)
    {:ok, reserved_pad} = BinaryReader.read_uint16(file)
    {:ok, start_codes} = collect_n_uint16(file, seg_count)
    {:ok, id_deltas} = collect_n_uint16(file, seg_count)
    {:ok, id_range_offsets} = collect_n_uint16(file, seg_count)

    remaining_bytes = length - (16 + seg_count * 8)
    # 2 bytes per glyph ID
    glyph_id_count = div(remaining_bytes, 2)
    {:ok, glyph_id_array} = collect_n_uint16(file, glyph_id_count)

    data = %{
      length: length,
      language: language,
      seg_count_x2: seg_count_x2,
      search_range: search_range,
      entry_selector: entry_selector,
      range_shift: range_shift,
      end_codes: end_codes,
      reserved_pad: reserved_pad,
      start_codes: start_codes,
      id_deltas: id_deltas,
      id_range_offsets: id_range_offsets,
      glyph_id_array: glyph_id_array
    }

    {:ok, %__MODULE__{format: 4, data: data}}
  end

  defp read_by_format(file, 12) do
    {:ok, reserved} = BinaryReader.read_uint16(file)
    {:ok, length} = BinaryReader.read_uint32(file)
    {:ok, language} = BinaryReader.read_uint32(file)
    {:ok, n_groups} = BinaryReader.read_uint32(file)
    {:ok, groups} = collect_groups(file, n_groups)

    data = %{
      reserved: reserved,
      length: length,
      language: language,
      n_groups: n_groups,
      groups: groups
    }

    {:ok, %__MODULE__{format: 12, data: data}}
  end
end
