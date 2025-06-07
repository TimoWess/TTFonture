defmodule TTFonture.Tables.Common do
  @moduledoc """
  Common functionality shared across all table modules.
  """

  alias TTFonture.FileRegister

  @doc """
  Generic table reader with caching support.

  This function handles the common pattern of:
  1. Check cache first
  2. If not cached, read from file
  3. Cache the result
  4. Return the table
  """
  @spec read_cached_table(
          table_name :: String.t(),
          read_fn :: (FileRegister.file_info() -> {:ok, any()})
        ) :: {:ok, any()}
  def read_cached_table(table_name, read_fn) do
    case FileRegister.get_cached(table_name) do
      {:ok, table} ->
        {:ok, table}

      {:error, _} ->
        file_info = FileRegister.current()
        {:ok, table} = read_fn.(file_info)
        FileRegister.cache_table(table_name, table)
        {:ok, table}
    end
  end

  @doc """
  Generic table reader for direct file access (no caching).
  """
  @spec read_table_from_file(
          file :: pid(),
          read_fn :: (FileRegister.file_info() -> {:ok, any()})
        ) :: {:ok, any()}
  def read_table_from_file(file, read_fn) when is_pid(file) do
    {:ok, table_directory} = TTFonture.get_table_directory(file)
    file_info = %{pid: file, table_directory: table_directory, tables: %{}}
    read_fn.(file_info)
  end
end
