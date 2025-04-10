ExUnit.start()

defmodule TTFonture.TestHelpers do
  @moduledoc """
  Helper functions for TTFonture tests.
  """
  
  @fixture_path Path.expand("fixtures", __DIR__)
  
  @doc """
  Returns the path to a fixture file.
  """
  def fixture_path(filename) do
    Path.join(@fixture_path, filename)
  end
  
  @doc """
  Opens a fixture file and returns the file handle.
  """
  def open_fixture(filename) do
    path = fixture_path(filename)
    File.open!(path, [:binary, :read])
  end
  
  @doc """
  Sets up a test by opening a font file and registering it.
  """
  def setup_font(filename) do
    path = fixture_path(filename)
    TTFonture.FileRegister.start_link()
    TTFonture.FileRegister.register(path)
    path
  end
end
