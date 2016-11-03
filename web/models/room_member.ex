defmodule Asdf.RoomMember do
  use Asdf.Web, :model

  
  schema "roommembers" do
    field :user_id, :integer
    field :room_id, :integer
    field :is_admin, :boolean

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:user_id, :room_id])
    |> validate_required([:user_id, :room_id])
  end

  @doc """
  Return the creator of the member
  """
  def user!(member) do
    Asdf.Repo.get!(Asdf.User, member.user_id)
  end

  @doc """
  Return the room of the member
  """
  def room!(member) do
    Asdf.Repo.get!(Asdf.Room, member.room_id)
  end

  def create(room, user, is_admin) do
    lm = %Asdf.RoomMember{user_id: user.id, room_id: room.id, is_admin: is_admin}
    Asdf.Repo.insert!(lm)
  end

  def upsert(room, user) do
    #if !Asdf.Repo.get_by(Asdf.RoomMember, user_id: user.id, room_id: room.id) do
    if !exists(room, user) do
      create(room, user, false)
    end
  end

  def exists(room, user) do
    Asdf.Repo.get_by(Asdf.RoomMember, user_id: user.id, room_id: room.id) != nil
  end

end
