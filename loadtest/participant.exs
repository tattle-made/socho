defmodule Socho.Load.Participant do
  @moduledoc """
  Simulates participants taking an IAT study, the way a browser would.

  Every iteration is a new visitor who does one of two things:

    * Anonymous (1 - LOGGED_IN_SHARE): opens the public study, loads its
      assets, takes the study, and submits the results.
    * Signed in (LOGGED_IN_SHARE): opens /dashboard, gets redirected to log
      in, signs in with a seeded account, views the dashboard, then takes the
      client study the same way.

  A failed step stops the iteration and raises, so Stampede counts it under
  "iteration.errors" and prints the reason.

  Run Socho.LoadTest.Seed first, then set:

    * SOCHO_PUBLIC_STUDY_ID, SOCHO_CLIENT_STUDY_ID, SOCHO_ACCOUNTS (printed by the seed)
    * SOCHO_BASE_URL, the server to test
    * LOGGED_IN_SHARE (default 0.5)
    * SOCHO_THINK_SECONDS, how long taking a study takes (default 30-90)
  """

  use Stampede.Scenario

  alias Socho.LoadTest.{Accounts, IAT}
  alias Stampede.{HTTP, LiveView, VU}

  @gzip {"accept-encoding", "gzip"}
  @typing_ms 3_000..8_000
  @dashboard_view_ms 1_000..3_000

  defstruct [
    :base_url,
    :public_study_id,
    :client_study_id,
    :logged_in_share,
    :study_duration_ms,
    :submission,
    :accounts_count,
    :accounts_used
  ]

  @impl true
  def options do
    [
      # Stages:
      # 1. from 0 to 60 seconds, we grow from 0 to 500 users (about 8 new users per second)
      # 2. for the next 2 minutes, stay at 500 users
      # 3. over the last 10 seconds, drop from 500 to 0 users
      stages: [{[second: 60], 500}, {[minute: 2], 500}, {[second: 10], 0}],
      # Pass and fail rules
      thresholds: [
        # Speed rules
        # opening a study page: 95% of requests must finish within 500ms
        {"study.page", p95: 500},
        # posting the result: 95% of requests must finish within 300ms
        {"study.submit", p95: 300},
        # login request
        {"login.post", p95: 1_000},
        # Correctness rules
        # the study page loaded
        {"study page is 200", failed_rate: 0},
        # every JS and CSS file loaded
        {"asset is 200", failed_rate: 0},
        # login redirects to /dashboard
        {"logged in", failed_rate: 0},
        # the submission is successful
        {"submit saved", failed_rate: 0},
        # Crash rules
        # No user's session may crash
        {"iteration.errors", count: 0}
      ]
    ]
  end

  @impl true
  def setup(_opts) do
    # This struct is passed verbatim to run/1 below
    %__MODULE__{
      base_url: System.fetch_env!("SOCHO_BASE_URL"),
      public_study_id: System.fetch_env!("SOCHO_PUBLIC_STUDY_ID"),
      client_study_id: System.fetch_env!("SOCHO_CLIENT_STUDY_ID"),
      logged_in_share: parse_share(System.get_env("LOGGED_IN_SHARE", "0.5")),
      study_duration_ms: parse_seconds_range(System.get_env("SOCHO_THINK_SECONDS", "30-90")),
      submission: IAT.submission(),
      accounts_count: System.fetch_env!("SOCHO_ACCOUNTS") |> String.to_integer(),
      accounts_used: :atomics.new(1, [])
    }
  end

  # Every VU runs this over and over. One run is one visitor:
  #  1. Clear cookies, so every run is a new visitor
  #  2. Signed in only (LOGGED_IN_SHARE of runs): get an account, log in, view the dashboard
  #  3. Open the study page: client study if signed in, public otherwise
  #  4. Load its JS and CSS
  #  5. Pause while the study runs in the browser, with no server work
  #  6. Submit the results
  # The first failed step raises, counted under "iteration.errors"
  @impl true
  def run(%VU{data: %__MODULE__{} = config}) do
    HTTP.clear_cookies()

    result =
      if sign_in?(config) do
        sign_in_and_take_study(config)
      else
        take_study(config, config.public_study_id)
      end

    case result do
      :ok -> :ok
      {:error, reason} -> raise failure_message(reason)
    end
  end

  defp sign_in?(%__MODULE__{logged_in_share: share}) do
    :rand.uniform() < share
  end

  defp sign_in_and_take_study(%__MODULE__{} = config) do
    with {:ok, email} <- get_account_email(config),
         :ok <- sign_in(config, email),
         :ok <- view_dashboard(config) do
      take_study(config, config.client_study_id)
    end
  end

  defp sign_in(%__MODULE__{} = config, email) do
    credentials = %{"email" => email, "password" => Accounts.password()}

    # /dashboard redirects to log in.
    # The LiveView submit doesn't log in: it tells the browser to POST the form.
    # Stampede runs no JS, so we send that POST ourselves.
    with {:ok, login} <- LiveView.connect(config.base_url <> "/dashboard", cookies: true),
         :ok <- pause(@typing_ms),
         {:ok, _reply} <- LiveView.submit(login, "submit_password", %{"user" => credentials}),
         :ok <- LiveView.close(login),
         {:ok, response} <- post_login_form(config, login.params["_csrf_token"], credentials) do
      expect("logged in", response, redirected_to?(response, "/dashboard"))
    end
  end

  defp post_login_form(%__MODULE__{} = config, csrf_token, credentials) do
    post(config.base_url <> "/users/log-in",
      cookies: true,
      headers: [@gzip],
      metric: "login.post",
      form: %{
        "_csrf_token" => csrf_token,
        "user" => Map.put(credentials, "remember_me", "true")
      }
    )
  end

  defp view_dashboard(%__MODULE__{} = config) do
    with {:ok, dashboard} <- LiveView.connect(config.base_url <> "/dashboard", cookies: true),
         :ok <- pause(@dashboard_view_ms) do
      LiveView.close(dashboard)
    end
  end

  defp take_study(%__MODULE__{} = config, study_id) do
    study_url = "#{config.base_url}/study/#{study_id}"

    with {:ok, html} <- open_study(study_url),
         :ok <- load_assets(config, html),
         :ok <- pause(config.study_duration_ms) do
      submit_results(config, study_url, HTTP.csrf_token(html))
    end
  end

  defp open_study(study_url) do
    with {:ok, page} <- HTTP.get(study_url, cookies: true, headers: [@gzip], metric: "study.page"),
         :ok <- expect("study page is 200", page, page.status == 200) do
      {:ok, body(page)}
    end
  end

  # A real visit downloads the page's JS and CSS from Phoenix, which adds load.
  # Stampede isn't a browser, so we fetch the page's assets ourselves
  defp load_assets(%__MODULE__{} = config, html) do
    html
    |> asset_paths()
    |> Enum.reduce_while(:ok, fn path, :ok ->
      case load_asset(config.base_url <> path) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp load_asset(url) do
    with {:ok, asset} <- HTTP.get(url, cookies: true, headers: [@gzip], metric: "study.asset") do
      expect("asset is 200", asset, asset.status == 200)
    end
  end

  # Only {"status": "ok"} counts as saved
  defp submit_results(%__MODULE__{} = config, study_url, csrf_token) do
    with {:ok, response} <-
           post(study_url <> "/user-data",
             cookies: true,
             headers: [{"x-csrf-token", csrf_token}, {"accept", "*/*"}, @gzip],
             metric: "study.submit",
             json: %{data: config.submission}
           ) do
      status = submit_status(response)
      Stampede.check("submit saved", response.status == 200 and status == "ok")
      submit_result(response, status)
    end
  end

  defp submit_result(%{status: 200}, "ok"), do: :ok
  # The account was used by an earlier run
  defp submit_result(_response, "already_submitted"), do: {:error, :already_submitted}

  defp submit_result(response, _status),
    do: {:error, {:check_failed, "submit saved", response.status}}

  # Stampede 1.4.0 returns :closed when it reuses a keep-alive connection the
  # server closed while idle, where a browser opens a new one.
  # Fixed upstream. unreleased as of 1.4.0.
  defp post(url, opts) do
    case HTTP.post(url, opts) do
      {:error, %Mint.TransportError{reason: :closed}} -> HTTP.post(url, opts)
      result -> result
    end
  end

  # Record the check, and turn a failure into an error
  defp expect(check_name, response, passed?) do
    if Stampede.check(check_name, passed?) do
      :ok
    else
      {:error, {:check_failed, check_name, response.status}}
    end
  end

  defp pause(range_ms), do: Process.sleep(Enum.random(range_ms))

  # Shared :atomics counter, so no two VUs get the same account
  defp get_account_email(%__MODULE__{} = config) do
    number = :atomics.add_get(config.accounts_used, 1, 1)

    if number <= config.accounts_count do
      {:ok, Accounts.email(number)}
    else
      {:error, :out_of_accounts}
    end
  end

  defp failure_message(:out_of_accounts),
    do: "used every seeded account: reseed with more accounts and raise SOCHO_ACCOUNTS"

  defp failure_message(:already_submitted),
    do: "account already submitted: reseed before each run"

  defp failure_message({:check_failed, check_name, status}),
    do: "check #{inspect(check_name)} failed with status #{status}"

  defp failure_message(reason), do: "participant failed: #{inspect(reason)}"

  # Local .js and .css paths only
  defp asset_paths(html) do
    ~r/(?:src|href)="(\/[^"]+\.(?:js|css))"/
    |> Regex.scan(html, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
  end

  # Stampede doesn't gunzip responses
  defp body(response) do
    case header(response, "content-encoding") do
      "gzip" -> :zlib.gunzip(response.body)
      _ -> response.body
    end
  end

  defp submit_status(response) do
    case Jason.decode(body(response)) do
      {:ok, %{"status" => status}} -> status
      _ -> nil
    end
  end

  defp redirected_to?(response, path) do
    response.status == 302 and header(response, "location") == path
  end

  defp header(response, name) do
    case List.keyfind(response.headers, name, 0) do
      {_name, value} -> value
      nil -> nil
    end
  end

  defp parse_share(value) do
    {share, ""} = Float.parse(value)
    share
  end

  # "30-90" -> 30_000..90_000
  defp parse_seconds_range(value) do
    [low, high] = value |> String.split("-") |> Enum.map(&String.to_integer/1)
    (low * 1_000)..(high * 1_000)
  end
end
