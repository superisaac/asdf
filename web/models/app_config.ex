defmodule Asdf.AppConfig do
  use Asdf.Web, :model

  schema "appconfigs" do
    field :key, :string
    field :data, :map

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:key, :data])
    |> validate_required([:key, :data])
  end
  
end
