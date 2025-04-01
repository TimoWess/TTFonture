defmodule TTFonture.FileRegister do
  @moduledoc """
  Provides a centralized registry for file handles using an Agent.
  Also caches the table directory for each file to avoid repeated reads.
  """
  use Agent

  @doc """
  Starts the FileRegister agent.
  """
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{current: nil, files: %{}} end, name: __MODULE__)
  end

  @doc """
  Registers a file with the given path, reads its table directory,
  and sets it as the current file.
  Returns {file_pid, table_directory}.
  """
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
  Returns the current file information (PID and table directory),
  or raises if no file is registered.
  """
  def current do
    Agent.get(__MODULE__, fn state -> 
      if is_nil(state.current) do
        raise "No file currently registered. Call register/1 first."
      end
      
      state.current
    end)
  end

  @doc """
  Returns just the PID of the current file.
  """
  def current_pid do
    current().pid
  end

  @doc """
  Returns just the table directory of the current file.
  """
  def current_table_directory do
    current().table_directory
  end

  @doc """
  Closes all open files and clears the registry.
  """
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
  """
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
