defmodule Asdf.RoomChannel do
  use Phoenix.Channel
  alias Phoenix.Channel.Server
  
  def join(room_name, _params, socket) do
    IO.puts "room name #{room_name}"
    {:ok, socket}
  end
end
