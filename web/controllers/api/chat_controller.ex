defmodule Asdf.Api.ChatController do
  use Asdf.Web, :controller
  import Ecto.Query
  alias Asdf.Msg
  alias Asdf.Repo
  alias Asdf.Room
  alias Asdf.RoomMember

  def valid_template?(template) do
    case template |> valid_ident do
      nil -> false
      "select" -> true
      "form" -> true
      _ -> false
    end
  end
  
  def add_gadget(conn, params) do
    curr_user = current_user(conn)
    template = params["template"]
    data = params["data"]
    target = params["target"]
    text = params["text"] |> Asdf.Msg.clean_text
    room = Room.get_chat_room_if_joined(target, curr_user)
    cond do
      room == nil ->
        error_json conn, "invalid_target"
      not is_map(data) ->
        error_json conn, "invalid_data"
     !valid_template?(template) ->
        error_json conn, "invalid_template"
      true ->
        template = template |> String.downcase
        msg = add_gadget_msg(conn, curr_user, room, template, text, data)
        msg = msg |> Repo.insert!        
        body = msg_created(conn, msg, room)
        ok_json conn, body
    end
  end
  
  def add_gadget_msg(_conn, curr_user, room, "select", text, data) do
    options = data["options"]
    %Msg{:user_id => curr_user.id,
         :room_id => room.id,
         :content => text,
         :args => %{
           "msg_type": "gadget",
           "template": "select",
           "options": options}}
  end
  def add_gadget_msg(conn, curr_user, room, "form", text, data) do
    action = data["action"] |> valid_ident
    fields = data["fields"] |> clean_form_fields
    cond do
      fields == [] or fields == nil ->
        error_json conn, "invalid_fields"
      action == nil or action == "" ->
        error_json conn, "invalid_action"
      true ->
        text = Asdf.Msg.clean_text(text)
        action = action |> String.downcase
        %Msg{:user_id => curr_user.id,
             :room_id => room.id,
             :content => text,
             :args => %{"msg_type": "gadget",
                        "template": "form",
                        "action": action,
                        "fields": fields}}
    end
  end
  def add_gadget_msg(conn, _curr_user, _room, _template, _text, _data) do
    error_json conn, "template_not_supported"
  end

  # clean form fields
  defp clean_form_fields([]), do: []
  defp clean_form_fields([h|t]) do
    case clean_form_field(h) do
      nil ->
        clean_form_fields(t)
      x ->
        [x|clean_form_fields(t)]
    end
  end
  defp clean_form_fields(_), do: nil
  
  defp clean_form_field(field) when is_map(field) do
    type = field["type"]
    name = field["name"] |> valid_ident
    label = field["label"]
    cond do
      type != "text" and type != "number" ->
        nil
      name == nil or name == "" or name == "action" or name == "target" or name == "reply" ->
        nil
      true ->
        %{"type" => type, "name" => name, "label" => label}
    end
  end
  defp clean_form_field(_), do: nil

  def add_msg(conn, params) do
    curr_user = current_user(conn)
    text = params["text"]
    target = params["target"]
    room = Room.get_chat_room_if_joined(target, curr_user)
    cond do
      room == nil ->
        error_json conn, "invalid_target"
      !valid_text?(text) ->
        error_json conn, "invalid_or_empty_text"
      true ->
        text = Asdf.Msg.clean_text(text)
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
    spawn(__MODULE__, :broadcast,
          [room, "new_msg", body])
    
    body = %{"body" => msg_json,
             "event" => "message"}
    spawn(__MODULE__, :call_bots,
          [conn, room, body, msg.user_id])
    body
  end

  def add_gadget_action(conn, params) do
    curr_user = current_user(conn)
    template = params["template"] |> valid_ident 
    action = params["action"] |> valid_ident
    reply_msg_id = params["reply"]
    target = params["target"]
    room = Room.get_chat_room_if_joined(target, curr_user)
    
    form_data = params
    |> Map.delete("action") |> Map.delete("template")
    |> Map.delete("reply") |> Map.delete("target")

    cond do
      room == nil ->
        error_json conn, "invalid_target"
      !valid_template?(template) ->
        error_json conn, "invalid_template"
      action == nil or action == "" ->
        error_json conn, "invalid_action"
      true ->
        body = %{
          "room_id" => room.id,
          "user_id" => curr_user.id,
          "user_name" => Asdf.User.get_user_name(curr_user),
          "reply" => reply_msg_id,
          "template" => template,
          "action" => action,
          "data" => form_data}
        msg_body = %{"body" => body,
                     "event" => "gadget_action"}
        spawn(__MODULE__, :call_bots, [conn, room, msg_body, curr_user.id])

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
    if !RoomMember.exists(room, curr_user) do
      error_json conn, "room_not_joined"
    else
      get_msg_list_if_joined(conn, room, curr_user, params)
    end
  end
  
  defp get_msg_list_if_joined(conn, room, curr_user, params) do
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
