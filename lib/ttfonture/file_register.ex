defmodule TTFonture.FileRegister do
  @moduledoc """
  Provides a centralized registry for TTF file handles with automatic table directory caching.

  The FileRegister module simplifies working with multiple font files by:

  1. Managing file handles through a central registry
  2. Caching table directories to avoid repeated parsing
  3. Tracking a "current" file for streamlined API usage
  4. Handling file cleanup automatically

  This module is implemented as an Elixir Agent, making it stateful and safe to use
  across processes. It's typically started as part of your application's supervision tree.

  ## Usage Example

  ```elixir
  # Start the FileRegister (usually in your application's supervision tree)
  TTFonture.FileRegister.start_link()

  # Register a font file and make it the current file
  TTFonture.FileRegister.register("fonts/opensans.ttf")

  # Work with the current file
  pid = TTFonture.FileRegister.current_pid()
  table_directory = TTFonture.FileRegister.current_table_directory()

  # Register another font (becomes the new current file)
  TTFonture.FileRegister.register("fonts/roboto.ttf")

  # When done with a specific file
  TTFonture.FileRegister.close("fonts/opensans.ttf")

  # Or close all files when finished
  TTFonture.FileRegister.close_all()
  ```
  """

  use Agent

  @type table_directory() :: %{
          binary() => [
            checksum: non_neg_integer(),
            offset: non_neg_integer(),
            length: non_neg_integer()
          ]
        }
  @type file_info() :: %{pid: pid(), table_directory: table_directory()}
  @type state() :: %{files: %{binary() => file_info()}, current: file_info() | nil}

  @doc """
  Starts the FileRegister agent.
  """
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{current: nil, files: %{}} end, name: __MODULE__)
  end

  @doc """
  Registers a font file and sets it as the current file.

  This function:
  1. Opens the file if it's not already registered
  2. Reads and caches its table directory
  3. Makes it the current file for subsequent operations
  4. Reuses existing file handles when possible

  ## Parameters

  - `path`: Path to the TTF file to register

  ## Returns

  A map containing:
  - `:pid` - The file handle
  - `:table_directory` - The parsed table directory for the font

  ## Example

  ```elixir
  # Register a font file
  file_info = TTFonture.FileRegister.register("fonts/myfont.ttf")

  # You can use the returned information directly
  file_pid = file_info.pid
  table_dir = file_info.table_directory

  # But usually you'll use the current_* functions instead
  ```
  """
  @spec register(path :: binary()) :: file_info()
  def register(path) do
    file_info =
      Agent.get(__MODULE__, fn state ->
        Map.get(state.files, path)
      end)

    if is_nil(file_info) || !Process.alive?(file_info.pid) do
      {:ok, file} = File.open(path, [:binary, :read])
      table_directory = TTFonture.get_table_directory(file)

      file_info = %{pid: file, table_directory: table_directory}

      Agent.update(__MODULE__, fn state ->
        %{state | current: file_info, files: Map.put(state.files, path, file_info)}
      end)

      file_info
    else
      Agent.update(__MODULE__, fn state ->
        %{state | current: file_info}
      end)

      file_info
    end
  end

  @doc """
  Returns information about the current file.

  Gets the file handle and table directory for the font file that was most recently
  registered or set as current.

  ## Returns

  A map containing:
  - `:pid` - The current file handle
  - `:table_directory` - The parsed table directory

  ## Raises

  Raises an error if no file is currently registered. Always call `register/1` before
  using this function.

  ## Example

  ```elixir
  # First register a file
  TTFonture.FileRegister.register("fonts/myfont.ttf")

  # Then get info about the current file
  %{pid: file_pid, table_directory: table_dir} = TTFonture.FileRegister.current()
  ```
  """
  @spec current() :: file_info()
  def current do
    Agent.get(__MODULE__, fn state ->
      if is_nil(state.current) do
        raise "No file currently registered. Call register/1 first."
      end

      state.current
    end)
  end

  @doc """
  Returns the file handle (PID) of the current file.

  ## Returns

  The `pid` of the current file.

  ## Raises

  Raises an error if no file is currently registered.

  ## Example

  ```elixir
  # Get just the file handle for the current font
  file_pid = TTFonture.FileRegister.current_pid()
  ```
  """
  @spec current_pid() :: pid()
  def current_pid do
    current().pid
  end

  @doc """
  Returns the table directory of the current file.

  ## Returns

  The table directory map of the current file.

  ## Raises

  Raises an error if no file is currently registered.

  ## Example

  ```elixir
  # Get the table directory of the current font
  table_dir = TTFonture.FileRegister.current_table_directory()
  ```
  """
  @spec current_table_directory() :: table_directory()
  def current_table_directory do
    current().table_directory
  end

  @doc """
  Closes all open files and clears the registry.

  This function is useful during cleanup to ensure all file handles are properly
  closed and resources are released.

  ## Returns

  The state before clearing, containing all file information that was registered.
  """
  @spec close_all() :: state()
  def close_all do
    Agent.get_and_update(__MODULE__, fn state ->
      Enum.each(state.files, fn {_path, file_info} ->
        File.close(file_info.pid)
      end)

      {state, %{current: nil, files: %{}}}
    end)
  end

  @doc """
  Closes a specific file by path.

  Removes the file from the registry and closes the file handle. If the file being
  closed is the current file, the current file reference is set to nil.

  ## Parameters

  - `path`: Path of the file to close

  ## Returns

  The file information of the closed file, or `nil` if the file wasn't registered.

  ## Example

  ```elixir
  # Close a specific font when done with it
  TTFonture.FileRegister.close("fonts/temporary_font.ttf")
  ```
  """
  @spec close(path :: binary()) :: {file_info()}
  def close(path) do
    Agent.get_and_update(__MODULE__, fn state ->
      case Map.fetch(state.files, path) do
        {:ok, file_info} ->
          File.close(file_info.pid)
          files = Map.delete(state.files, path)
          current = if state.current == file_info, do: nil, else: state.current

          {file_info, %{state | current: current, files: files}}

        :error ->
          {nil, state}
      end
    end)
  end
end
