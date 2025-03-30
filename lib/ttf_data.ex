defmodule TtfData do
  import Bitwise, only: [&&&: 2, >>>: 2]

  def get_table_directory(file_path \\ "data/test.ttf") do
    case File.open(file_path, [:read, :binary]) do
      {:ok, file} ->
        try do
          # Skip scaler type
          Reader.skip_bytes(file, 4)

          # Read the next 2 bytes
          {:ok, num_tables} =
            case Reader.read_uint16(file) do
              {:ok, value} ->
                {:ok, value}

              {:error, reason} ->
                {:error, reason}
            end

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

  def parse_font(font_path \\ "data/test.ttf") do
    table_directory = get_table_directory(font_path)

    case File.open(font_path, [:read, :binary]) do
      {:ok, file} ->
        try do
          glyf_offset = Keyword.get(table_directory["glyf"], :offset)

          :file.position(file, glyf_offset)
          {glyf_xcoords, glyf_ycoords, contour_end_indices} = read_simple_glyph(file)
          IO.inspect(Enum.with_index(contour_end_indices))
          Enum.zip(glyf_xcoords, glyf_ycoords)
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

  def read_coordinates(file, all_flags, reading_x: reading_x) do
    offset_size_flag_bit = if reading_x, do: 1, else: 2
    offset_sign_or_skip_bit = if reading_x, do: 4, else: 5

    {cooridantes, _} =
      Enum.reduce(all_flags, {[], 0}, fn flag, {acc, last} ->
        base_offset = last

        _on_curve = flag_bit_is_set(flag, 0)

        final_offset =
          cond do
            flag_bit_is_set(flag, offset_size_flag_bit) ->
              {:ok, offset} = Reader.read_uint8(file)
              sign = if flag_bit_is_set(flag, offset_sign_or_skip_bit), do: 1, else: -1
              base_offset + offset * sign

            not flag_bit_is_set(flag, offset_sign_or_skip_bit) ->
              {:ok, offset} = Reader.read_int16(file)
              base_offset + offset

            true ->
              base_offset
          end

        {[final_offset | acc], final_offset}
      end)

    cooridantes |> Enum.reverse()
  end

  def read_simple_glyph(file, offset) do
    :file.position(file, offset)
    read_simple_glyph(file)
  end

  def read_simple_glyph(file) do
    {:ok, number_of_contours} = Reader.read_int16(file)

    # Skip bounding box size
    Reader.skip_bytes(file, 8)

    contour_end_indices =
      Enum.map(1..number_of_contours, fn _ ->
        {:ok, val} = Reader.read_uint16(file)
        val
      end)

    num_points = List.last(contour_end_indices) + 1

    # Skip instructions
    {:ok, instruction_bytes} = Reader.read_int16(file)
    Reader.skip_bytes(file, instruction_bytes)

    all_flags = collect_flags(file, num_points, 0)

    coords_x = read_coordinates(file, all_flags, reading_x: true)
    coords_y = read_coordinates(file, all_flags, reading_x: false)

    IO.inspect(Enum.zip(coords_x, coords_y))

    {coords_x, coords_y, contour_end_indices}
  end

  def collect_flags(_, num_points, index) when index >= num_points, do: []

  def collect_flags(file, num_points, index) do
    {:ok, flag} = Reader.read_uint8(file)

    if flag_bit_is_set(flag, 3) do
      {:ok, number_of_copies} = Reader.read_uint8(file)

      List.duplicate(flag, number_of_copies) ++
        collect_flags(file, num_points, index + number_of_copies)
    else
      [flag | collect_flags(file, num_points, index + 1)]
    end
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
          Enum.map(all_glyph_locations, fn offset -> read_simple_glyph(file, offset) end)
        after
          File.close(file)
        end
      {:error, reason} -> {:error, reason}
    end
  end
end
