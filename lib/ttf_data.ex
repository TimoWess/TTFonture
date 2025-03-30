defmodule TtfData do
  import Bitwise, only: [&&&: 2, >>>: 2]

  def get_table_directory(file_path \\ "data/test.ttf") do
    case File.open(file_path, [:read, :binary]) do
      {:ok, file} ->
        try do
          # Skip scaler type
          Reader.skip_bytes(file, 4)

          # Read the next 2 bytes
          {:ok, num_tables} = Reader.read_uint16(file)

          # Skip searchRange, entrySelector and rangeShift
          Reader.skip_bytes(file, 6)

          Enum.reduce(1..num_tables, %{}, fn _, acc ->
            with {:ok, tag} <- Reader.read_tag(file),
                 {:ok, checksum} <- Reader.read_uint32(file),
                 {:ok, offset} <- Reader.read_uint32(file),
                 {:ok, length} <- Reader.read_uint32(file) do
              Map.put(acc, tag, checksum: checksum, offset: offset, length: length)
            else
              {:error, reason} -> {:error, reason}
            end
          end)
        after
          File.close(file)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def flag_bit_is_set(flag, bit_index) do
    (flag >>> bit_index &&& 1) == 1
  end

  def read_glyph(file, offset) do
    {:ok, number_of_contours} = Reader.read_at_offset(file, offset, &Reader.read_int16/1)

    if number_of_contours >= 0,
      do: SimpleGlyph.read(file, offset),
      else: CompoundGlyph.read(file, offset)
  end

  def get_all_glyph_locations(font_path \\ "data/test.ttf") do
    table_directory = get_table_directory(font_path)

    case File.open(font_path, [:read, :binary]) do
      {:ok, file} ->
        try do
          # Skip unused: version
          maxp_offset = Keyword.get(table_directory["maxp"], :offset) + 4

          {:ok, num_glyphs} = Reader.read_at_offset(file, maxp_offset, &Reader.read_uint16/1)

          head_offset = Keyword.get(table_directory["head"], :offset)
          :file.position(file, head_offset)

          # Skip unused: version, fontRevision, checkSumAdjustment, magicNumber?, flags, unitsPerEm, created, modified, xMin, yMin, xMax, yMax, macStyle, lowestRecPPEM, fontDirectionHint
          Reader.skip_bytes(file, 50)

          {:ok, index_to_loc_format} = Reader.read_int16(file)
          is_two_byte_entry = index_to_loc_format == 0
          offset_length = if is_two_byte_entry, do: 2, else: 4

          location_table_start = Keyword.get(table_directory["loca"], :offset)
          glyph_table_start = Keyword.get(table_directory["glyf"], :offset)

          all_glyph_locations =
            Enum.map(0..(num_glyphs - 1), fn glyph_index ->
              :file.position(file, location_table_start + glyph_index * offset_length)

              glyph_data_offset =
                if is_two_byte_entry do
                  {:ok, gdo} = Reader.read_uint16(file)
                  gdo * 2
                else
                  {:ok, gdo} = Reader.read_uint32(file)
                  gdo
                end

              glyph_table_start + glyph_data_offset
            end)

          all_glyph_locations
        after
          File.close(file)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def read_all_glyphs(font_path \\ "data/test.ttf") do
    case File.open(font_path, [:read, :binary]) do
      {:ok, file} ->
        try do
          all_glyph_locations = get_all_glyph_locations(font_path)
          Enum.map(all_glyph_locations, fn offset -> read_glyph(file, offset) end)
        after
          File.close(file)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
