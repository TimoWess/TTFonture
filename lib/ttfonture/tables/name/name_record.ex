defmodule TTFonture.Tables.Name.NameRecord do
  alias TTFonture.BinaryReader

  @type t() :: %__MODULE__{
          platform_id: non_neg_integer(),
          platform_specific_id: non_neg_integer(),
          language_id: non_neg_integer(),
          name_id: non_neg_integer(),
          length: non_neg_integer(),
          offset: non_neg_integer()
        }

  defstruct platform_id: 0,
            platform_specific_id: 0,
            language_id: 0,
            name_id: 0,
            length: 0,
            offset: 0

  def read(file) do
    with {:ok, platform_id} <- BinaryReader.read_uint16(file),
         {:ok, platform_specific_id} <- BinaryReader.read_uint16(file),
         {:ok, language_id} <- BinaryReader.read_uint16(file),
         {:ok, name_id} <- BinaryReader.read_uint16(file),
         {:ok, length} <- BinaryReader.read_uint16(file),
         {:ok, offset} <- BinaryReader.read_uint16(file) do
      {:ok,
       %__MODULE__{
         platform_id: platform_id,
         platform_specific_id: platform_specific_id,
         language_id: language_id,
         name_id: name_id,
         length: length,
         offset: offset
       }}
    end
  end
end
