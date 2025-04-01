defmodule TTFonture.Tables.Loca do
  alias TTFonture.BinaryReader

  @type t() :: [offset()]
  @type offset() :: non_neg_integer()

  @spec read(file :: pid()) :: __MODULE__.t()
  def read(file) when is_pid(file) do
    table_directory = TTFonture.get_table_directory(file)

    # Skip unused: version
    maxp_offset = Keyword.get(table_directory["maxp"], :offset) + 4

    {:ok, number_of_glyphs} =
      BinaryReader.read_at_offset(file, maxp_offset, &BinaryReader.read_uint16/1)

    head_offset = Keyword.get(table_directory["head"], :offset)
    :file.position(file, head_offset)

    # Skip unused: version, fontRevision, checkSumAdjustment, magicNumber?, flags, unitsPerEm, created, modified, xMin, yMin, xMax, yMax, macStyle, lowestRecPPEM, fontDirectionHint
    BinaryReader.skip_bytes(file, 50)

    {:ok, index_to_loc_format} = BinaryReader.read_int16(file)
    is_two_byte_entry = index_to_loc_format == 0
    offset_length = if is_two_byte_entry, do: 2, else: 4

    location_table_start = Keyword.get(table_directory["loca"], :offset)

    all_glyph_locations =
      Enum.map(0..number_of_glyphs, fn glyph_index ->
        :file.position(file, location_table_start + glyph_index * offset_length)

        if is_two_byte_entry do
          {:ok, gdo} = BinaryReader.read_uint16(file)
          gdo * 2
        else
          {:ok, gdo} = BinaryReader.read_uint32(file)
          gdo
        end
      end)

    all_glyph_locations
  end

  @spec get_absolute_offsets(file :: pid()) :: __MODULE__.t()
  def get_absolute_offsets(file) when is_pid(file) do
    table_directory = TTFonture.get_table_directory(file)
    glyph_table_start = Keyword.get(table_directory["glyf"], :offset)
    loca_table_entries = read(file)

    Enum.map(loca_table_entries, fn relative_offset -> relative_offset + glyph_table_start end)
  end
end
