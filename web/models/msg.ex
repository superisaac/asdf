defmodule Asdf.Msg do
  use Asdf.Web, :model

  alias Asdf.Repo

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
    Repo.get!(Asdf.User, msg.user_id)
  end

  @doc """
  Return the creator of this room
  """
  def room!(msg) do
    Repo.get!(Asdf.Room, msg.room_id)
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

  def get_entity(ent) do
    case Asdf.Util.parse_entity(ent) do
      {:room, user_name, room_name} ->
        user = Repo.get_by(Asdf.User, name: user_name)
        if user != nil do
          {:room, Repo.get_by(Asdf.Room,
                              user_id: user.id,
                              name: room_name)}
        else
          nil
        end
      {:room_id, room_id} ->
        {:room, Repo.get(Asdf.Room, room_id)}
      {:user_id, user_id} ->
        {:user, Repo.get_by(Asdf.User, id: user_id, is_active: true)}
      {:user, user_name} ->
        {:user, Repo.get_by(Asdf.User, name: user_name, is_active: true)}
      {:bot, user_name, bot_name} ->
        {:user, Asdf.User.get_bot_user(user_name, bot_name)}
      _ -> nil
    end
  end

  def replace_entity(ent) do
    lower_ent = String.downcase(ent)
    case get_entity(lower_ent) do
      {:user, user} when user != nil ->
        full_name = Asdf.User.get_user_name(user)
        "<@#{user.id}|#{full_name}>"
      {:room, room} when room != nil ->
        full_name = Asdf.Room.get_full_name(room)
        "<\##{room.id}|#{full_name}>"
      _ -> ent
    end
  end

  def clean_text(nil), do: ""
  def clean_text(text) do
    reg_entity = ~r{[@#]\w+(\/\w+)?}
    text = Regex.replace(~r{&}, text, "&amp;")
    text = Regex.replace(~r{<}, text, "&lt;")
    text = Regex.replace(~r{>}, text, "&gt;")    
    Regex.replace(reg_entity, text, fn x -> replace_entity(x) end)
  end
  
end
