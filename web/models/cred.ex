defmodule Asdf.Cred do
  use Asdf.Web, :model

  schema "creds" do
    field :user_id, :integer
    field :name, :string
    field :secret, :string

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:user_id, :name, :secret])
    |> validate_required([:user_id, :name, :secret])
  end
  
  def user(cred) do
    Asdf.Repo.get(Asdf.User, cred.user_id)
  end

  def create(user, name) do
    cred = %Asdf.Cred{
      user_id: user.id,
      name: name,
      secret: UUID.uuid4()
    }
    Asdf.Repo.insert!(cred)
  end

  def get_json(cred) do
    %{secret: cred.secret}
  end

end
