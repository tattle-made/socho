defmodule Socho.LoadTest.Seed do
  @moduledoc """
  Seeds a load test database for loadtest/participant.exs.

  It ships in the release, so a deployed instance seeds itself:

      bin/socho rpc "Socho.LoadTest.Seed.run()"

  It refuses to run unless the connected database's name contains "loadtest".
  Running it again resets the previous run instead of recreating everything,
  so the study IDs stay the same. Each run makes sure there are:

    * a "Load Test" client
    * two published IAT studies, one public and one for the client, with no
      submissions
    * `:accounts` participant accounts for the client (default 5000), with no
      sessions

  It ends by printing the env vars loadtest/participant.exs needs.
  """

  import Ecto.Query

  alias Socho.{Clients, Repo, Studies}
  alias Socho.Accounts.{User, UserToken}
  alias Socho.Clients.Client
  alias Socho.LoadTest.{Accounts, IAT}
  alias Socho.Studies.{Study, Submission}

  @client_name "Load Test"
  @title_prefix "Load Test: "
  @insert_batch_size 1_000

  # Steps:
  #  1. Refuse unless the database name contains "loadtest"
  #  2. Find or create the "Load Test" client
  #  3. Find or create two published IAT studies: public and client
  #  4. Delete the studies' submissions, so every account can submit again
  #  5. Insert the participant accounts that don't exist yet
  #  6. Delete the accounts' sessions
  #  7. Print the env vars participant.exs needs
  def run(opts \\ []) do
    accounts_count = Keyword.get(opts, :accounts, Accounts.default_count())
    nodes = IAT.nodes()

    with {:ok, database} <- check_database(),
         {:ok, client} <- find_or_create_client(),
         {:ok, public_study} <-
           find_or_create_study("IAT (public)", nil, nodes, %{
             # every VU submits from the Stampede machine's IP
             allow_multiple_public_submissions: true
           }),
         {:ok, client_study} <- find_or_create_study("IAT (client)", client.id, nodes, %{}) do
      delete_submissions([public_study.id, client_study.id])
      insert_missing_accounts(accounts_count, client)
      delete_sessions()

      print_summary(database, accounts_count, public_study, client_study)
    else
      {:error, reason} -> raise failure_message(reason)
    end
  end

  defp check_database do
    %{rows: [[database]]} = Repo.query!("select current_database()")

    if String.contains?(database, "loadtest") do
      {:ok, database}
    else
      {:error, {:not_loadtest_database, database}}
    end
  end

  defp find_or_create_client do
    case Repo.get_by(Client, name: @client_name) do
      nil -> Clients.create_client(%{name: @client_name})
      %Client{} = client -> {:ok, client}
    end
  end

  # New studies start as drafts, so publish them
  defp find_or_create_study(title, client_id, nodes, attrs) do
    title = @title_prefix <> title

    with {:ok, study} <- find_or_create_draft(title, client_id, nodes) do
      Studies.update_study(study.id, Map.put(attrs, :status, :published))
    end
  end

  defp find_or_create_draft(title, client_id, nodes) do
    case Repo.get_by(Study, title: title) do
      nil -> Studies.create_study_with_trials(title, client_id, nodes)
      %Study{} = study -> {:ok, study}
    end
  end

  defp delete_submissions(study_ids) do
    Repo.delete_all(from s in Submission, where: s.study_id in ^study_ids)
  end

  # One shared password, hashed once: bcrypt is slow
  defp insert_missing_accounts(count, %Client{} = client) do
    now = DateTime.utc_now(:second)
    hashed_password = Bcrypt.hash_pwd_salt(Accounts.password())

    1..count//1
    |> Enum.map(fn number ->
      %{
        email: Accounts.email(number),
        hashed_password: hashed_password,
        confirmed_at: now,
        role: :participant,
        client_id: client.id,
        verification_method: :email,
        inserted_at: now,
        updated_at: now
      }
    end)
    |> Enum.chunk_every(@insert_batch_size)
    |> Enum.each(&Repo.insert_all(User, &1, on_conflict: :nothing, conflict_target: :email))
  end

  # Every logged-in visit leaves a session token behind
  defp delete_sessions do
    seeded_users =
      from u in User, where: like(u.email, ^"%@#{Accounts.email_domain()}"), select: u.id

    Repo.delete_all(from t in UserToken, where: t.user_id in subquery(seeded_users))
  end

  defp print_summary(database, accounts_count, public_study, client_study) do
    IO.puts("""
    Seeded #{database} with #{accounts_count} accounts.

    export SOCHO_PUBLIC_STUDY_ID=#{public_study.id}
    export SOCHO_CLIENT_STUDY_ID=#{client_study.id}
    export SOCHO_ACCOUNTS=#{accounts_count}
    """)
  end

  defp failure_message({:not_loadtest_database, database}),
    do: "refusing to seed #{inspect(database)}: the database name must contain \"loadtest\""

  defp failure_message(%Ecto.Changeset{} = changeset),
    do: "could not save #{inspect(changeset.data.__struct__)}: #{inspect(changeset.errors)}"

  defp failure_message(reason), do: "seeding failed: #{inspect(reason)}"
end
