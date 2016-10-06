defmodule Asdf.UserAuth do
  use Asdf.Web, :model

  schema "userauths" do
    field :site, :string
    field :token, :string
    field :site_userid, :string
    field :user_name, :string
    field :avatar_url, :string
    belongs_to :user, Asdf.User

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:site, :token, :site_userid, :user_name, :avatar_url, :user_id])
    |> validate_required([:site, :token, :user_name])
  end
end
