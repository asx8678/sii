defmodule Si.Repo do
  @moduledoc """
  The SQLite repository, with WAL storage initialized before pooled connections.
  """

  use Ecto.Repo,
    otp_app: :si,
    adapter: Ecto.Adapters.SQLite3

  @doc "Initializes missing storage before pool startup; runtime config reads have no side effects."
  @impl true
  @spec init(:supervisor | :runtime, keyword()) :: {:ok, keyword()}
  def init(:supervisor, config) do
    case __adapter__().storage_up(config) do
      :ok -> {:ok, config}
      {:error, :already_up} -> {:ok, config}
    end
  end

  def init(:runtime, config), do: {:ok, config}
end
