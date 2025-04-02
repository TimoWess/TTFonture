defmodule TTFonture.Tables.Glyf do
  alias TTFonture.Tables.Loca
  alias TTFonture.FileRegister
  alias TTFonture.BinaryReader
  alias TTFonture.Glyphs.CompoundGlyph
  alias TTFonture.Glyphs.SimpleGlyph

  @type glyph() :: SimpleGlyph.t() | CompoundGlyph.t()

  @spec read_glyph(file :: pid(), offset :: non_neg_integer()) :: glyph()
  def read_glyph(file, offset) do
    {:ok, number_of_contours} =
      BinaryReader.read_at_offset(file, offset, &BinaryReader.read_int16/1)

    if number_of_contours >= 0,
      do: SimpleGlyph.read(file, offset),
      else: CompoundGlyph.read(file, offset)
  end

  def read do
    file_info = FileRegister.current()
    read(file_info)
  end

  @spec read(file :: pid()) :: [glyph()]
  def read(file) when is_pid(file) do
    table_directory = TTFonture.get_table_directory(file)
    file_info = %{pid: file, table_directory: table_directory}
    read(file_info)
  end

  @spec read(file :: FileRegister.file_info()) :: [glyph()]
  def read(file_info) do
    # Last entry only needed to calculate length of the glyph
    all_glyph_locations =
      Loca.get_absolute_offsets(file_info) |> Enum.slice(0..-2//1)

    Enum.map(all_glyph_locations, fn offset ->
      read_glyph(file_info.pid, offset)
    end)
  end
end
