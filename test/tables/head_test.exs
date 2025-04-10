defmodule TTFonture.Tables.HeadTest do
  use ExUnit.Case
  alias TTFonture.FileRegister
  alias TTFonture.Tables.Head

  setup do
    path = TTFonture.TestHelpers.setup_font("opensans.ttf")
    %{path: path}
  end

  test "reads head table correctly" do
    {:ok, head} = Head.read()

    # Basic structure checks
    assert %Head{} = head
    assert head.magic_number == 0x5F0F3CF5
    assert head.version == 0x00010000 / 65536

    # Font-specific checks (adjust values for your test font)
    assert head.units_per_em > 0
    assert head.x_min < head.x_max
    assert head.y_min < head.y_max

    FileRegister.close_all()
  end
end
