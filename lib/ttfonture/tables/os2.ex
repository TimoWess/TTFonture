defmodule TTFonture.Tables.OS2 do
  alias TTFonture.BinaryReader
  alias TTFonture.FileRegister

  @type t() :: %__MODULE__{
          # Version 0 fields
          version: non_neg_integer(),
          x_avg_char_width: integer(),
          us_weight_class: non_neg_integer(),
          us_width_class: non_neg_integer(),
          fs_type: non_neg_integer(),
          y_subscript_x_size: integer(),
          y_subscript_y_size: integer(),
          y_subscript_x_offset: integer(),
          y_subscript_y_offset: integer(),
          y_superscript_x_size: integer(),
          y_superscript_y_size: integer(),
          y_superscript_x_offset: integer(),
          y_superscript_y_offset: integer(),
          y_strikeout_size: integer(),
          y_strikeout_position: integer(),
          s_family_class: integer(),
          panose: list(non_neg_integer()),
          ul_unicode_range1: non_neg_integer(),
          ul_unicode_range2: non_neg_integer(),
          ul_unicode_range3: non_neg_integer(),
          ul_unicode_range4: non_neg_integer(),
          ach_vendor_id: binary(),
          fs_selection: non_neg_integer(),
          us_first_char_index: non_neg_integer(),
          us_last_char_index: non_neg_integer(),
          s_typo_ascender: integer(),
          s_typo_descender: integer(),
          s_typo_line_gap: integer(),

          # Version 1 fields
          us_win_ascent: non_neg_integer(),
          us_win_descent: non_neg_integer(),

          # Version 2 fields
          ul_code_page_range1: non_neg_integer(),
          ul_code_page_range2: non_neg_integer(),

          # Version 3 & 4 fields
          sx_height: integer(),
          s_cap_height: integer(),
          us_default_char: non_neg_integer(),
          us_break_char: non_neg_integer(),
          us_max_context: non_neg_integer(),

          # Version 5 fields
          us_lower_optical_point_size: non_neg_integer(),
          us_upper_optical_point_size: non_neg_integer()
        }

  defstruct [
    # Version 0 fields
    version: 0,
    x_avg_char_width: 0,
    us_weight_class: 0,
    us_width_class: 0,
    fs_type: 0,
    y_subscript_x_size: 0,
    y_subscript_y_size: 0,
    y_subscript_x_offset: 0,
    y_subscript_y_offset: 0,
    y_superscript_x_size: 0,
    y_superscript_y_size: 0,
    y_superscript_x_offset: 0,
    y_superscript_y_offset: 0,
    y_strikeout_size: 0,
    y_strikeout_position: 0,
    s_family_class: 0,
    panose: List.duplicate(0, 10),
    ul_unicode_range1: 0,
    ul_unicode_range2: 0,
    ul_unicode_range3: 0,
    ul_unicode_range4: 0,
    ach_vendor_id: "",
    fs_selection: 0,
    us_first_char_index: 0,
    us_last_char_index: 0,
    s_typo_ascender: 0,
    s_typo_descender: 0,
    s_typo_line_gap: 0,

    # Version 1 fields
    us_win_ascent: 0,
    us_win_descent: 0,

    # Version 2 fields
    ul_code_page_range1: 0,
    ul_code_page_range2: 0,

    # Version 3 & 4 fields
    sx_height: 0,
    s_cap_height: 0,
    us_default_char: 0,
    us_break_char: 0,
    us_max_context: 0,

    # Version 5 fields
    us_lower_optical_point_size: 0,
    us_upper_optical_point_size: 0
  ]

  @spec read() :: {:ok, __MODULE__.t()}
  def read do
    file_info = FileRegister.current()
    read(file_info)
  end

  @spec read(pid() | FileRegister.file_info()) :: {:ok, __MODULE__.t()}
  def read(file) when is_pid(file) do
    table_directory = TTFonture.get_table_directory(file)
    file_info = %{pid: file, table_directory: table_directory}
    read(file_info)
  end

  def read(%{pid: file, table_directory: table_directory}) do
    os2_offset = Keyword.get(table_directory["OS/2"], :offset)
    :file.position(file, os2_offset)

    # Read version first to determine how much data to read
    {:ok, version} = BinaryReader.read_uint16(file)

    # Read version 0 fields - required in all versions
    {:ok, x_avg_char_width} = BinaryReader.read_int16(file)
    {:ok, us_weight_class} = BinaryReader.read_uint16(file)
    {:ok, us_width_class} = BinaryReader.read_uint16(file)
    {:ok, fs_type} = BinaryReader.read_uint16(file)
    {:ok, y_subscript_x_size} = BinaryReader.read_int16(file)
    {:ok, y_subscript_y_size} = BinaryReader.read_int16(file)
    {:ok, y_subscript_x_offset} = BinaryReader.read_int16(file)
    {:ok, y_subscript_y_offset} = BinaryReader.read_int16(file)
    {:ok, y_superscript_x_size} = BinaryReader.read_int16(file)
    {:ok, y_superscript_y_size} = BinaryReader.read_int16(file)
    {:ok, y_superscript_x_offset} = BinaryReader.read_int16(file)
    {:ok, y_superscript_y_offset} = BinaryReader.read_int16(file)
    {:ok, y_strikeout_size} = BinaryReader.read_int16(file)
    {:ok, y_strikeout_position} = BinaryReader.read_int16(file)
    {:ok, s_family_class} = BinaryReader.read_int16(file)

    # Read PANOSE classification (10 bytes)
    {:ok, panose_data} = :file.read(file, 10)
    panose = :binary.bin_to_list(panose_data)

    {:ok, ul_unicode_range1} = BinaryReader.read_uint32(file)
    {:ok, ul_unicode_range2} = BinaryReader.read_uint32(file)
    {:ok, ul_unicode_range3} = BinaryReader.read_uint32(file)
    {:ok, ul_unicode_range4} = BinaryReader.read_uint32(file)

    # Read 4-byte vendor ID tag and convert to string
    {:ok, vendor_id_data} = :file.read(file, 4)
    ach_vendor_id = vendor_id_data

    {:ok, fs_selection} = BinaryReader.read_uint16(file)
    {:ok, us_first_char_index} = BinaryReader.read_uint16(file)
    {:ok, us_last_char_index} = BinaryReader.read_uint16(file)
    {:ok, s_typo_ascender} = BinaryReader.read_int16(file)
    {:ok, s_typo_descender} = BinaryReader.read_int16(file)
    {:ok, s_typo_line_gap} = BinaryReader.read_int16(file)

    # Initialize with default values for fields that may not be read
    table = %__MODULE__{
      version: version,
      x_avg_char_width: x_avg_char_width,
      us_weight_class: us_weight_class,
      us_width_class: us_width_class,
      fs_type: fs_type,
      y_subscript_x_size: y_subscript_x_size,
      y_subscript_y_size: y_subscript_y_size,
      y_subscript_x_offset: y_subscript_x_offset,
      y_subscript_y_offset: y_subscript_y_offset,
      y_superscript_x_size: y_superscript_x_size,
      y_superscript_y_size: y_superscript_y_size,
      y_superscript_x_offset: y_superscript_x_offset,
      y_superscript_y_offset: y_superscript_y_offset,
      y_strikeout_size: y_strikeout_size,
      y_strikeout_position: y_strikeout_position,
      s_family_class: s_family_class,
      panose: panose,
      ul_unicode_range1: ul_unicode_range1,
      ul_unicode_range2: ul_unicode_range2,
      ul_unicode_range3: ul_unicode_range3,
      ul_unicode_range4: ul_unicode_range4,
      ach_vendor_id: ach_vendor_id,
      fs_selection: fs_selection,
      us_first_char_index: us_first_char_index,
      us_last_char_index: us_last_char_index,
      s_typo_ascender: s_typo_ascender,
      s_typo_descender: s_typo_descender,
      s_typo_line_gap: s_typo_line_gap
    }

    # Read version-specific fields
    table =
      if version >= 1 do
        {:ok, us_win_ascent} = BinaryReader.read_uint16(file)
        {:ok, us_win_descent} = BinaryReader.read_uint16(file)

        %{table | us_win_ascent: us_win_ascent, us_win_descent: us_win_descent}
      else
        table
      end

    table =
      if version >= 2 do
        {:ok, ul_code_page_range1} = BinaryReader.read_uint32(file)
        {:ok, ul_code_page_range2} = BinaryReader.read_uint32(file)

        %{
          table
          | ul_code_page_range1: ul_code_page_range1,
            ul_code_page_range2: ul_code_page_range2
        }
      else
        table
      end

    table =
      if version >= 3 do
        {:ok, sx_height} = BinaryReader.read_int16(file)
        {:ok, s_cap_height} = BinaryReader.read_int16(file)
        {:ok, us_default_char} = BinaryReader.read_uint16(file)
        {:ok, us_break_char} = BinaryReader.read_uint16(file)
        {:ok, us_max_context} = BinaryReader.read_uint16(file)

        %{
          table
          | sx_height: sx_height,
            s_cap_height: s_cap_height,
            us_default_char: us_default_char,
            us_break_char: us_break_char,
            us_max_context: us_max_context
        }
      else
        table
      end

    table =
      if version >= 5 do
        {:ok, us_lower_optical_point_size} = BinaryReader.read_uint16(file)
        {:ok, us_upper_optical_point_size} = BinaryReader.read_uint16(file)

        %{
          table
          | us_lower_optical_point_size: us_lower_optical_point_size,
            us_upper_optical_point_size: us_upper_optical_point_size
        }
      else
        table
      end

    {:ok, table}
  end
end
