defmodule TTFonture.Glyphs.CompoundGlyph do
  @moduledoc """
  Represents and processes Compound Glyphs within TrueType fonts.

  A CompoundGlyph is composed of multiple components, where each component references another
  glyph in the font (either a SimpleGlyph or another CompoundGlyph). Each component includes
  positioning data and transformation information that determine how the referenced glyph
  should be placed and modified.

  Compound glyphs enable efficient reuse of glyph components within a font. For example,
  accented characters can be composed by combining a base letter glyph with accent marks.
  """

  import TTFonture.Utility, only: [flag_bit_is_set: 2]
  alias TTFonture.BinaryReader

  @type t() :: %__MODULE__{
          x_min: integer(),
          y_min: integer(),
          x_max: integer(),
          y_max: integer(),
          components: [component()]
        }
  @type index() :: non_neg_integer()
  @type transformation() ::
          %{type: :uniform_scale, scale: float()}
          | %{type: :xy_scale, x_scale: float(), y_scale: float()}
          | %{
              type: :matrix,
              x_scale: float(),
              scale01: float(),
              scale10: float(),
              y_scale: float()
            }
          | %{type: :identity}
  @type component() :: {index(), integer(), integer(), transformation()}

  defstruct x_min: 0,
            y_min: 0,
            x_max: 0,
            y_max: 0,
            components: []

  @doc """
  Reads transformation data for a component based on flag values.

  TrueType supports various transformations for component glyphs:
  - Uniform scaling (same scale factor for both axes)
  - XY scaling (different scale factors for each axis)
  - 2×2 matrix transformation (full affine transformation)
  - No transformation (identity)

  ## Parameters
    - `file`: File handle for the TTF file being read
    - `flag`: The component flag word
    
  ## Returns
    A transformation map with the appropriate type and parameters
  """
  @spec read_transformation(file :: pid(), flag :: non_neg_integer()) :: transformation()
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

  @doc """
  Recursively reads all components of a compound glyph.

  Each component includes:
  - A glyph index pointing to another glyph in the font
  - Position arguments (either offsets or anchor points)
  - Transformation data

  The function continues reading components until it finds one without the
  MORE_COMPONENTS flag set.

  ## Parameters
    - `file`: File handle for the TTF file being read
    
  ## Returns
    A list of component tuples, each containing glyph index, position arguments, and transformation
  """
  @spec read_components(file :: pid()) :: [component()]
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

  @doc """
  Reads a CompoundGlyph from a file at a specific offset.

  ## Parameters
    - `file`: File handle for the TTF file being read
    - `offset`: Byte offset in the file where the glyph data begins
    
  ## Returns
    A CompoundGlyph struct containing the bounding box and all component data
  """
  @spec read(file :: pid(), offset :: non_neg_integer()) :: __MODULE__.t()
  def read(file, offset) do
    :file.position(file, offset)
    read(file)
  end

  @doc """
  Reads a CompoundGlyph from a file at the current position.

  This function reads and parses the complete data structure of a compound glyph
  as defined in the TrueType specification, including:
  - Bounding box coordinates
  - All component glyphs with their transformations

  ## Parameters
    - `file`: File handle for the TTF file being read, positioned at glyph data
    
  ## Returns
    A CompoundGlyph struct containing the bounding box and all component data
  """
  @spec read(file :: pid()) :: __MODULE__.t()
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
