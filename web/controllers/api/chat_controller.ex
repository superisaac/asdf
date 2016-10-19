defmodule Asdf.Api.ChatController do
  use Asdf.Web, :controller
  import Ecto.Query
  alias Asdf.Msg
  alias Asdf.Repo
  alias Asdf.Room
  alias Asdf.RoomMember
  #alias Phoenix.Channel.Server

  def add_select(conn, params) do
    curr_user = current_user(conn)
    options = params["options"]
    # TODO: validatate options
    text =
      case params["text"] do
        nil -> ""
        x -> x
      end

    target = params["target"]
    room = Room.get_chat_room(target, curr_user)
    cond do
      room == nil ->
        error_json conn, "invalid_target"
      true ->
        msg = %Msg{:user_id => curr_user.id,
                   :room_id => room.id,
                   :content => text,
                   :args => %{"msg_type": "select",
                              "options": options}}
        msg = msg |> Repo.insert!
        body = msg_created(conn, msg, room)
        ok_json conn, body
    end
  end

  def add_form(conn, params) do
    curr_user = current_user(conn)
    fields = params["fields"]
    # TODO: validate fields
    text =
      case params["text"] do
        nil -> ""
        x -> x
      end

    target = params["target"]
    room = Room.get_chat_room(target, curr_user)
    cond do
      room == nil ->
        error_json conn, "invalid_target"
      true ->
        msg = %Msg{:user_id => curr_user.id,
                   :room_id => room.id,
                   :content => text,
                   :args => %{"msg_type": "form",
                              "fields": fields}}
        msg = msg |> Repo.insert!
        body = msg_created(conn, msg, room)
        ok_json conn, body
    end
  end

  def add_msg(conn, params) do
      curr_user = current_user(conn)
      text = params["text"]
      target = params["target"]
      room = Room.get_chat_room(target, curr_user)
      cond do
        room == nil ->
          error_json conn, "invalid_target"
        !valid_text?(text) ->
          error_json conn, "invalid_or_empty_text"
        true ->
          msg = %Msg{:user_id => curr_user.id,
                     :room_id => room.id,
                     :content => text}
          msg = msg |> Repo.insert!
          body = msg_created(conn, msg, room)
          ok_json conn, body
      end
  end

  def msg_created(conn, msg, room) do
    params =
    if room.first_msg_id == 0 do
      %{first_msg_id: msg.id, last_msg_id: msg.id}
    else
      %{last_msg_id: msg.id}
    end
    {:ok, room} = Repo.transaction(fn ->
      cset = Room.changeset(room, params)
      Repo.update!(cset)
    end)
    msg_json = Msg.get_json(msg, room, nil)
    body = %{"message" => msg_json}
    spawn(__MODULE__, :broadcast, [room, "new_msg", body])
    
    body = %{"body" => msg_json,
             "event" => "message"}
    spawn(__MODULE__, :call_bots, [conn, room, body, msg.user_id])
    body
  end

  def add_select_value(conn, params) do
    curr_user = current_user(conn)
    value = params["value"]
    reply_msg_id = params["reply"]

    target = params["target"]
    room = Room.get_chat_room(target, curr_user)
    cond do
      room == nil ->
        error_json conn, "invalid_target"
      true ->
        select_json = %{
        "room_id" => room.id,
        "user_id" => curr_user.id,
        "user_name" => Asdf.User.get_user_name(curr_user),
        "reply" => reply_msg_id,
        "value" => value}

        body = %{"select" => select_json}
        spawn(__MODULE__, :broadcast, [room, "select", body])
    
        body = %{"body" => select_json,
                 "event" => "select"}
        spawn(__MODULE__, :call_bots, [conn, room, body, curr_user.id])

        ok_json conn, body
    end
  end

  def add_form_submit(conn, params) do
    curr_user = current_user(conn)
    form_data = params["form_data"]
    form_data = Poison.decode!(form_data)
    reply_msg_id = params["reply"]

    target = params["target"]
    room = Room.get_chat_room(target, curr_user)
    cond do
      room == nil ->
        error_json conn, "invalid_target"
      true ->
        form_json = %{
        "room_id" => room.id,
        "user_id" => curr_user.id,
        "user_name" => Asdf.User.get_user_name(curr_user),
        "reply" => reply_msg_id,
        "form_data" => form_data}

        body = %{"form" => form_json}
        spawn(__MODULE__, :broadcast, [room, "form", body])
    
        body = %{"body" => form_json,
                 "event" => "form"}
        spawn(__MODULE__, :call_bots, [conn, room, body, curr_user.id])

        ok_json conn, body
    end
  end

  def broadcast(room, event, body) do
    q = Repo.all(
      from member in RoomMember,
      where: member.room_id == ^room.id)

    Enum.map(q, fn(member) ->
      topic = "user:#{member.user_id}"
      Asdf.Endpoint.broadcast!(topic, event, body)
    end)
  end

  def call_bots(conn, room, msg_json, sender_id) do
    q = Repo.all(
      from member in RoomMember,
      join: user in Asdf.User,
      on: member.user_id == user.id,
      select: user,
      where: member.room_id == ^room.id)

    Enum.map(q, fn(user) ->
      if Asdf.User.is_bot(user) and user.id != sender_id and user.args["callback_url"] do
        callback_url = 
        case user.args["callback_url"] do
          "/" <> str ->
            merge_url(conn, "/" <> str)
          x -> x
        end

        nonce = generate_nonce()
        cred = Repo.one!(from c in Asdf.Cred,
                        where: c.user_id == ^user.id,
                        where: c.name == "default")
        sig = make_signature(nonce, "#{user.id}", cred.secret)
        headers = [
          "Content-Type": "application/json;charset=utf-8",
          "X-Bot-Nonce": nonce,
          "X-Bot-Id": "#{user.id}",
          "X-Bot-Signature": sig]

        body_json = msg_json
        |> Map.put("to_name", Asdf.User.get_user_name(user))
        |> Map.put("to_id", user.id)
        body = Poison.encode!(body_json)
        
        r = HTTPoison.post!(
          callback_url, body,
          headers)
        
        if r.status_code == 200 do
          IO.inspect Poison.decode!(r.body)
        end
      end
    end)
  end

  defp valid_text?(nil), do: false
  defp valid_text?(""), do: false
  defp valid_text?(_x), do: true

  def get_msg_list(conn, params) do
    curr_user = current_user(conn)
    room = Room.get_chat_room(params["room"], curr_user)
    max_msg_id = parse_uint(params["max_id"])
    count = parse_uint(params["count"], 20)
    qs =
      case max_msg_id do
        0 ->
          from m in Msg,
          where: m.room_id == ^room.id,
          order_by: [desc: :id],
          limit: ^count
        _ ->
          from m in Msg,
          where: m.room_id == ^room.id,
          where: m.id < ^max_msg_id,
          order_by: [desc: :id],
          limit: ^count
      end          
    q = Repo.all(qs)

    msgs = Enum.map(q, fn(m) ->
      Msg.get_json(m, room, nil)
    end)

    room_json = Room.get_json_via_user(room, curr_user)
    IO.inspect room_json
    ok_json conn, %{"msgs": msgs, "room": room_json}
  end

  def put_start_menu(conn, params) do
    curr_user = current_user(conn)
    options = params["options"]
    # TODO: validate options
    curr_user
    |> Asdf.User.put_args(%{"start_options" => options})
    
    ok_json conn, %{}
  end
  
end
