defmodule TTFonture do
  import Bitwise, only: [&&&: 2, >>>: 2]
  alias TTFonture.Glyphs.CompoundGlyph
  alias TTFonture.Glyphs.SimpleGlyph
  alias TTFonture.BinaryReader

  def get_table_directory(file_path \\ "data/test.ttf")

  def get_table_directory(file_path) when is_binary(file_path) do
    case File.open(file_path, [:read, :binary]) do
      {:ok, file} ->
        try do
          get_table_directory(file)
        after
          File.close(file)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_table_directory(file) when is_pid(file) do
    # Skip scaler type
    BinaryReader.skip_bytes(file, 4)

    {:ok, num_tables} = BinaryReader.read_uint16(file)

    # Skip searchRange, entrySelector and rangeShift
    BinaryReader.skip_bytes(file, 6)

    Enum.reduce(1..num_tables, %{}, fn _, acc ->
      with {:ok, tag} <- BinaryReader.read_tag(file),
           {:ok, checksum} <- BinaryReader.read_uint32(file),
           {:ok, offset} <- BinaryReader.read_uint32(file),
           {:ok, length} <- BinaryReader.read_uint32(file) do
        Map.put(acc, tag, checksum: checksum, offset: offset, length: length)
      else
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  def flag_bit_is_set(flag, bit_index) do
    (flag >>> bit_index &&& 1) == 1
  end

  def read_glyph(file, offset) do
    {:ok, number_of_contours} = BinaryReader.read_at_offset(file, offset, &BinaryReader.read_int16/1)

    if number_of_contours >= 0,
      do: SimpleGlyph.read(file, offset),
      else: CompoundGlyph.read(file, offset)
  end

  def get_all_glyph_locations(font_path \\ "data/test.ttf")

  def get_all_glyph_locations(font_path) when is_binary(font_path) do
    case File.open(font_path, [:read, :binary]) do
      {:ok, file} ->
        try do
          get_all_glyph_locations(file)
        after
          File.close(file)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_all_glyph_locations(file) when is_pid(file) do
    table_directory = get_table_directory(file)

    # Skip unused: version
    maxp_offset = Keyword.get(table_directory["maxp"], :offset) + 4

    {:ok, num_glyphs} = BinaryReader.read_at_offset(file, maxp_offset, &BinaryReader.read_uint16/1)

    head_offset = Keyword.get(table_directory["head"], :offset)
    :file.position(file, head_offset)

    # Skip unused: version, fontRevision, checkSumAdjustment, magicNumber?, flags, unitsPerEm, created, modified, xMin, yMin, xMax, yMax, macStyle, lowestRecPPEM, fontDirectionHint
    BinaryReader.skip_bytes(file, 50)

    {:ok, index_to_loc_format} = BinaryReader.read_int16(file)
    is_two_byte_entry = index_to_loc_format == 0
    offset_length = if is_two_byte_entry, do: 2, else: 4

    location_table_start = Keyword.get(table_directory["loca"], :offset)
    glyph_table_start = Keyword.get(table_directory["glyf"], :offset)

    all_glyph_locations =
      Enum.map(0..(num_glyphs - 1), fn glyph_index ->
        :file.position(file, location_table_start + glyph_index * offset_length)

        glyph_data_offset =
          if is_two_byte_entry do
            {:ok, gdo} = BinaryReader.read_uint16(file)
            gdo * 2
          else
            {:ok, gdo} = BinaryReader.read_uint32(file)
            gdo
          end

        glyph_table_start + glyph_data_offset
      end)

    all_glyph_locations
  end

  def read_all_glyphs(font_path \\ "data/test.ttf") do
    case File.open(font_path, [:read, :binary]) do
      {:ok, file} ->
        try do
          all_glyph_locations = get_all_glyph_locations(file)
          Enum.map(all_glyph_locations, fn offset -> read_glyph(file, offset) end)
        after
          File.close(file)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
