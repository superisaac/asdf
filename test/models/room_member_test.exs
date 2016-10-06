defmodule Asdf.RoomMemberTest do
  use Asdf.ModelCase

  alias Asdf.RoomMember

  @valid_attrs %{room_id: 42, user_id: 42}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = RoomMember.changeset(%RoomMember{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = RoomMember.changeset(%RoomMember{}, @invalid_attrs)
    refute changeset.valid?
  end
end
