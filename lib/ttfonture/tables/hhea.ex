defmodule TTFonture.Tables.Hhea do
  @moduledoc """
  Struct representing the 'hhea' (Horizontal Header) table in a TrueType/OpenType Font.

  The 'hhea' table contains global information about horizontal layout features of the font.
  It defines metrics like ascent, descent, line gap, and other horizontal typographic values
  that apply to the font as a whole.
  """

  alias TTFonture.BinaryReader
  alias TTFonture.FileRegister

  @typedoc """
  Type representing the 'hhea' table structure.

  Fields:
  * `:version` - Version number of the table (normally 1.0)
  * `:ascent` - Distance from baseline of highest ascender
  * `:descent` - Distance from baseline of lowest descender (typically negative)
  * `:line_gap` - Typographic line gap
  * `:advance_width_max` - Maximum advance width value in hmtx table
  * `:min_left_side_bearing` - Minimum left sidebearing value in hmtx table
  * `:min_right_side_bearing` - Minimum right sidebearing value
  * `:x_max_extent` - Max(lsb + (xMax - xMin))
  * `:caret_slope_rise` - Used to calculate the slope of the caret
  * `:caret_slope_run` - Used to calculate the slope of the caret
  * `:caret_offset` - The amount by which a slanted highlight on a glyph needs to be shifted
  * `:metric_data_format` - Format of metrics data (set to 0)
  * `:num_of_long_hor_metric` - Number of hMetric entries in hmtx table
  """
  @type t() :: %__MODULE__{
          version: float(),
          ascent: integer(),
          descent: integer(),
          line_gap: integer(),
          advance_width_max: non_neg_integer(),
          min_left_side_bearing: integer(),
          min_right_side_bearing: integer(),
          x_max_extent: integer(),
          caret_slope_rise: integer(),
          caret_slope_run: integer(),
          caret_offset: integer(),
          metric_data_format: integer(),
          num_of_long_hor_metric: non_neg_integer()
        }

  defstruct version: 0.0,
            ascent: 0,
            descent: 0,
            line_gap: 0,
            advance_width_max: 0,
            min_left_side_bearing: 0,
            min_right_side_bearing: 0,
            x_max_extent: 0,
            caret_slope_rise: 0,
            caret_slope_run: 0,
            caret_offset: 0,
            metric_data_format: 0,
            num_of_long_hor_metric: 0

  @doc """
  Reads the 'hhea' table from the currently registered font file.

  ## Returns

  Parsed hhea table structure with all horizontal metrics information.
  """
  @spec read() :: __MODULE__.t() | {:error, String.t()}
  def read do
    file_info = FileRegister.current()
    read(file_info)
  end

  @doc """
  Reads the 'hhea' table from the provided font file.

  ## Parameters

  * `file` - Open file handle to the font file

  ## Returns

  * `%TTFonture.Tables.Hhea{}` - Successfully parsed hhea table
  * `{:error, reason}` - Error reading the table
  """
  @spec read(file :: pid()) :: __MODULE__.t() | {:error, String.t()}
  def read(file) when is_pid(file) do
    table_directory = TTFonture.get_table_directory(file)
    read(%{pid: file, table_directory: table_directory})
  end

  @spec read(FileRegister.file_info()) :: __MODULE__.t() | {:error, String.t()}
  def read(%{pid: file, table_directory: table_directory}) do
    head_offset = Keyword.get(table_directory["hhea"], :offset)
    :file.position(file, head_offset)

    with {:ok, version} <- BinaryReader.read_fixed(file),
         {:ok, ascent} <- BinaryReader.read_fword(file),
         {:ok, descent} <- BinaryReader.read_fword(file),
         {:ok, line_gap} <- BinaryReader.read_fword(file),
         {:ok, advance_width_max} <- BinaryReader.read_ufword(file),
         {:ok, min_left_side_bearing} <- BinaryReader.read_fword(file),
         {:ok, min_right_side_bearing} <- BinaryReader.read_fword(file),
         {:ok, x_max_extent} <- BinaryReader.read_fword(file),
         {:ok, caret_slope_rise} <- BinaryReader.read_int16(file),
         {:ok, caret_slope_run} <- BinaryReader.read_int16(file),
         {:ok, caret_offset} <- BinaryReader.read_fword(file),
         # Skip reserved bytes
         {:ok, _} <- BinaryReader.skip_bytes(file, 8),
         {:ok, metric_data_format} <- BinaryReader.read_int16(file),
         {:ok, num_of_long_hor_metric} <- BinaryReader.read_uint16(file) do
      %__MODULE__{
        version: version,
        ascent: ascent,
        descent: descent,
        line_gap: line_gap,
        advance_width_max: advance_width_max,
        min_left_side_bearing: min_left_side_bearing,
        min_right_side_bearing: min_right_side_bearing,
        x_max_extent: x_max_extent,
        caret_slope_rise: caret_slope_rise,
        caret_slope_run: caret_slope_run,
        caret_offset: caret_offset,
        metric_data_format: metric_data_format,
        num_of_long_hor_metric: num_of_long_hor_metric
      }
    end
  end
end
