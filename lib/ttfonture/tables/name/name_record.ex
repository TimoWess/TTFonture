defmodule TTFonture.Tables.Name.NameRecord do
  @moduledoc """
  A module for parsing and representing a Name Record within the OpenType/TrueType font 'name' table.
  """

  alias TTFonture.BinaryReader

  @typedoc """
  Type representing a name record from the 'name' table.
  ## Fields

  * `platform_id` - Identifies the platform (0 = Unicode, 1 = Macintosh, 3 = Windows)
  * `platform_specific_id` - Platform-specific encoding ID (varies by platform)
  * `language_id` - Language identifier (varies by platform)
  * `name_id` - Type of name data (0-25+, e.g., 1 = Font Family, 2 = Font Subfamily)
  * `length` - Length of the string data in bytes
  * `offset` - Offset to the string data from the start of the string storage area
  """
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

  @doc """
  Reads a NameRecord from the provided file handle.

  Each NameRecord consists of six uint16 fields (12 bytes total):
  platform ID, platform-specific ID, language ID, name ID, string length, and string offset.

  ## Parameters

  * `file` - An open file handle positioned at the start of a NameRecord

  ## Returns

  * `{:ok, %NameRecord{}}` - Successfully parsed name record
  * `{:error, reason}` - Error reading the data
  """
  @spec read(file :: pid()) :: {:ok, __MODULE__.t()} | {:error, String.t()}
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
