defmodule TTFonture.BinaryReader do
  @moduledoc false

  @type binary_term() :: integer() | float() | binary()
  @type result() :: {:ok, binary_term()} | {:error, String.t()}
  @type file_interaction() :: (file :: pid() -> result :: result())

  @spec skip_bytes(file :: pid(), bytes :: non_neg_integer()) :: result()
  def skip_bytes(file, bytes) do
    case :file.position(file, {:cur, bytes}) do
      {:ok, new_position} -> {:ok, new_position}
      {:error, reason} -> {:error, "Failed to skip #{bytes} bytes: #{format_error(reason)}"}
      :eof -> {:error, "Reach EOF"}
    end
  end

  @spec read_fixed(file :: pid()) :: result()
  def read_fixed(file) do
    case :file.read(file, 4) do
      {:ok, <<fixed_value::signed-integer-32>>} -> {:ok, fixed_value / 65536.0}
      {:ok, _incomplete_data} -> {:error, "Incomplete data when reading Fixed value"}
      {:error, reason} -> {:error, "Failed to read Fixed value: #{format_error(reason)}"}
      :eof -> {:error, "Reach EOF"}
    end
  end

  @spec read_fword(file :: pid()) :: result()
  def read_fword(file) do
    case :file.read(file, 2) do
      {:ok, <<fword::signed-integer-16>>} -> {:ok, fword}
      {:ok, _incomplete_data} -> {:error, "Incomplete data when reading FWord value"}
      {:error, reason} -> {:error, "Failed to read FWord value: #{format_error(reason)}"}
      :eof -> {:error, "Reach EOF"}
    end
  end

  @spec read_uword(file :: pid()) :: result()
  def read_uword(file) do
    case :file.read(file, 2) do
      {:ok, <<uword::unsigned-integer-16>>} -> {:ok, uword}
      {:ok, _incomplete_data} -> {:error, "Incomplete data when reading UWord value"}
      {:error, reason} -> {:error, "Failed to read UWord value: #{format_error(reason)}"}
      :eof -> {:error, "Reach EOF"}
    end
  end

  @spec read_long_date_time(file :: pid()) :: result()
  def read_long_date_time(file) do
    case :file.read(file, 8) do
      {:ok, <<long_date_time::signed-integer-64>>} -> {:ok, long_date_time}
      {:ok, _incomplete_data} -> {:error, "Incomplete data when reading LongDateTime value"}
      {:error, reason} -> {:error, "Failed to read LongDateTime value: #{format_error(reason)}"}
      :eof -> {:error, "Reach EOF"}
    end
  end

  @spec read_int8(file :: pid()) :: result()
  def read_int8(file) do
    case :file.read(file, 1) do
      {:ok, <<int8::signed-integer-8>>} -> {:ok, int8}
      {:ok, _incomplete_data} -> {:error, "Incomplete data when reading Int8 value"}
      {:error, reason} -> {:error, "Failed to read Int8 value: #{format_error(reason)}"}
      :eof -> {:error, "Reach EOF"}
    end
  end

  @spec read_int16(file :: pid()) :: result()
  def read_int16(file) do
    case :file.read(file, 2) do
      {:ok, <<int16::signed-integer-16>>} -> {:ok, int16}
      {:ok, _incomplete_data} -> {:error, "Incomplete data when reading Int16 value"}
      {:error, reason} -> {:error, "Failed to read Int16 value: #{format_error(reason)}"}
      :eof -> {:error, "Reach EOF"}
    end
  end

  @spec read_int32(file :: pid()) :: result()
  def read_int32(file) do
    case :file.read(file, 4) do
      {:ok, <<int32::signed-integer-32>>} -> {:ok, int32}
      {:ok, _incomplete_data} -> {:error, "Incomplete data when reading Int32 value"}
      {:error, reason} -> {:error, "Failed to read Int32 value: #{format_error(reason)}"}
      :eof -> {:error, "Reach EOF"}
    end
  end

  @spec read_int64(file :: pid()) :: result()
  def read_int64(file) do
    case :file.read(file, 8) do
      {:ok, <<int64::signed-integer-64>>} -> {:ok, int64}
      {:ok, _incomplete_data} -> {:error, "Incomplete data when reading Int64 value"}
      {:error, reason} -> {:error, "Failed to read Int64 value: #{format_error(reason)}"}
      :eof -> {:error, "Reach EOF"}
    end
  end

  @spec read_uint8(file :: pid()) :: result()
  def read_uint8(file) do
    case :file.read(file, 1) do
      {:ok, <<uint8::unsigned-integer-8>>} -> {:ok, uint8}
      {:ok, _incomplete_data} -> {:error, "Incomplete data when reading UInt8 value"}
      {:error, reason} -> {:error, "Failed to read UInt8 value: #{format_error(reason)}"}
      :eof -> {:error, "Reach EOF"}
    end
  end

  @spec read_uint16(file :: pid()) :: result()
  def read_uint16(file) do
    case :file.read(file, 2) do
      {:ok, <<uint16::unsigned-integer-16>>} -> {:ok, uint16}
      {:ok, _incomplete_data} -> {:error, "Incomplete data when reading UInt16 value"}
      {:error, reason} -> {:error, "Failed to read UInt16 value: #{format_error(reason)}"}
      :eof -> {:error, "Reach EOF"}
    end
  end

  @spec read_uint32(file :: pid()) :: result()
  def read_uint32(file) do
    case :file.read(file, 4) do
      {:ok, <<uint32::unsigned-integer-32>>} -> {:ok, uint32}
      {:ok, _incomplete_data} -> {:error, "Incomplete data when reading UInt32 value"}
      {:error, reason} -> {:error, "Failed to read UInt32 value: #{format_error(reason)}"}
      :eof -> {:error, "Reach EOF"}
    end
  end

  @spec read_uint64(file :: pid()) :: result()
  def read_uint64(file) do
    case :file.read(file, 8) do
      {:ok, <<uint64::unsigned-integer-64>>} -> {:ok, uint64}
      {:ok, _incomplete_data} -> {:error, "Incomplete data when reading UInt64 value"}
      {:error, reason} -> {:error, "Failed to read UInt64 value: #{format_error(reason)}"}
      :eof -> {:error, "Reach EOF"}
    end
  end

  @spec read_short_frac(file :: pid()) :: result()
  def read_short_frac(file) do
    case :file.read(file, 2) do
      {:ok, <<short_frac::signed-integer-16>>} -> {:ok, short_frac / 16384.0}
      {:ok, _incomplete_data} -> {:error, "Incomplete data when reading ShortFrac value"}
      {:error, reason} -> {:error, "Failed to read ShortFrac value: #{format_error(reason)}"}
      :eof -> {:error, "Reach EOF"}
    end
  end

  @spec read_f2dot14(file :: pid()) :: result()
  def read_f2dot14(file) do
    case :file.read(file, 2) do
      {:ok, <<f2dot14::signed-integer-16>>} -> {:ok, f2dot14 / 16384.0}
      {:ok, _incomplete_data} -> {:error, "Incomplete data when reading F2Dot14 value"}
      {:error, reason} -> {:error, "Failed to read F2Dot14 value: #{format_error(reason)}"}
      :eof -> {:error, "Reach EOF"}
    end
  end

  @spec read_tag(file :: pid()) :: result()
  def read_tag(file) do
    case :file.read(file, 4) do
      {:ok, <<tag::binary-size(4)>>} -> {:ok, tag}
      {:ok, _incomplete_data} -> {:error, "Incomplete data when reading Tag value"}
      {:error, reason} -> {:error, "Failed to read Tag value: #{format_error(reason)}"}
      :eof -> {:error, "Reach EOF"}
    end
  end

  @spec read_pascal_string(file :: pid()) :: result()
  def read_pascal_string(file) do
    case read_uint8(file) do
      {:ok, length} ->
        case :file.read(file, length) do
          {:ok, <<string_data::binary-size(length)>>} ->
            {:ok, string_data}

          {:ok, _incomplete_data} ->
            {:error, "Incomplete data when reading Pascal string of length #{length}"}

          {:error, reason} ->
            {:error, "Failed to read Pascal string data: #{format_error(reason)}"}

          :eof ->
            {:error, "Reach EOF"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec read_at_offset(file :: pid(), offset :: non_neg_integer(), read_fn :: file_interaction()) ::
          result()
  def read_at_offset(file, offset, read_fn) do
    case :file.position(file, {:bof, offset}) do
      {:ok, _new_position} ->
        result = read_fn.(file)
        # Restore original position (optional)
        # :file.position(file, original_position)
        result

      {:error, reason} ->
        {:error, "Failed to seek to offset #{offset}: #{format_error(reason)}"}
    end
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason) when is_atom(reason), do: "#{reason}"
  defp format_error(_reason), do: "unknown error"
end
