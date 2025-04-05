defmodule TTFonture.Tables.Hhea do
  alias TTFonture.BinaryReader
  alias TTFonture.FileRegister

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

  def read do
    file_info = FileRegister.current()
    read(file_info)
  end

  def read(file) when is_pid(file) do
    table_directory = TTFonture.get_table_directory(file)
    read(%{pid: file, table_directory: table_directory})
  end

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
