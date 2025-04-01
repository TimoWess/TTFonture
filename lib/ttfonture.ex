defmodule TTFonture do
  alias TTFonture.Glyphs.CompoundGlyph
  alias TTFonture.Glyphs.SimpleGlyph
  alias TTFonture.BinaryReader

  @type glyph() :: SimpleGlyph.t() | CompoundGlyph.t()
  @type table_directory() :: %{
          binary() => [
            checksum: non_neg_integer(),
            offset: non_neg_integer(),
            length: non_neg_integer()
          ]
        }

  def get_table_directory(file_path \\ "data/test.ttf")

  @spec get_table_directory(binary()) :: table_directory() | {:error, binary()}
  def get_table_directory(file_path) when is_binary(file_path) do
    case File.open(file_path, [:read, :binary]) do
      {:ok, file} ->
        try do
          get_table_directory(file)
        after
          File.close(file)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec get_table_directory(pid()) :: table_directory() | {:error, binary()}
  def get_table_directory(file) when is_pid(file) do
    # Skip scaler type
    :file.position(file, {:bof, 4})

    {:ok, num_tables} = BinaryReader.read_uint16(file)

    # Skip searchRange, entrySelector and rangeShift
    BinaryReader.skip_bytes(file, 6)

    Enum.reduce(1..num_tables, %{}, fn _, acc ->
      with {:ok, tag} <- BinaryReader.read_tag(file),
           {:ok, checksum} <- BinaryReader.read_uint32(file),
           {:ok, offset} <- BinaryReader.read_uint32(file),
           {:ok, length} <- BinaryReader.read_uint32(file) do
        Map.put(acc, tag, checksum: checksum, offset: offset, length: length)
      else
        {:error, reason} -> {:error, reason}
      end
    end)
  end
end
