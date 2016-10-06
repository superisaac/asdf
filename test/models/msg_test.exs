defmodule Asdf.MsgTest do
  use Asdf.ModelCase

  alias Asdf.Msg

  @valid_attrs %{args: %{}, content: "some content", room_id: 42, user_id: 42}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Msg.changeset(%Msg{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Msg.changeset(%Msg{}, @invalid_attrs)
    refute changeset.valid?
  end
end
