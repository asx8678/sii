defmodule Si.RepoTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Ecto.Adapters.SQL
  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.Adapters.SQLite3

  @moduletag :tmp_dir

  setup %{tmp_dir: dir} do
    config = Si.Repo.config() |> Keyword.put(:database, Path.join(dir, "fresh.db"))
    assert config[:journal_mode] == :wal
    assert config[:pool_size] == 5
    %{config: config, database: config[:database]}
  end

  test "storage creation uses the configured persistent WAL mode", %{config: config, database: db} do
    assert SQLite3.storage_up(config) == :ok
    assert query(db, "PRAGMA journal_mode") == [["wal"]]
  end

  test "runtime configuration has no filesystem side effects", %{config: config, database: db} do
    assert Si.Repo.init(:runtime, config) == {:ok, config}
    refute File.exists?(db)
  end

  test "supervisor initialization creates missing storage before connections", %{
    config: config,
    database: db
  } do
    assert Si.Repo.init(:supervisor, config) == {:ok, config}
    assert query(db, "PRAGMA journal_mode") == [["wal"]]
  end

  test "existing storage and its data are preserved", %{config: config, database: db} do
    assert Si.Repo.init(:supervisor, config) == {:ok, config}
    {:ok, conn} = Exqlite.Sqlite3.open(db)
    :ok = Exqlite.Sqlite3.execute(conn, "CREATE TABLE preserved (value TEXT)")
    :ok = Exqlite.Sqlite3.execute(conn, "INSERT INTO preserved VALUES ('keep me')")
    :ok = Exqlite.Sqlite3.close(conn)

    assert Si.Repo.init(:supervisor, config) == {:ok, config}
    assert query(db, "SELECT value FROM preserved") == [["keep me"]]
    assert query(db, "PRAGMA journal_mode") == [["wal"]]
  end

  test "a genuine storage creation error is propagated without changing existing data", %{
    config: config,
    tmp_dir: dir
  } do
    parent = Path.join(dir, "not-a-directory")
    File.write!(parent, "preserve this file")
    config = Keyword.put(config, :database, Path.join(parent, "database.db"))

    assert_raise MatchError, fn -> Si.Repo.init(:supervisor, config) end
    assert File.read!(parent) == "preserve this file"
    refute File.exists?(config[:database])
  end

  test "fresh pooled startup initializes WAL and exercises all configured connections", %{
    config: config,
    database: db
  } do
    supervisor = start_supervised!(Task.Supervisor)
    parent = self()

    log =
      capture_log(fn ->
        repo = start_supervised!({Si.Repo, name: nil, database: db})

        tasks =
          for _ <- 1..config[:pool_size] do
            Task.Supervisor.async(supervisor, fn ->
              :ok = Sandbox.checkout(repo, sandbox: false)
              assert SQL.query!(repo, "SELECT 1", []).rows == [[1]]
              send(parent, {:connection_ready, self()})

              receive do
                :release -> :ok
              after
                5_000 -> raise "connection barrier timed out"
              end

              Sandbox.checkin(repo)
            end)
          end

        for _ <- tasks, do: assert_receive({:connection_ready, _}, 5_000)
        for task <- tasks, do: send(task.pid, :release)
        assert Enum.map(tasks, &Task.await/1) == List.duplicate(:ok, config[:pool_size])
        stop_supervised!(Si.Repo)
      end)

    refute log =~ "[error]"
    refute log =~ "[warning]"
    assert query(db, "PRAGMA journal_mode") == [["wal"]]
  end

  defp query(path, sql) do
    {:ok, conn} = Exqlite.Sqlite3.open(path)

    try do
      {:ok, statement} = Exqlite.Sqlite3.prepare(conn, sql)
      {:ok, rows} = Exqlite.Sqlite3.fetch_all(conn, statement)
      :ok = Exqlite.Sqlite3.release(conn, statement)
      rows
    after
      :ok = Exqlite.Sqlite3.close(conn)
    end
  end
end
