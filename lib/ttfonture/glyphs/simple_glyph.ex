defmodule TTFonture.Glyphs.SimpleGlyph do
  @moduledoc """
  Represents and processes Simple Glyphs within TrueType fonts.

  A SimpleGlyph contains outline data for a character with one or more contours defined by points.
  Each contour is a closed path represented by a series of points, which can be either on-curve
  or off-curve control points defining Bézier curves.

  The glyph outline is stored as a series of contours with coordinates in the font's coordinate system.
  """

  import TTFonture.Utility, only: [flag_bit_is_set: 2]
  alias TTFonture.BinaryReader

  @type flag() :: non_neg_integer()
  @type t() :: %__MODULE__{
          number_of_contours: non_neg_integer(),
          x_min: integer(),
          y_min: integer(),
          x_max: integer(),
          y_max: integer(),
          contour_end_points: [non_neg_integer()],
          instruction_length: non_neg_integer(),
          instructions: [non_neg_integer()],
          flags: [flag()],
          coords_x: [integer()],
          coords_y: [integer()]
        }

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

  defmodule Flag do
    @moduledoc """
    Represents the flag byte used in TrueType glyph descriptions.

    Each point in a glyph outline has an associated flag that provides information about:
    - Whether the point is on the curve or a control point
    - How to interpret and decode the coordinate data
    - Handling of repeated points
    """

    @type t() :: %__MODULE__{
            on_curve: boolean(),
            x_short_vector: boolean(),
            y_short_vector: boolean(),
            repeat: boolean(),
            offset_sign_or_skip_x: boolean(),
            offset_sign_or_skip_y: boolean()
          }

    defstruct on_curve: false,
              x_short_vector: false,
              y_short_vector: false,
              repeat: false,
              offset_sign_or_skip_x: false,
              offset_sign_or_skip_y: false
  end

  @doc """
  Calculates the final coordinate offset value based on the flag values.

  TrueType uses a delta encoding scheme to store coordinates efficiently.
  This function decodes a coordinate based on the previous coordinate and flag values.

  ## Parameters
    - `file`: File handle for the TTF file being read
    - `base_offset`: Previous coordinate value to build upon
    - `flag`: The flag byte for the current point
    - `offset_size_flag_bit`: Bit position indicating short vector format (1 for x, 2 for y)
    - `offset_sign_or_skip_bit`: Bit position indicating sign or skip (4 for x, 5 for y)
    
  ## Returns
    The final calculated coordinate value
  """
  @spec calculate_final_offset(
          file :: pid(),
          base_offset :: non_neg_integer(),
          flag :: flag(),
          offset_size_flag_bit :: non_neg_integer(),
          offset_sign_or_skip_bit :: non_neg_integer()
        ) :: non_neg_integer()
  def calculate_final_offset(
        file,
        base_offset,
        flag,
        offset_size_flag_bit,
        offset_sign_or_skip_bit
      ) do
    cond do
      flag_bit_is_set(flag, offset_size_flag_bit) ->
        {:ok, offset} = BinaryReader.read_uint8(file)
        sign = if flag_bit_is_set(flag, offset_sign_or_skip_bit), do: 1, else: -1
        base_offset + offset * sign

      not flag_bit_is_set(flag, offset_sign_or_skip_bit) ->
        {:ok, offset} = BinaryReader.read_int16(file)
        base_offset + offset

      true ->
        base_offset
    end
  end

  @doc """
  Reads and decodes a sequence of coordinate values (either x or y) for all points.

  TrueType stores coordinates as delta values from the previous point to save space.
  This function reconstructs the absolute coordinates from the compressed form.

  ## Parameters
    - `file`: File handle for the TTF file being read
    - `all_flags`: List of flag bytes for all points
    - `reading_x`: Boolean indicating whether x (true) or y (false) coordinates are being read
    
  ## Returns
    A list of coordinate values in their original order
  """
  @spec read_coordinates(file :: pid(), all_flags :: [flag()], reading_x: boolean()) :: [
          integer()
        ]
  def read_coordinates(file, all_flags, reading_x: reading_x) do
    offset_size_flag_bit = if reading_x, do: 1, else: 2
    offset_sign_or_skip_bit = if reading_x, do: 4, else: 5

    {coordinates, _} =
      Enum.reduce(all_flags, {[], 0}, fn flag, {acc, last_offset} ->
        base_offset = last_offset

        _on_curve = flag_bit_is_set(flag, 0)

        final_offset =
          calculate_final_offset(
            file,
            base_offset,
            flag,
            offset_size_flag_bit,
            offset_sign_or_skip_bit
          )

        {[final_offset | acc], final_offset}
      end)

    coordinates |> Enum.reverse()
  end

  @doc """
  Parses a raw flag byte into a structured Flag struct.

  ## Parameters
    - `flag`: The raw flag byte from the font file
    
  ## Returns
    A Flag struct with boolean fields representing each flag bit's meaning
  """
  @spec parse_flag(flag :: flag()) :: __MODULE__.Flag.t()
  def parse_flag(flag) do
    on_curve = flag_bit_is_set(flag, 0)
    x_short_vector = flag_bit_is_set(flag, 1)
    y_short_vector = flag_bit_is_set(flag, 2)
    repeat = flag_bit_is_set(flag, 3)
    offset_sign_or_skip_x = flag_bit_is_set(flag, 4)
    offset_sign_or_skip_y = flag_bit_is_set(flag, 5)

    %__MODULE__.Flag{
      on_curve: on_curve,
      x_short_vector: x_short_vector,
      y_short_vector: y_short_vector,
      repeat: repeat,
      offset_sign_or_skip_x: offset_sign_or_skip_x,
      offset_sign_or_skip_y: offset_sign_or_skip_y
    }
  end

  @doc """
  Collects and processes all flag bytes for a glyph, handling the run-length encoding
  used by TrueType to compress repeated flags.

  ## Parameters
    - `file`: File handle for the TTF file being read
    - `number_of_points`: Total number of points to collect flags for
    - `index`: Current processing index
    
  ## Returns
    A list of flag bytes, with repeated flags expanded
  """
  @spec collect_flags(
          file :: pid(),
          number_of_points :: non_neg_integer(),
          index :: non_neg_integer()
        ) ::
          [flag()]
  def collect_flags(_, number_of_points, index) when index >= number_of_points, do: []

  def collect_flags(file, number_of_points, index) do
    {:ok, flag} = BinaryReader.read_uint8(file)

    if flag_bit_is_set(flag, 3) do
      {:ok, number_of_copies} = BinaryReader.read_uint8(file)

      List.duplicate(flag, number_of_copies) ++
        collect_flags(file, number_of_points, index + number_of_copies)
    else
      [flag | collect_flags(file, number_of_points, index + 1)]
    end
  end

  @doc """
  Reads a SimpleGlyph from a file at a specific offset.

  ## Parameters
    - `file`: File handle for the TTF file being read
    - `offset`: Byte offset in the file where the glyph data begins
    
  ## Returns
    A SimpleGlyph struct containing all glyph data
  """
  @spec read(file :: pid(), offset :: non_neg_integer()) :: __MODULE__.t()
  def read(file, offset) do
    :file.position(file, offset)
    read(file)
  end

  @doc """
  Reads a SimpleGlyph from a file at the current position.

  This function reads and parses the complete data structure of a simple glyph
  as defined in the TrueType specification, including:
  - Bounding box coordinates
  - Contour endpoints
  - Hinting instructions
  - Point coordinates with their associated flags

  ## Parameters
    - `file`: File handle for the TTF file being read, positioned at glyph data
    
  ## Returns
    A SimpleGlyph struct containing all glyph data
  """
  @spec read(file :: pid()) :: __MODULE__.t()
  def read(file) do
    {:ok, number_of_contours} = BinaryReader.read_int16(file)

    {:ok, x_min} = BinaryReader.read_fword(file)
    {:ok, y_min} = BinaryReader.read_fword(file)
    {:ok, x_max} = BinaryReader.read_fword(file)
    {:ok, y_max} = BinaryReader.read_fword(file)

    contour_end_indices =
      Enum.map(1..number_of_contours, fn _ ->
        {:ok, val} = BinaryReader.read_uint16(file)
        val
      end)

    number_of_points = List.last(contour_end_indices) + 1

    {:ok, instruction_bytes} = BinaryReader.read_int16(file)

    instructions =
      Enum.map(1..instruction_bytes, fn _ ->
        {:ok, instruction} = BinaryReader.read_uint8(file)
        instruction
      end)

    all_flags = collect_flags(file, number_of_points, 0)

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
