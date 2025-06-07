defmodule TTFonture.Tables.Hmtx.LongHorMetric do
  @type t() :: %__MODULE__{
          advance_width: non_neg_integer(),
          left_side_bearing: integer()
        }

  defstruct advance_width: 0, left_side_bearing: 0
end
