defmodule Reader do
  import Bitwise, only: [&&&: 2, >>>: 2]

  def get_table_directory(file_path \\ "data/test.ttf") do
    case File.open(file_path, [:read, :binary]) do
      {:ok, file} ->
        try do
          # Skip the first 4 bytes
          :file.position(file, 4)

          # Read the next 2 bytes
          {:ok, num_tables} =
            case :file.read(file, 2) do
              {:ok, <<value::big-size(16)>>} ->
                {:ok, value}

              {:ok, _} ->
                {:error, :insufficient_data}

              {:error, reason} ->
                {:error, reason}
            end

          :file.position(file, elem(:file.position(file, :cur), 1) + 6)

          Enum.reduce(1..num_tables, %{}, fn _, acc ->
            {:ok, <<tag::binary>>} = :file.read(file, 4)
            {:ok, <<checksum::unsigned-integer-32>>} = :file.read(file, 4)
            {:ok, <<offset::unsigned-integer-32>>} = :file.read(file, 4)
            {:ok, <<length::unsigned-integer-32>>} = :file.read(file, 4)

            Map.put(acc, tag, checksum: checksum, offset: offset, length: length)
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

    {:ok, file} = File.open(font_path, [:read, :binary])

    glyf_offset = Keyword.get(table_directory["glyf"], :offset)

    :file.position(file, glyf_offset)
    {glyf_xcoords, glyf_ycoords, contour_end_indices} = read_simple_glyph(file)
    :file.close(file)
    IO.inspect(Enum.with_index(contour_end_indices))
    Enum.zip(glyf_xcoords, glyf_ycoords)
  end

  def flag_bit_is_set(flag, bit_index) do
    (flag >>> bit_index &&& 1) == 1
  end

  def read_coordinates(file, all_flags, reading_x: true) do
    offset_size_flag_bit = 1
    offset_sign_or_skip_bit = 4
    coordinates_length = length(all_flags)

    Enum.reduce(0..(coordinates_length - 1), [], fn i, acc ->
      base_offset = if i == 0, do: 0, else: Enum.at(acc, i - 1)
      flag = Enum.at(all_flags, i)

      _on_curve = flag_bit_is_set(flag, 0)

      final_offset =
        cond do
          flag_bit_is_set(flag, offset_size_flag_bit) ->
            {:ok, <<offset::8>>} = :file.read(file, 1)
            sign = if flag_bit_is_set(flag, offset_sign_or_skip_bit), do: 1, else: -1
            base_offset + offset * sign

          not flag_bit_is_set(flag, offset_sign_or_skip_bit) ->
            {:ok, <<offset::8>>} = :file.read(file, 1)
            base_offset + offset

          true ->
            base_offset
        end

      acc ++ [final_offset]
    end)
  end

  def read_coordinates(file, all_flags, reading_x: false) do
    offset_size_flag_bit = 2
    offset_sign_or_skip_bit = 5
    coordinates_length = length(all_flags)

    Enum.reduce(0..(coordinates_length - 1), [], fn i, acc ->
      base_offset = if i == 0, do: 0, else: Enum.at(acc, i - 1)
      flag = Enum.at(all_flags, i)

      _on_curve = flag_bit_is_set(flag, 0)

      final_offset =
        cond do
          flag_bit_is_set(flag, offset_size_flag_bit) ->
            {:ok, <<offset::8>>} = :file.read(file, 1)
            sign = if flag_bit_is_set(flag, offset_sign_or_skip_bit), do: 1, else: -1
            base_offset + offset * sign

          not flag_bit_is_set(flag, offset_sign_or_skip_bit) ->
            {:ok, <<offset::8>>} = :file.read(file, 1)
            base_offset + offset

          true ->
            base_offset
        end

      acc ++ [final_offset]
    end)
  end

  def read_simple_glyph(file) do
    {:ok, <<contour_end_indices_size::integer-16>>} = :file.read(file, 2)
    :file.read(file, 8)

    contour_end_indices =
      Enum.map(1..contour_end_indices_size, fn _ ->
        {:ok, <<val::unsigned-integer-16>>} = :file.read(file, 2)
        val
      end)

    num_points = List.last(contour_end_indices) + 1

    {:ok, <<instruction_bytes::integer-16>>} = :file.read(file, 2)
    :file.read(file, instruction_bytes)

    all_flags = collect_flags(file, num_points, 0) |> Enum.reverse()

    coords_x = read_coordinates(file, all_flags, reading_x: true)
    coords_y = read_coordinates(file, all_flags, reading_x: false)

    {coords_x, coords_y, contour_end_indices}
  end

  def collect_flags(_, num_points, num_points), do: []

  def collect_flags(file, num_points, index) do
    {:ok, <<flag::8>>} = :file.read(file, 1)
    fbis? = flag_bit_is_set(flag, 3)

    if fbis? do
      {:ok, <<number_of_copys::8>>} = :file.read(file, 1)

      List.duplicate(flag, number_of_copys) ++
        collect_flags(file, num_points, index + number_of_copys)
    else
      [flag | collect_flags(file, num_points, index + 1)]
    end
  end
end
