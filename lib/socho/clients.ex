defmodule Socho.Clients do
  import Ecto.Query

  alias Socho.Repo
  alias Socho.Clients.Client

  def list_clients do
    Client |> order_by(:name) |> Repo.all()
  end

  def get_client!(id), do: Repo.get!(Client, id)

  def get_client(id) when not is_nil(id), do: Repo.get(Client, id)
  def get_client(nil), do: nil

  def create_client(attrs) do
    %Client{}
    |> Client.changeset(attrs)
    |> Repo.insert()
  end

  def update_client(%Client{} = client, attrs) do
    client
    |> Client.changeset(attrs)
    |> Repo.update()
  end


  def client_counts do
    from(c in Client,
      left_join: u in assoc(c, :users),
      left_join: s in assoc(c, :studies),
      group_by: c.id,
      select: {c, count(u.id, :distinct), count(s.id, :distinct)}
    )
    |> order_by([c], c.name)
    |> Repo.all()
  end
end
