defmodule TTFonture.Tables.Cmap.EncodingSubtable do
  alias TTFonture.BinaryReader

  @type t() :: %__MODULE__{
          platform_id: non_neg_integer(),
          platform_specific_id: non_neg_integer(),
          offset: non_neg_integer()
        }
  defstruct platform_id: 0, platform_specific_id: 0, offset: 0

  @spec read(file :: pid()) :: {:ok, __MODULE__.t()}
  def read(file) do
    {:ok, platform_id} = BinaryReader.read_uint16(file)
    {:ok, platform_specific_id} = BinaryReader.read_uint16(file)
    {:ok, offset} = BinaryReader.read_uint32(file)

    {:ok,
     %__MODULE__{
       platform_id: platform_id,
       platform_specific_id: platform_specific_id,
       offset: offset
     }}
  end
end
