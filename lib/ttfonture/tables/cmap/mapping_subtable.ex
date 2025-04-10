defmodule TTFonture.Tables.Cmap.MappingSubtable do
  alias TTFonture.Tables.Cmap.EncodingSubtable
  alias TTFonture.BinaryReader
  defstruct format: 0, length: 0, data: %{}

  def collect_n_uint16(_file, 0), do: []

  def collect_n_uint16(file, seg_count) do
    {:ok,
     Enum.map(1..seg_count, fn _ ->
       {:ok, val} = BinaryReader.read_uint16(file)
       val
     end)}
  end

  def read(file, cmap_offset, %EncodingSubtable{offset: es_offset}) do
    :file.position(file, cmap_offset + es_offset)
    {:ok, format} = BinaryReader.read_uint16(file)
    read_by_format(file, format)
  end

  def read_by_format(file, 4) do
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

    remaining_bytes = length - (14 + seg_count * 8 + 2)
    glyph_id_count = div(remaining_bytes, 2)  # 2 bytes per glyph ID
    {:ok, glyph_id_array} = collect_n_uint16(file, glyph_id_count)

    %{
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
  end

  def read_by_format(file, 12) do
    :todo_12
  end
end
