defmodule Asdf.UserChannel do
  use Phoenix.Channel
  #alias Phoenix.Channel.Server
  
  def join("user:" <> user_id, _params, socket) do
    s_user = socket.assigns[:user]
    if "#{s_user.id}" == "#{user_id}" do
      {:ok, socket}
    else
      {:error, %{reason: "auth failed"}}
    end
  end

  def join(channel, _params, _socket) do
    {:error, %{reason: "illegal " <> channel}}
  end  
end
