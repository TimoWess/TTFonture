defmodule TTFonture.Tables.Htmx do
  alias Ttfonture.Tables.Htmx.LongHorMetric
  alias TTFonture.BinaryReader
  alias TTFonture.Tables.Hhea
  alias TTFonture.Tables.Maxp
  alias TTFonture.FileRegister

  @type t() :: %__MODULE__{
          h_metrics: [LongHorMetric.t()],
          left_side_bearings: [integer()]
        }

  defstruct h_metrics: [], left_side_bearings: []

  @doc false
  @spec collect_h_metrics(file :: pid, num_of_long_hor_metric :: non_neg_integer()) :: [
          LongHorMetric.t()
        ]
  defp collect_h_metrics(_, num_of_long_hor_metric) when num_of_long_hor_metric <= 0, do: []

  defp collect_h_metrics(file, num_of_long_hor_metric) do
    Enum.map(1..num_of_long_hor_metric, fn _ ->
      {:ok, advanced_width} = BinaryReader.read_uint16(file)
      {:ok, left_side_bearing} = BinaryReader.read_int16(file)
      %LongHorMetric{advance_width: advanced_width, left_side_bearing: left_side_bearing}
    end)
  end

  @doc false
  @spec collect_left_side_bearings(file :: pid(), num_of_lsb :: non_neg_integer()) :: [
          non_neg_integer()
        ]
  defp collect_left_side_bearings(_, num_of_lsb) when num_of_lsb <= 0, do: []

  defp collect_left_side_bearings(file, num_of_lsb) do
    Enum.map(1..num_of_lsb, fn _ ->
      {:ok, lsb} = BinaryReader.read_fword(file)
      lsb
    end)
  end

  @spec read() :: {:ok, __MODULE__.t()}
  def read do
    file_info = FileRegister.current()
    read(file_info)
  end

  @spec read(file :: pid()) :: {:ok, __MODULE__.t()}
  def read(file) when is_pid(file) do
    table_directory = TTFonture.get_table_directory(file)
    read(%{pid: file, table_directory: table_directory})
  end

  @spec read(file_info :: FileRegister.file_info()) :: {:ok, __MODULE__.t()}
  def read(file_info = %{pid: file, table_directory: table_directory}) do
    htmx_offset = Keyword.get(table_directory["hmtx"], :offset)

    {:ok, maxp_table} = Maxp.read(file_info)
    {:ok, hhea_table} = Hhea.read(file_info)

    num_of_long_hor_metric = hhea_table.num_of_long_hor_metric
    num_of_glyphs = maxp_table.num_glyphs
    num_of_lsb = num_of_glyphs - num_of_long_hor_metric

    :file.position(file, htmx_offset)
    h_metrics = collect_h_metrics(file, num_of_long_hor_metric)
    left_side_bearings = collect_left_side_bearings(file, num_of_lsb)

    {:ok,
     %__MODULE__{
       h_metrics: h_metrics,
       left_side_bearings: left_side_bearings
     }}
  end
end
