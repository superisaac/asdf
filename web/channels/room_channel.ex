defmodule Asdf.RoomChannel do
  use Phoenix.Channel
  #alias Phoenix.Channel.Server
  def join(_room_name, _params, socket) do
    {:ok, socket}
  end
end
