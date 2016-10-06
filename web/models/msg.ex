defmodule Asdf.Msg do
  use Asdf.Web, :model

  schema "msgs" do
    field :user_id, :integer
    field :room_id, :integer
    field :content, :string
    field :args, :map

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:user_id, :room_id, :content, :args])
    |> validate_required([:user_id, :room_id, :content, :args])
  end

  @doc """
  Return the creator of this room
  """
  def user!(msg) do
    Asdf.Repo.get!(Asdf.User, msg.user_id)
  end

  @doc """
  Return the creator of this room
  """
  def room!(msg) do
    Asdf.Repo.get!(Asdf.Room, msg.room_id)
  end

  def get_json(msg, room, nil) do
    user = user!(msg)
    get_json(msg, room, user)
  end
  
  def get_json(msg, nil, user) do
    room = room!(msg)
    get_json(msg, room, user)
  end

  def get_json(msg, room, user) do
    %{id: msg.id,
      user_id: user.id,
      user_name: user.name,
      room_id: room.id,
      room_name: room.name,
      content: msg.content,
      created_at: msg.inserted_at,
      args: msg.args}
  end

  def get_json(msg) do
    get_json(msg, nil, nil)
  end
  
end
