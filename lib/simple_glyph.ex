defmodule SimpleGlyph do
  import TtfData, only: [flag_bit_is_set: 2]

  defstruct number_of_contours: 0,
            x_min: 0,
            y_min: 0,
            x_max: 0,
            y_max: 0,
            contour_end_points: [],
            instruction_length: 0,
            instructions: [],
            flags: [],
            coords_x: [],
            coords_y: []

  def read_coordinates(file, all_flags, reading_x: reading_x) do
    offset_size_flag_bit = if reading_x, do: 1, else: 2
    offset_sign_or_skip_bit = if reading_x, do: 4, else: 5

    {coordinates, _} =
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

    coordinates |> Enum.reverse()
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

  def read(file, offset) do
    :file.position(file, offset)
    read(file)
  end

  def read(file) do
    {:ok, number_of_contours} = Reader.read_int16(file)

    {:ok, x_min} = Reader.read_fword(file)
    {:ok, y_min} = Reader.read_fword(file)
    {:ok, x_max} = Reader.read_fword(file)
    {:ok, y_max} = Reader.read_fword(file)

    contour_end_indices =
      Enum.map(1..number_of_contours, fn _ ->
        {:ok, val} = Reader.read_uint16(file)
        val
      end)

    num_points = List.last(contour_end_indices) + 1

    {:ok, instruction_bytes} = Reader.read_int16(file)

    instructions =
      Enum.map(1..instruction_bytes, fn _ ->
        {:ok, instruction} = Reader.read_uint8(file)
        instruction
      end)

    all_flags = collect_flags(file, num_points, 0)

    coords_x = read_coordinates(file, all_flags, reading_x: true)
    coords_y = read_coordinates(file, all_flags, reading_x: false)

    %__MODULE__{
      number_of_contours: number_of_contours,
      x_min: x_min,
      y_min: y_min,
      x_max: x_max,
      y_max: y_max,
      contour_end_points: contour_end_indices,
      instruction_length: instruction_bytes,
      instructions: instructions,
      flags: all_flags,
      coords_x: coords_x,
      coords_y: coords_y
    }
  end
end
