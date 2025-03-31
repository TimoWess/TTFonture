defmodule TTFonture.Utility do
  import Bitwise, only: [>>>: 2, &&&: 2]

  @spec flag_bit_is_set(flag :: integer(), bit_index :: non_neg_integer()) :: boolean()
  def flag_bit_is_set(flag, bit_index) do
    (flag >>> bit_index &&& 1) == 1
  end
end
