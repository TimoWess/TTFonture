defmodule TTFonture.Integration.GlyphLoadingTest do
  use ExUnit.Case
  alias TTFonture.FileRegister
  alias TTFonture.Tables.{Glyf, Loca, Head, Maxp}
  alias TTFonture.TestHelpers
  
  setup do
    path = TestHelpers.setup_font("opensans.ttf")
    %{path: path}
  end
  
  test "load all glyphs correctly" do
    # First verify we can read the maxp table to get glyph count
    {:ok, maxp} = Maxp.read()
    assert maxp.num_glyphs > 0
    
    # Verify head table for index_to_loc_format
    {:ok, head} = Head.read()
    assert head.index_to_loc_format == 0 || head.index_to_loc_format == 1
    
    # Get glyph offsets
    {:ok, offsets} = Loca.get_absolute_offsets()
    assert length(offsets) >= maxp.num_glyphs
    
    # Read all glyphs
    {:ok, glyphs} = Glyf.read()
    assert length(glyphs) == maxp.num_glyphs

    FileRegister.close_all()
  end
end
