defmodule TTFonture.Tables.Head do
  @moduledoc """
  Struct representing the 'head' table in a TrueType Font.

  The 'head' table contains global information about the font.
  """

  alias TTFonture.FileRegister
  alias TTFonture.BinaryReader
  alias TTFonture.Tables.Common

  @typedoc """
  Type representing the 'head' table structure.

  Fields:
  * `:version` - Fixed 32-bit value: 0x00010000 for version 1.0
  * `:font_revision` - Font revision set by font manufacturer
  * `:checksum_adjustment` - Checksum adjustment value
  * `:magic_number` - Set to 0x5F0F3CF5
  * `:flags` - Bit flags (see flags_description for details)
  * `:units_per_em` - Units per em, range from 64 to 16384
  * `:created` - International date (seconds since 1904-01-01 00:00:00)
  * `:modified` - International date (seconds since 1904-01-01 00:00:00)
  * `:x_min` - Minimum x for all glyph bounding boxes
  * `:y_min` - Minimum y for all glyph bounding boxes
  * `:x_max` - Maximum x for all glyph bounding boxes
  * `:y_max` - Maximum y for all glyph bounding boxes
  * `:mac_style` - Style bits (see mac_style_description for details)
  * `:lowest_rec_ppem` - Smallest readable size in pixels
  * `:font_direction_hint` - Font direction hint
  * `:index_to_loc_format` - 0 for short offsets, 1 for long
  * `:glyph_data_format` - 0 for current format
  """
  @type t :: %__MODULE__{
          version: non_neg_integer(),
          font_revision: non_neg_integer(),
          checksum_adjustment: non_neg_integer(),
          magic_number: non_neg_integer(),
          flags: non_neg_integer(),
          units_per_em: non_neg_integer(),
          created: integer(),
          modified: integer(),
          x_min: integer(),
          y_min: integer(),
          x_max: integer(),
          y_max: integer(),
          mac_style: non_neg_integer(),
          lowest_rec_ppem: non_neg_integer(),
          font_direction_hint: integer(),
          index_to_loc_format: integer(),
          glyph_data_format: integer()
        }

  defstruct version: 0x00010000,
            font_revision: 0x00010000,
            checksum_adjustment: 0,
            magic_number: 0x5F0F3CF5,
            flags: 0,
            units_per_em: 2048,
            created: 0,
            modified: 0,
            x_min: 0,
            y_min: 0,
            x_max: 0,
            y_max: 0,
            mac_style: 0,
            lowest_rec_ppem: 0,
            font_direction_hint: 0,
            index_to_loc_format: 0,
            glyph_data_format: 0

  @spec read() :: {:ok, __MODULE__.t()}
  def read do
    Common.read_cached_table("head", &read_head_table/1)
  end

  @spec read(pid() | FileRegister.file_info()) :: {:ok, __MODULE__.t()}
  def read(file) when is_pid(file) do
    Common.read_table_from_file(file, &read_head_table/1)
  end

  def read(%{pid: _file, table_directory: _table_directory} = file_info),
    do: read_head_table(file_info)

  def read_head_table(%{pid: file, table_directory: table_directory}) do
    head_offset = Keyword.get(table_directory["head"], :offset)
    :file.position(file, head_offset)

    with {:ok, version} <- BinaryReader.read_fixed(file),
         {:ok, font_revision} <- BinaryReader.read_fixed(file),
         {:ok, checksum_adjustment} <- BinaryReader.read_uint32(file),
         {:ok, magic_number} <- BinaryReader.read_uint32(file),
         {:ok, flags} <- BinaryReader.read_uint16(file),
         {:ok, units_per_em} <- BinaryReader.read_uint16(file),
         {:ok, created} <- BinaryReader.read_long_date_time(file),
         {:ok, modified} <- BinaryReader.read_long_date_time(file),
         {:ok, x_min} <- BinaryReader.read_fword(file),
         {:ok, y_min} <- BinaryReader.read_fword(file),
         {:ok, x_max} <- BinaryReader.read_fword(file),
         {:ok, y_max} <- BinaryReader.read_fword(file),
         {:ok, mac_style} <- BinaryReader.read_uint16(file),
         {:ok, lowest_rec_ppem} <- BinaryReader.read_uint16(file),
         {:ok, font_direction_hint} <- BinaryReader.read_int16(file),
         {:ok, index_to_loc_format} <- BinaryReader.read_int16(file),
         {:ok, glyph_data_format} <- BinaryReader.read_int16(file) do
      {:ok,
       %__MODULE__{
         version: version,
         font_revision: font_revision,
         checksum_adjustment: checksum_adjustment,
         magic_number: magic_number,
         flags: flags,
         units_per_em: units_per_em,
         created: created,
         modified: modified,
         x_min: x_min,
         y_min: y_min,
         x_max: x_max,
         y_max: y_max,
         mac_style: mac_style,
         lowest_rec_ppem: lowest_rec_ppem,
         font_direction_hint: font_direction_hint,
         index_to_loc_format: index_to_loc_format,
         glyph_data_format: glyph_data_format
       }}
    end
  end

  @spec calc_checksum_adjustment() :: non_neg_integer()
  def calc_checksum_adjustment() do
    file = FileRegister.current_pid()
    table_directory = FileRegister.current_table_directory()
    head_offset = Keyword.get(table_directory["head"], :offset)
    :file.position(file, 0)

    entire_file = IO.binread(file, :eof)

    checksum_adj_pos = head_offset + 8

    # Zero out the checksumAdjustment field (4 bytes at head_offset + 8)
    <<before::binary-size(checksum_adj_pos), _ca::big-unsigned-32, rest::binary>> =
      entire_file

    data = before <> <<0, 0, 0, 0>> <> rest

    size = byte_size(data)

    padded_data =
      if rem(size, 4) == 0, do: data, else: data <> <<0::size((4 - rem(size, 4)) * 8)>>

    calc_sum =
      for <<value::big-unsigned-32 <- padded_data>>, reduce: 0 do
        sum -> sum + value
      end
      # Simulate 32-bit integer overflow
      |> Bitwise.band(0xFFFFFFFF)

    res = 0xB1B0AFBA - calc_sum

    # Simulate 32-bit integer underflow
    if res < 0, do: Bitwise.band(rem(res, 2 ** 32), 0xFFFFFFFF), else: res
  end
end
