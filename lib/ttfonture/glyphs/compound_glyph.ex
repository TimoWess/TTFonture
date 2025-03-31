defmodule TTFonture.Glyphs.CompoundGlyph do
  import TTFonture.Utility, only: [flag_bit_is_set: 2]
  alias TTFonture.BinaryReader

  defstruct x_min: 0,
            y_min: 0,
            x_max: 0,
            y_max: 0,
            components: []

  def read_transformation(file, flag) do
    cond do
      # WE_HAVE_A_SCALE
      flag_bit_is_set(flag, 3) ->
        {:ok, scale} = BinaryReader.read_f2dot14(file)
        %{type: :uniform_scale, scale: scale}

      # WE_HAVE_AN_X_AND_Y_SCALE
      flag_bit_is_set(flag, 6) ->
        {:ok, x_scale} = BinaryReader.read_f2dot14(file)
        {:ok, y_scale} = BinaryReader.read_f2dot14(file)
        %{type: :xy_scale, x_scale: x_scale, y_scale: y_scale}

      # WE_HAVE_A_TWO_BY_TWO
      flag_bit_is_set(flag, 7) ->
        {:ok, x_scale} = BinaryReader.read_f2dot14(file)
        {:ok, scale01} = BinaryReader.read_f2dot14(file)
        {:ok, scale10} = BinaryReader.read_f2dot14(file)
        {:ok, y_scale} = BinaryReader.read_f2dot14(file)
        %{type: :matrix, x_scale: x_scale, scale01: scale01, scale10: scale10, y_scale: y_scale}

      # No transformation data
      true ->
        %{type: :identity}
    end
  end

  def read_components(file) do
    {:ok, flag} = BinaryReader.read_uint16(file)
    {:ok, glyph_index} = BinaryReader.read_uint16(file)

    arg_1_and_2_are_words = flag_bit_is_set(flag, 0)
    _args_are_xy_values = flag_bit_is_set(flag, 1)

    more_components = flag_bit_is_set(flag, 5)

    argument_reader_function =
      if arg_1_and_2_are_words, do: &BinaryReader.read_int16/1, else: &BinaryReader.read_int8/1

    {:ok, argument_1} = argument_reader_function.(file)
    {:ok, argument_2} = argument_reader_function.(file)

    transformation = read_transformation(file, flag)

    if more_components,
      do: [{glyph_index, argument_1, argument_2, transformation} | read_components(file)],
      else: [{glyph_index, argument_1, argument_2, transformation}]
  end

  def read(file, offset) do
    :file.position(file, offset)
    read(file)
  end

  def read(file) do
    # Skip numberOfContours
    BinaryReader.skip_bytes(file, 2)

    {:ok, x_min} = BinaryReader.read_fword(file)
    {:ok, y_min} = BinaryReader.read_fword(file)
    {:ok, x_max} = BinaryReader.read_fword(file)
    {:ok, y_max} = BinaryReader.read_fword(file)

    components = read_components(file)

    %__MODULE__{x_min: x_min, y_min: y_min, x_max: x_max, y_max: y_max, components: components}
  end
end
