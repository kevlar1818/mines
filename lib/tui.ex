defmodule Mines.TUI do
  use GenServer

  alias Mines.Game
  alias Mines.TUI.Formatter

  defstruct port: nil, cursor_row_col: [0, 0], game: nil

  #
  # GenServer API
  #
  def start_link(game = %Game{}) do
    GenServer.start_link(__MODULE__, game)
  end

  #
  # GenServer Callbacks
  #
  # called after start_link
  def init(game) do
    port = Port.open({:spawn, "tty_sl -c -e"}, [:binary, :eof])
    new_game = Game.init(game)
    state = %__MODULE__{
              port: port,
              game: new_game,
            }
    print_board(state)
    {:ok, state}
  end

  # callback for the Erlang Port
  def handle_info({_pid, {:data, data}}, state) do
    key = translate(data)
    new_state = cond do
      key in [:up, :down, :left, :right] -> move_cursor(key, state)
      key == :space -> reveal_cell(state)
    end
    print_board(new_state)
    {:noreply, new_state}
  end

  #
  # Main actions
  #
  def move_cursor(key, state = %__MODULE__{cursor_row_col: [row, col]}) do
    case key do
      :up    -> %{ state | cursor_row_col: [row - 1, col] }
      :down  -> %{ state | cursor_row_col: [row + 1, col] }
      :right -> %{ state | cursor_row_col: [row, col + 1] }
      :left  -> %{ state | cursor_row_col: [row, col - 1] }
    end
  end

  def reveal_cell(state = %__MODULE__{}) do
    new_game = Game.reveal(state.cursor_row_col, state.game)
    %{ state | game: new_game }
  end

  #
  # Other functions
  #
  defp clear_screen do
    IO.write [IO.ANSI.clear, IO.ANSI.home]
  end

  defp print_board(state) do
    clear_screen
    IO.inspect state.game.mine_locs
    IO.write [?\n, ?\r]
    Formatter.format_board(state.game, state.cursor_row_col) |> IO.write
  end

  defp translate("\e[A"), do: :up
  defp translate("\e[B"), do: :down
  defp translate("\e[C"), do: :right
  defp translate("\e[D"), do: :left
  defp translate(" "), do: :space
  defp translate(_), do: nil

end
